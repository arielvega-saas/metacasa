// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Account _$AccountFromJson(Map<String, dynamic> json) => _Account(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$AccountTypeEnumMap, json['type']),
      currency: json['currency'] as String,
      startingBalance:
          const DecimalConverter().fromJson(json['starting_balance']),
      institution: json['institution'] as String?,
      accountNumberLast4: json['account_number_last4'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      displayOrder: (json['display_order'] as num).toInt(),
      isActive: json['is_active'] as bool,
      notes: json['notes'] as String?,
      ownership:
          $enumDecodeNullable(_$AccountOwnershipEnumMap, json['ownership']) ??
              AccountOwnership.personal,
      ownerUserId: json['owner_user_id'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$AccountToJson(_Account instance) => <String, dynamic>{
      'id': instance.id,
      'household_id': instance.householdId,
      'name': instance.name,
      'type': _$AccountTypeEnumMap[instance.type]!,
      'currency': instance.currency,
      'starting_balance':
          const DecimalConverter().toJson(instance.startingBalance),
      'institution': instance.institution,
      'account_number_last4': instance.accountNumberLast4,
      'icon': instance.icon,
      'color': instance.color,
      'display_order': instance.displayOrder,
      'is_active': instance.isActive,
      'notes': instance.notes,
      'ownership': _$AccountOwnershipEnumMap[instance.ownership]!,
      'owner_user_id': instance.ownerUserId,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$AccountTypeEnumMap = {
  AccountType.checking: 'checking',
  AccountType.savings: 'savings',
  AccountType.cash: 'cash',
  AccountType.creditCard: 'credit_card',
  AccountType.investment: 'investment',
  AccountType.loan: 'loan',
  AccountType.other: 'other',
};

const _$AccountOwnershipEnumMap = {
  AccountOwnership.personal: 'personal',
  AccountOwnership.shared: 'shared',
  AccountOwnership.external: 'external',
};

_CreditCardDetails _$CreditCardDetailsFromJson(Map<String, dynamic> json) =>
    _CreditCardDetails(
      accountId: json['account_id'] as String,
      creditLimit: const DecimalConverter().fromJson(json['credit_limit']),
      statementDay: (json['statement_day'] as num).toInt(),
      dueDay: (json['due_day'] as num).toInt(),
      interestRateMonthly:
          const DecimalConverter().fromJson(json['interest_rate_monthly']),
      minimumPaymentPct:
          const DecimalConverter().fromJson(json['minimum_payment_pct']),
      lastStatementAmount:
          const DecimalNullConverter().fromJson(json['last_statement_amount']),
      lastStatementDate: json['last_statement_date'] == null
          ? null
          : DateTime.parse(json['last_statement_date'] as String),
      network: $enumDecodeNullable(_$CardNetworkEnumMap, json['network']),
    );

Map<String, dynamic> _$CreditCardDetailsToJson(_CreditCardDetails instance) =>
    <String, dynamic>{
      'account_id': instance.accountId,
      'credit_limit': const DecimalConverter().toJson(instance.creditLimit),
      'statement_day': instance.statementDay,
      'due_day': instance.dueDay,
      'interest_rate_monthly':
          const DecimalConverter().toJson(instance.interestRateMonthly),
      'minimum_payment_pct':
          const DecimalConverter().toJson(instance.minimumPaymentPct),
      'last_statement_amount':
          const DecimalNullConverter().toJson(instance.lastStatementAmount),
      'last_statement_date': instance.lastStatementDate?.toIso8601String(),
      'network': _$CardNetworkEnumMap[instance.network],
    };

const _$CardNetworkEnumMap = {
  CardNetwork.visa: 'visa',
  CardNetwork.mastercard: 'mastercard',
  CardNetwork.amex: 'amex',
  CardNetwork.discover: 'discover',
  CardNetwork.other: 'other',
};
