// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TransactionTemplate _$TransactionTemplateFromJson(Map<String, dynamic> json) =>
    _TransactionTemplate(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String?,
      type: $enumDecode(_$TxTypeEnumMap, json['type']),
      amount: const DecimalConverter().fromJson(json['amount']),
      currency: json['currency'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      note: json['note'] as String?,
      position: (json['position'] as num).toInt(),
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$TransactionTemplateToJson(
        _TransactionTemplate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'household_id': instance.householdId,
      'name': instance.name,
      'emoji': instance.emoji,
      'type': _$TxTypeEnumMap[instance.type]!,
      'amount': const DecimalConverter().toJson(instance.amount),
      'currency': instance.currency,
      'category': instance.category,
      'subcategory': instance.subcategory,
      'note': instance.note,
      'position': instance.position,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$TxTypeEnumMap = {
  TxType.gasto: 'GASTO',
  TxType.ingreso: 'INGRESO',
};
