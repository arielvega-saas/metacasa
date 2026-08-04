// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Transaction _$TransactionFromJson(Map<String, dynamic> json) => _Transaction(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      userId: json['user_id'] as String,
      accountId: json['account_id'] as String?,
      type: $enumDecode(_$TxTypeEnumMap, json['type']),
      amount: const DecimalConverter().fromJson(json['amount']),
      amountOriginal:
          const DecimalNullConverter().fromJson(json['amount_original']),
      currencyOriginal: json['currency_original'] as String?,
      fxRateToBase:
          const DecimalNullConverter().fromJson(json['fx_rate_to_base']),
      fxSource: json['fx_source'] as String?,
      fxStatus: json['fx_status'] as String?,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      account: json['account'] as String?,
      note: json['note'] as String?,
      date: DateTime.parse(json['date'] as String),
      periodYear: (json['period_year'] as num?)?.toInt(),
      periodMonth: (json['period_month'] as num?)?.toInt(),
      transferGroupId: json['transfer_group_id'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$TransactionToJson(_Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'household_id': instance.householdId,
      'user_id': instance.userId,
      'account_id': instance.accountId,
      'type': _$TxTypeEnumMap[instance.type]!,
      'amount': const DecimalConverter().toJson(instance.amount),
      'amount_original':
          const DecimalNullConverter().toJson(instance.amountOriginal),
      'currency_original': instance.currencyOriginal,
      'fx_rate_to_base':
          const DecimalNullConverter().toJson(instance.fxRateToBase),
      'fx_source': instance.fxSource,
      'fx_status': instance.fxStatus,
      'category': instance.category,
      'subcategory': instance.subcategory,
      'account': instance.account,
      'note': instance.note,
      'date': instance.date.toIso8601String(),
      'period_year': instance.periodYear,
      'period_month': instance.periodMonth,
      'transfer_group_id': instance.transferGroupId,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$TxTypeEnumMap = {
  TxType.gasto: 'GASTO',
  TxType.ingreso: 'INGRESO',
};

_NewTransactionInput _$NewTransactionInputFromJson(Map<String, dynamic> json) =>
    _NewTransactionInput(
      householdId: json['household_id'] as String,
      userId: json['user_id'] as String,
      accountId: json['account_id'] as String?,
      type: $enumDecode(_$TxTypeEnumMap, json['type']),
      amount: const DecimalConverter().fromJson(json['amount']),
      amountOriginal:
          const DecimalNullConverter().fromJson(json['amount_original']),
      currencyOriginal: json['currency_original'] as String?,
      fxRateToBase:
          const DecimalNullConverter().fromJson(json['fx_rate_to_base']),
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      note: json['note'] as String?,
      date: DateTime.parse(json['date'] as String),
    );

Map<String, dynamic> _$NewTransactionInputToJson(
        _NewTransactionInput instance) =>
    <String, dynamic>{
      'household_id': instance.householdId,
      'user_id': instance.userId,
      'account_id': instance.accountId,
      'type': _$TxTypeEnumMap[instance.type]!,
      'amount': const DecimalConverter().toJson(instance.amount),
      'amount_original':
          const DecimalNullConverter().toJson(instance.amountOriginal),
      'currency_original': instance.currencyOriginal,
      'fx_rate_to_base':
          const DecimalNullConverter().toJson(instance.fxRateToBase),
      'category': instance.category,
      'subcategory': instance.subcategory,
      'note': instance.note,
      'date': instance.date.toIso8601String(),
    };
