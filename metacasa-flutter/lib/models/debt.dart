import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/decimal_converter.dart';

part 'debt.freezed.dart';
part 'debt.g.dart';

/// Estado de la deuda.
enum DebtStatus {
  @JsonValue('active')
  active,
  @JsonValue('settled')
  settled,
}

/// Deuda (préstamo, crédito). Espejo 1:1 de `public.debts`.
@freezed
abstract class Debt with _$Debt {
  const Debt._();

  const factory Debt({
    required String id,
    @JsonKey(name: 'household_id') required String householdId,
    required String creditor,
    @JsonKey(name: 'original_amount')
    @DecimalConverter()
    required Decimal originalAmount,
    @JsonKey(name: 'current_balance')
    @DecimalConverter()
    required Decimal currentBalance,

    /// Tasa de interés **anual** en porcentaje (ej. 45.5 = 45.5%).
    @JsonKey(name: 'annual_rate')
    @DecimalConverter()
    required Decimal annualRate,

    /// Pago mensual sugerido (si está definido).
    @JsonKey(name: 'monthly_payment')
    @DecimalNullConverter()
    Decimal? monthlyPayment,
    required String currency,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'maturity_date') DateTime? maturityDate,
    String? category,
    String? note,
    required DebtStatus status,
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Debt;

  factory Debt.fromJson(Map<String, dynamic> json) => _$DebtFromJson(json);

  /// Progreso pagado (0.0 – 1.0).
  double get progress {
    if (originalAmount <= Decimal.zero) return 0;
    final Decimal paid = originalAmount - currentBalance;
    final double ratio = paid.toDouble() / originalAmount.toDouble();
    return ratio.clamp(0, 1).toDouble();
  }

  /// Tasa mensual como fracción (anual% / 1200). Convertida a `Decimal` con
  /// 20 decimales de precisión (achica el epsilon de display). Centraliza la
  /// matemática para no nombrar el tipo `Rational` (no exportado por `decimal`).
  Decimal get _monthlyRate => (annualRate / Decimal.fromInt(1200))
      .toDecimal(scaleOnInfinitePrecision: 20);

  /// Interés mensual estimado sobre el saldo actual (tasa anual / 12).
  /// Mantiene la matemática en `Decimal` (precisión exacta).
  Decimal get estimatedMonthlyInterest => currentBalance * _monthlyRate;

  /// Proyección de meses hasta saldo cero asumiendo `monthlyPayment` constante
  /// y aplicando interés mensual. Aproximación simple (sólo mensual).
  /// Port de `estimatedMonthsToPayoff` en iOS.
  int? get estimatedMonthsToPayoff {
    final Decimal? pay = monthlyPayment;
    if (pay == null || pay <= Decimal.zero) return null;
    Decimal balance = currentBalance;
    final Decimal monthlyRate = _monthlyRate;
    var months = 0;
    while (balance > Decimal.zero && months < 600) {
      final Decimal interest = balance * monthlyRate;
      balance += interest - pay;
      months += 1;
      if (balance >= currentBalance && interest >= pay) {
        // El pago no cubre el interés — nunca termina.
        return null;
      }
    }
    return months < 600 ? months : null;
  }

  /// Días restantes hasta la fecha de vencimiento.
  int? get daysUntilMaturity {
    final DateTime? due = maturityDate;
    if (due == null) return null;
    return due.difference(DateTime.now()).inDays;
  }
}
