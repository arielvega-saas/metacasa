// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Debt _$DebtFromJson(Map<String, dynamic> json) => _Debt(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      creditor: json['creditor'] as String,
      originalAmount:
          const DecimalConverter().fromJson(json['original_amount']),
      currentBalance:
          const DecimalConverter().fromJson(json['current_balance']),
      annualRate: const DecimalConverter().fromJson(json['annual_rate']),
      monthlyPayment:
          const DecimalNullConverter().fromJson(json['monthly_payment']),
      currency: json['currency'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      maturityDate: json['maturity_date'] == null
          ? null
          : DateTime.parse(json['maturity_date'] as String),
      category: json['category'] as String?,
      note: json['note'] as String?,
      status: $enumDecode(_$DebtStatusEnumMap, json['status']),
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$DebtToJson(_Debt instance) => <String, dynamic>{
      'id': instance.id,
      'household_id': instance.householdId,
      'creditor': instance.creditor,
      'original_amount':
          const DecimalConverter().toJson(instance.originalAmount),
      'current_balance':
          const DecimalConverter().toJson(instance.currentBalance),
      'annual_rate': const DecimalConverter().toJson(instance.annualRate),
      'monthly_payment':
          const DecimalNullConverter().toJson(instance.monthlyPayment),
      'currency': instance.currency,
      'start_date': instance.startDate.toIso8601String(),
      'maturity_date': instance.maturityDate?.toIso8601String(),
      'category': instance.category,
      'note': instance.note,
      'status': _$DebtStatusEnumMap[instance.status]!,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$DebtStatusEnumMap = {
  DebtStatus.active: 'active',
  DebtStatus.settled: 'settled',
};
