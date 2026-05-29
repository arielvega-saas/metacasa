// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BudgetPeriod _$BudgetPeriodFromJson(Map<String, dynamic> json) =>
    _BudgetPeriod(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      periodType: $enumDecode(_$PeriodTypeEnumMap, json['period_type']),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      totalIncome: const DecimalConverter().fromJson(json['total_income']),
      totalAllocated:
          const DecimalConverter().fromJson(json['total_allocated']),
      readyToAssign: const DecimalConverter().fromJson(json['ready_to_assign']),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$BudgetPeriodToJson(_BudgetPeriod instance) =>
    <String, dynamic>{
      'id': instance.id,
      'household_id': instance.householdId,
      'period_type': _$PeriodTypeEnumMap[instance.periodType]!,
      'period_start': instance.periodStart.toIso8601String(),
      'period_end': instance.periodEnd.toIso8601String(),
      'total_income': const DecimalConverter().toJson(instance.totalIncome),
      'total_allocated':
          const DecimalConverter().toJson(instance.totalAllocated),
      'ready_to_assign':
          const DecimalConverter().toJson(instance.readyToAssign),
      'notes': instance.notes,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$PeriodTypeEnumMap = {
  PeriodType.week: 'week',
  PeriodType.biweek: 'biweek',
  PeriodType.month: 'month',
  PeriodType.quarter: 'quarter',
  PeriodType.year: 'year',
  PeriodType.custom: 'custom',
};

_BudgetAllocation _$BudgetAllocationFromJson(Map<String, dynamic> json) =>
    _BudgetAllocation(
      id: json['id'] as String,
      periodId: json['period_id'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      allocated: const DecimalConverter().fromJson(json['allocated']),
      rolloverFromPrev:
          const DecimalConverter().fromJson(json['rollover_from_prev']),
      rolloverMode: $enumDecode(_$RolloverModeEnumMap, json['rollover_mode']),
      currency: json['currency'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$BudgetAllocationToJson(_BudgetAllocation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'period_id': instance.periodId,
      'category': instance.category,
      'subcategory': instance.subcategory,
      'allocated': const DecimalConverter().toJson(instance.allocated),
      'rollover_from_prev':
          const DecimalConverter().toJson(instance.rolloverFromPrev),
      'rollover_mode': _$RolloverModeEnumMap[instance.rolloverMode]!,
      'currency': instance.currency,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$RolloverModeEnumMap = {
  RolloverMode.none: 'none',
  RolloverMode.surplus: 'surplus',
  RolloverMode.full: 'full',
};
