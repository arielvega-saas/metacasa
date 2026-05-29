import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/decimal_converter.dart';

part 'budget.freezed.dart';
part 'budget.g.dart';

/// Tipo de período presupuestario.
enum PeriodType {
  @JsonValue('week')
  week,
  @JsonValue('biweek')
  biweek,
  @JsonValue('month')
  month,
  @JsonValue('quarter')
  quarter,
  @JsonValue('year')
  year,
  @JsonValue('custom')
  custom;

  String get label => switch (this) {
        PeriodType.week => 'Semanal',
        PeriodType.biweek => 'Quincenal',
        PeriodType.month => 'Mensual',
        PeriodType.quarter => 'Trimestral',
        PeriodType.year => 'Anual',
        PeriodType.custom => 'Personalizado',
      };
}

/// Modo de rollover de un envelope entre períodos.
enum RolloverMode {
  @JsonValue('none')
  none,
  @JsonValue('surplus')
  surplus,
  @JsonValue('full')
  full;

  String get label => switch (this) {
        RolloverMode.none => 'Sin rollover',
        RolloverMode.surplus => 'Solo sobrante',
        RolloverMode.full => 'Todo el saldo',
      };
}

/// Período presupuestario (zero-based). Espejo 1:1 de `public.budget_periods`.
@freezed
abstract class BudgetPeriod with _$BudgetPeriod {
  const factory BudgetPeriod({
    required String id,
    @JsonKey(name: 'household_id') required String householdId,
    @JsonKey(name: 'period_type') required PeriodType periodType,
    @JsonKey(name: 'period_start') required DateTime periodStart,
    @JsonKey(name: 'period_end') required DateTime periodEnd,
    @JsonKey(name: 'total_income')
    @DecimalConverter()
    required Decimal totalIncome,
    @JsonKey(name: 'total_allocated')
    @DecimalConverter()
    required Decimal totalAllocated,
    @JsonKey(name: 'ready_to_assign')
    @DecimalConverter()
    required Decimal readyToAssign,
    String? notes,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _BudgetPeriod;

  factory BudgetPeriod.fromJson(Map<String, dynamic> json) =>
      _$BudgetPeriodFromJson(json);
}

/// Asignación a un envelope dentro de un período. Espejo 1:1 de
/// `public.budget_allocations`.
@freezed
abstract class BudgetAllocation with _$BudgetAllocation {
  const factory BudgetAllocation({
    required String id,
    @JsonKey(name: 'period_id') required String periodId,
    required String category,
    required String subcategory,
    @DecimalConverter() required Decimal allocated,
    @JsonKey(name: 'rollover_from_prev')
    @DecimalConverter()
    required Decimal rolloverFromPrev,
    @JsonKey(name: 'rollover_mode') required RolloverMode rolloverMode,
    required String currency,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _BudgetAllocation;

  factory BudgetAllocation.fromJson(Map<String, dynamic> json) =>
      _$BudgetAllocationFromJson(json);
}

/// Cálculo ligero del saldo de un envelope en cliente. La fuente canónica
/// sigue siendo la función SQL `public.envelope_balance(...)`. No serializa
/// (no es una tabla) — espejo de `EnvelopeStatus` en iOS.
@freezed
abstract class EnvelopeStatus with _$EnvelopeStatus {
  const EnvelopeStatus._();

  const factory EnvelopeStatus({
    required String category,
    required String subcategory,
    @DecimalConverter() required Decimal allocated,
    @DecimalConverter() required Decimal spent,
  }) = _EnvelopeStatus;

  /// Saldo restante del envelope.
  Decimal get remaining => allocated - spent;

  /// Porcentaje usado, clampeado a [0, 1].
  double get percentUsed {
    if (allocated <= Decimal.zero) return 0;
    final double ratio = spent.toDouble() / allocated.toDouble();
    return ratio.clamp(0, 1).toDouble();
  }

  /// Indica sobregiro del envelope.
  bool get isOverBudget => spent > allocated;
}
