import 'package:decimal/decimal.dart';

import '../../models/household.dart';
import '../../models/transaction.dart';

/// Falla al construir un movimiento cuya moneda no se puede llevar a la base del hogar.
class FxConversionException implements Exception {
  const FxConversionException({required this.moneda, required this.base});

  final String moneda;
  final String base;

  @override
  String toString() =>
      'No hay cotización de $moneda a $base. Cargala en Ajustes → Monedas '
      'para poder guardar este movimiento.';
}

extension NewTransactionInputConverting on NewTransactionInput {
  /// **El único constructor que se debe usar cuando el monto puede venir en otra moneda.**
  ///
  /// `amount` es, por contrato (`metacasa-web/AGENTS_CONTRACT.md`), siempre la moneda base
  /// del hogar: es lo que suman los totales del Home, `envelope_balance` y el matview
  /// mensual. Pero hay varios caminos que crean movimientos y cada uno resolvía la moneda
  /// por su cuenta — o no la resolvía.
  ///
  /// El escaneo de recibos era el peor: guardaba el monto leído **sin convertir**, sólo
  /// etiquetado con la moneda del ticket. Un recibo de USD 100 en un hogar en pesos
  /// insertaba `amount = 100`, y todos los totales quedaban divididos por la cotización.
  /// El alta manual sí convertía, pero perdía el monto original y la tasa, así que la lista
  /// mostraba "US$ 150.000" para un gasto de US$ 100.
  ///
  /// Tira si no hay cotización, a propósito: no existe forma honesta de guardar el monto,
  /// y meterlo crudo es peor que no meterlo.
  static NewTransactionInput converting({
    required String householdId,
    required String userId,
    String? accountId,
    required TxType type,
    required Decimal amountOriginal,
    String? currency,
    required String baseCurrency,
    required Map<String, FXRate> rates,
    required String category,
    String? subcategory,
    String? note,
    required DateTime date,
  }) {
    final String base = baseCurrency.toUpperCase();
    final String moneda = (currency ?? base).toUpperCase();

    late final Decimal enBase;
    late final Decimal tasa;
    if (moneda == base) {
      enBase = amountOriginal;
      tasa = Decimal.one;
    } else {
      final FXRate? r = rates[moneda];
      if (r == null) {
        throw FxConversionException(moneda: moneda, base: base);
      }
      enBase = amountOriginal * r.rate;
      tasa = r.rate;
    }

    return NewTransactionInput(
      householdId: householdId,
      userId: userId,
      accountId: accountId,
      type: type,
      amount: enBase,
      amountOriginal: amountOriginal,
      currencyOriginal: moneda,
      fxRateToBase: tasa,
      category: category,
      subcategory: subcategory,
      note: note,
      date: date,
    );
  }
}
