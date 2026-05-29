// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Bill _$BillFromJson(Map<String, dynamic> json) => _Bill(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      householdId: json['household_id'] as String,
      title: json['title'] as String,
      amount: const DecimalConverter().fromJson(json['amount']),
      currency: json['currency'] as String? ?? 'USD',
      dueDate: DateTime.parse(json['due_date'] as String),
      status: $enumDecodeNullable(_$BillStatusEnumMap, json['status']) ??
          BillStatus.pending,
      category: json['category'] as String? ?? '',
      recurrenceType: json['recurrence_type'] as String?,
      reminderDays: (json['reminder_days'] as num?)?.toInt(),
      amountOriginal:
          const DecimalNullConverter().fromJson(json['amount_original']),
      currencyOriginal: json['currency_original'] as String?,
      fxRateToBase:
          const DecimalNullConverter().fromJson(json['fx_rate_to_base']),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$BillToJson(_Bill instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'household_id': instance.householdId,
      'title': instance.title,
      'amount': const DecimalConverter().toJson(instance.amount),
      'currency': instance.currency,
      'due_date': instance.dueDate.toIso8601String(),
      'status': _$BillStatusEnumMap[instance.status]!,
      'category': instance.category,
      'recurrence_type': instance.recurrenceType,
      'reminder_days': instance.reminderDays,
      'amount_original':
          const DecimalNullConverter().toJson(instance.amountOriginal),
      'currency_original': instance.currencyOriginal,
      'fx_rate_to_base':
          const DecimalNullConverter().toJson(instance.fxRateToBase),
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$BillStatusEnumMap = {
  BillStatus.pending: 'pending',
  BillStatus.paid: 'paid',
  BillStatus.skipped: 'skipped',
};
