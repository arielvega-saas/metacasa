import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_init.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/household_repository.dart';

/// Estado del *gate* raíz de la app — espejo del `RootView` de iOS, que decide
/// qué subtree mostrar antes de entrar al shell de tabs:
///
/// iOS:  isBootstrapping → session==nil → currentHouseholdId==nil → mainApp
/// aquí: loading         → unauthenticated → noHousehold          → ready
///
/// En iOS hay además un trial-gate (AccessController: loading/locked/granted)
/// DESPUÉS de auth+hogar. Eso llega con RevenueCat en una ola futura; por ahora
/// el gate financiero no se modela acá.
enum AppGate { loading, unauthenticated, noHousehold, ready }

/// `Notifier` real del gate raíz. Reemplaza al stub `StateProvider` previo.
///
/// Decide el estado a partir de **dos** señales:
///  1. ¿Hay sesión Supabase? (`AuthRepository.currentSession`)
///  2. Si la hay, ¿el usuario pertenece a algún hogar? (`HouseholdRepository.fetchMine()`)
///
/// Se suscribe a `authStateChanges` para re-evaluar en login/logout/refresh.
///
/// Modo sin backend (dev/diseño/`flutter test`): si `!Env.hasSupabase` el gate
/// resuelve directo a [AppGate.unauthenticated] y **nunca** toca
/// `Supabase.instance` (que tiraría un assert sin inicializar). Así los tests
/// de widget bootean a la pantalla de login sin red ni credenciales.
class AppGateNotifier extends Notifier<AppGate> {
  StreamSubscription<AuthState>? _authSub;

  @override
  AppGate build() {
    // Cerrar la suscripción si el provider se recrea/dispone.
    ref.onDispose(() => _authSub?.cancel());

    if (!supabaseReady) {
      // Sin Supabase no hay nada que escuchar ni que consultar.
      return AppGate.unauthenticated;
    }

    final auth = ref.read(authRepositoryProvider);

    // Re-evaluar ante cualquier cambio de auth (signedIn, signedOut,
    // tokenRefreshed, userUpdated). `evaluate()` setea `state` async.
    _authSub = auth.authStateChanges.listen((_) {
      // Evaluación best-effort; los errores se absorben en `evaluate`.
      unawaited(evaluate());
    });

    // Arranque: si NO hay sesión, ya sabemos el estado sin red. Si la hay,
    // mostramos `loading` mientras consultamos la pertenencia a hogar.
    if (auth.currentSession == null) {
      return AppGate.unauthenticated;
    }
    unawaited(evaluate());
    return AppGate.loading;
  }

  /// Recalcula el gate desde cero (sesión + pertenencia a hogar) y publica el
  /// resultado en `state`. Idempotente y seguro de llamar varias veces.
  Future<void> evaluate() async {
    if (!supabaseReady) {
      state = AppGate.unauthenticated;
      return;
    }

    final auth = ref.read(authRepositoryProvider);
    if (auth.currentSession == null) {
      state = AppGate.unauthenticated;
      return;
    }

    // Hay sesión: averiguar si tiene hogar. RLS filtra a los hogares del user.
    try {
      final households =
          await ref.read(householdRepositoryProvider).fetchMine();
      state = households.isEmpty ? AppGate.noHousehold : AppGate.ready;
    } catch (_) {
      // No pudimos resolver la pertenencia (red caída, etc.). Conservador:
      // tratamos como "sin hogar" para no encerrar al user fuera del flujo de
      // alta; podrá reintentar. (No lo mandamos a `unauthenticated`: la sesión
      // sigue siendo válida.)
      state = AppGate.noHousehold;
    }
  }

  /// Re-evaluación pública para que las pantallas fuercen un refresh (p. ej.
  /// tras crear/unirse a un hogar, o un pull-to-retry).
  Future<void> refresh() => evaluate();

  // ───────────────────────── Acciones de auth ─────────────────────────
  // Las pantallas llaman a estos métodos; el gate orquesta repo + re-evalúa.
  // Los errores de auth se propagan como `AuthFailure` (mensaje en español)
  // para que la UI los pinte. La transición de estado la dispara igualmente
  // `authStateChanges`, pero llamamos `evaluate()` explícito para no depender
  // del timing del stream.

  Future<void> signIn({required String email, required String password}) async {
    await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);
    await evaluate();
  }

  /// Devuelve el resultado del alta: si quedó pendiente de confirmar email, la
  /// pantalla muestra el mensaje y NO transiciona (no hay sesión todavía).
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .signUp(email: email, password: password);
    if (result == AuthSignUpResult.signedIn) {
      await evaluate();
    }
    return result;
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    await evaluate();
  }

  // ──────────────────────── Acciones de hogar ─────────────────────────

  /// Crea un hogar y, si sale bien, transiciona a `ready`. La moneda viene de la
  /// pantalla.
  ///
  /// Timezone: el iOS manda `TimeZone.current.identifier` (un id **IANA**, p. ej.
  /// "America/Argentina/Buenos_Aires"). Dart no expone la zona IANA del device
  /// sin sumar un paquete (`DateTime.timeZoneName` da una abreviatura tipo "ART"
  /// / "-03", que NO es IANA y rompería la aritmética de fechas server-side).
  /// Para no escribir basura mandamos `'UTC'` (id IANA válido, == al default de
  /// la columna `households.timezone`); el hogar puede ajustar su zona después.
  /// TODO: cuando se agregue un paquete de timezone (p. ej. `flutter_timezone`),
  /// reemplazar `'UTC'` por la zona real del device, igual que iOS.
  Future<void> createHousehold({
    required String name,
    required String currency,
  }) async {
    await ref.read(householdRepositoryProvider).create(
          name: name.trim(),
          currency: currency.toUpperCase(),
          timezone: 'UTC',
        );
    await evaluate();
  }

  /// Acepta una invitación por token y re-evalúa (debería pasar a `ready`).
  Future<void> joinHousehold(String token) async {
    await ref.read(householdRepositoryProvider).acceptInvitation(token.trim());
    await evaluate();
  }
}

/// Provider del gate raíz. El router lo lee (`ref.read`) en su `redirect` y lo
/// escucha (`ref.listen`) vía `_GateListenable`; las pantallas leen el notifier
/// (`.notifier`) para invocar las acciones de auth/hogar.
final appGateProvider = NotifierProvider<AppGateNotifier, AppGate>(
  AppGateNotifier.new,
);
