import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/decimal_converter.dart';

part 'installment.freezed.dart';
part 'installment.g.dart';

/// Estado del plan de cuotas. OJO: `cancelled` con doble-L (wire-value real).
enum PlanStatus {
  @JsonValue('active')
  active,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

/// Plan de cuotas (ej. iPhone en 12 cuotas). Espejo 1:1 de
/// `public.installment_plans`.
@freezed
abstract class InstallmentPlan with _$InstallmentPlan {
  const InstallmentPlan._();

  const factory InstallmentPlan({
    required String id,
    @JsonKey(name: 'household_id') required String householdId,
    required String name,
    @JsonKey(name: 'total_amount')
    @DecimalConverter()
    required Decimal totalAmount,
    @JsonKey(name: 'total_installments') required int totalInstallments,
    required String currency,
    @JsonKey(name: 'start_year') required int startYear,
    @JsonKey(name: 'start_month') required int startMonth,
    String? category,
    @JsonKey(name: 'account_id') String? accountId,
    String? note,
    required PlanStatus status,
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _InstallmentPlan;

  factory InstallmentPlan.fromJson(Map<String, dynamic> json) =>
      _$InstallmentPlanFromJson(json);

  /// Monto de cada cuota (total / número de cuotas). Matemática en `Decimal`.
  Decimal get monthlyAmount {
    if (totalInstallments <= 0) return Decimal.zero;
    return (totalAmount / Decimal.fromInt(totalInstallments))
        .toDecimal(scaleOnInfinitePrecision: 10);
  }

  /// Año/mes efectivo de la cuota número [n] (1-indexed).
  ({int year, int month}) periodFor(int n) {
    final int offset = n - 1;
    var y = startYear;
    var m = startMonth + offset;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    return (year: y, month: m);
  }

  /// Número de cuota (1-indexed) que corresponde al (año, mes) dado, o `null`
  /// si ese período no pertenece al plan.
  int? installmentNumber({required int year, required int month}) {
    final int startMonths = startYear * 12 + (startMonth - 1);
    final int targetMonths = year * 12 + (month - 1);
    final int diff = targetMonths - startMonths;
    if (diff < 0 || diff >= totalInstallments) return null;
    return diff + 1;
  }
}

/// Ledger mensual de cuota (una fila por mes planificado). Espejo 1:1 de
/// `public.installment_payments`.
@freezed
abstract class InstallmentPayment with _$InstallmentPayment {
  const factory InstallmentPayment({
    required String id,
    @JsonKey(name: 'plan_id') required String planId,
    @JsonKey(name: 'period_year') required int periodYear,
    @JsonKey(name: 'period_month') required int periodMonth,
    @JsonKey(name: 'installment_number') required int installmentNumber,
    @DecimalConverter() required Decimal amount,
    required bool paid,
    @JsonKey(name: 'paid_at') DateTime? paidAt,
    @JsonKey(name: 'transaction_id') String? transactionId,
  }) = _InstallmentPayment;

  factory InstallmentPayment.fromJson(Map<String, dynamic> json) =>
      _$InstallmentPaymentFromJson(json);
}
