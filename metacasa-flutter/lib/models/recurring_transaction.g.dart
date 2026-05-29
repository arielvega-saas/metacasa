// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RecurringTransaction _$RecurringTransactionFromJson(
        Map<String, dynamic> json) =>
    _RecurringTransaction(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      userId: json['user_id'] as String,
      type: $enumDecode(_$TxTypeEnumMap, json['type']),
      amount: const DecimalConverter().fromJson(json['amount']),
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      account: json['account'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      nextDate: json['next_date'] == null
          ? null
          : DateTime.parse(json['next_date'] as String),
      note: json['note'] as String?,
      frequency: $enumDecode(_$FrequencyEnumMap, json['frequency']),
      active: json['active'] as bool,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$RecurringTransactionToJson(
        _RecurringTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'household_id': instance.householdId,
      'user_id': instance.userId,
      'type': _$TxTypeEnumMap[instance.type]!,
      'amount': const DecimalConverter().toJson(instance.amount),
      'category': instance.category,
      'subcategory': instance.subcategory,
      'account': instance.account,
      'start_date': instance.startDate.toIso8601String(),
      'end_date': instance.endDate?.toIso8601String(),
      'next_date': instance.nextDate?.toIso8601String(),
      'note': instance.note,
      'frequency': _$FrequencyEnumMap[instance.frequency]!,
      'active': instance.active,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$TxTypeEnumMap = {
  TxType.gasto: 'GASTO',
  TxType.ingreso: 'INGRESO',
};

const _$FrequencyEnumMap = {
  Frequency.daily: 'daily',
  Frequency.weekly: 'weekly',
  Frequency.monthly: 'monthly',
  Frequency.yearly: 'yearly',
};
