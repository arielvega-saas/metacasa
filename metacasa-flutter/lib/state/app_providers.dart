import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/household_repository.dart';
import '../models/models.dart';

/// Providers de alcance global de la app (app-scope), complementarios al
/// `appGateProvider` de `app_state.dart`. Mientras el gate decide QUÉ subtree
/// mostrar (auth / sin-hogar / app), estos providers exponen el CONTEXTO que las
/// pantallas autenticadas comparten: el hogar activo, el período visible y el
/// modo privacidad.
///
/// Espejo del `AppState` de iOS (`App/AppState.swift`): `households.first`
/// (hogar activo), el mes/año en curso y el `PrivacyManager` (toggle del ojo).

/// Hogar activo del usuario. Lee `HouseholdRepository.fetchMine()` y toma el
/// PRIMERO de la lista — exactamente como iOS, donde `loadHouseholds()` setea
/// `currentHouseholdId = households.first?.id` cuando no hay uno elegido.
///
/// Devuelve `null` si el usuario no pertenece a ningún hogar (el gate ya cubre
/// ese caso enviando a la pantalla de alta, pero lo modelamos defensivamente).
final currentHouseholdProvider = FutureProvider<Household?>((ref) async {
  final List<Household> households =
      await ref.watch(householdRepositoryProvider).fetchMine();
  return households.isEmpty ? null : households.first;
});

/// `id` del hogar activo (String?), derivado de [currentHouseholdProvider].
/// Las pantallas que solo necesitan el id (la mayoría de los fetch) observan
/// este provider para no recargarse ante cambios de otros campos del hogar.
final currentHouseholdIdProvider = Provider<AsyncValue<String?>>((ref) {
  return ref.watch(currentHouseholdProvider).whenData((h) => h?.id);
});

/// Par (año, mes) del período visible en el dashboard. Default: el mes actual
/// según el reloj del device (`DateTime.now()` — runtime de la app, válido
/// acá: no es un default de modelo/const).
typedef YearMonth = ({int year, int month});

/// Notifier del período visible. Expone helpers [nextMonth]/[prevMonth] que
/// avanzan/retroceden un mes manejando el wrap de diciembre↔enero. Espejo del
/// navegador de mes (‹ Mes Año ›) de la UI.
class CurrentPeriodNotifier extends Notifier<YearMonth> {
  @override
  YearMonth build() {
    final DateTime now = DateTime.now();
    return (year: now.year, month: now.month);
  }

  /// Avanza un mes (enero del año siguiente tras diciembre).
  void nextMonth() {
    final int m = state.month + 1;
    state = m > 12
        ? (year: state.year + 1, month: 1)
        : (year: state.year, month: m);
  }

  /// Retrocede un mes (diciembre del año anterior antes de enero).
  void prevMonth() {
    final int m = state.month - 1;
    state = m < 1
        ? (year: state.year - 1, month: 12)
        : (year: state.year, month: m);
  }

  /// Salta a un período arbitrario (usado por selectores externos si hiciera
  /// falta; el navegador del Home solo usa next/prev).
  void setPeriod(int year, int month) => state = (year: year, month: month);
}

/// Provider del período visible (StateProvider con notifier para los helpers).
final currentPeriodProvider =
    NotifierProvider<CurrentPeriodNotifier, YearMonth>(
        CurrentPeriodNotifier.new);

/// Modo privacidad: cuando es `true`, los montos se enmascaran con `••••`.
/// Espejo del `PrivacyManager.isEnabled` de iOS (toggle del ojo en el hero y la
/// AppBar). Default `false`.
final privacyModeProvider = StateProvider<bool>((ref) => false);
