import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio de tasas de cambio manuales del hogar.
///
/// Port de `FXService.swift`. Las tasas viven en la columna JSONB
/// `households.fx_rates` (NO hay tabla dedicada): un mapa
/// `{ "USD": { rate, updated_at, source }, ... }` con clave = código ISO en
/// MAYÚSCULAS. Cada valor mapea a [FXRate].
class FxRepository {
  const FxRepository();

  static const String _table = 'households';

  /// Lee el mapa completo de tasas del hogar. Si la fila no tiene `fx_rates`
  /// (o es null), devuelve un mapa vacío. Port de `FXService.fetch`.
  Future<Map<String, FXRate>> getRates(String householdId) async {
    final Map<String, dynamic>? row = await supabase
        .from(_table)
        .select('fx_rates')
        .eq('id', householdId)
        .maybeSingle();

    final dynamic raw = row?['fx_rates'];
    if (raw is! Map) return <String, FXRate>{};

    return raw.map<String, FXRate>(
      (dynamic key, dynamic value) => MapEntry<String, FXRate>(
        key as String,
        FXRate.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  /// Reemplaza el mapa completo de tasas (reescribe el JSONB entero). Port de
  /// `FXService.save`. Serializa cada [FXRate] vía su `toJson` (el `rate` sale
  /// como String por el DecimalConverter — precisión exacta).
  Future<void> setRates(String householdId, Map<String, FXRate> rates) async {
    final Map<String, dynamic> encoded = rates.map<String, dynamic>(
      (String code, FXRate rate) =>
          MapEntry<String, dynamic>(code, rate.toJson()),
    );
    await supabase
        .from(_table)
        .update(<String, dynamic>{'fx_rates': encoded}).eq('id', householdId);
  }

  /// Fija o actualiza UNA tasa puntual. Port de `FXService.setRate`:
  /// lee el mapa actual, setea la entrada bajo el código en MAYÚSCULAS y
  /// reescribe el mapa entero. La marca temporal se guarda en ISO 8601 UTC.
  Future<void> setRate(String householdId, String code, FXRate rate) async {
    final Map<String, FXRate> current = await getRates(householdId);
    current[code.toUpperCase()] = rate;
    await setRates(householdId, current);
  }

  /// Helper de conveniencia: fija una tasa con `source = "manual"` y
  /// `updated_at = now()` (UTC ISO 8601). Espejo de la sobrecarga de iOS que
  /// recibe solo el [Decimal] y arma el [FXRate].
  Future<void> setManualRate(
    String householdId,
    String code,
    Decimal rate,
  ) async {
    final FXRate entry = FXRate(
      rate: rate,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      source: 'manual',
    );
    await setRate(householdId, code, entry);
  }

  /// Elimina una tasa puntual. Port de `FXService.removeRate`.
  Future<void> removeRate(String householdId, String code) async {
    final Map<String, FXRate> current = await getRates(householdId);
    current.remove(code.toUpperCase());
    await setRates(householdId, current);
  }
}

/// Provider del repositorio de FX.
final fxRepositoryProvider = Provider<FxRepository>(
  (ref) => const FxRepository(),
);
