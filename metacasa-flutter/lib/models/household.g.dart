// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FXRate _$FXRateFromJson(Map<String, dynamic> json) => _FXRate(
      rate: const DecimalConverter().fromJson(json['rate']),
      updatedAt: json['updated_at'] as String,
      source: json['source'] as String,
    );

Map<String, dynamic> _$FXRateToJson(_FXRate instance) => <String, dynamic>{
      'rate': const DecimalConverter().toJson(instance.rate),
      'updated_at': instance.updatedAt,
      'source': instance.source,
    };

_HouseholdStrategy _$HouseholdStrategyFromJson(Map<String, dynamic> json) =>
    _HouseholdStrategy(
      savingsPct: const DecimalConverter().fromJson(json['savings_pct']),
      investmentPct: const DecimalConverter().fromJson(json['investment_pct']),
      distributionMode: $enumDecodeNullable(
              _$DistributionModeEnumMap, json['distribution_mode']) ??
          DistributionMode.equal,
      customAllocations:
          (json['custom_allocations'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, const DecimalConverter().fromJson(e)),
              ) ??
              const <String, Decimal>{},
      includeBillsInWaterfall:
          json['include_bills_in_waterfall'] as bool? ?? true,
      includeInstallmentsInWaterfall:
          json['include_installments_in_waterfall'] as bool? ?? true,
      includeDebtPaymentsInWaterfall:
          json['include_debt_payments_in_waterfall'] as bool? ?? true,
    );

Map<String, dynamic> _$HouseholdStrategyToJson(_HouseholdStrategy instance) =>
    <String, dynamic>{
      'savings_pct': const DecimalConverter().toJson(instance.savingsPct),
      'investment_pct': const DecimalConverter().toJson(instance.investmentPct),
      'distribution_mode':
          _$DistributionModeEnumMap[instance.distributionMode]!,
      'custom_allocations': instance.customAllocations
          .map((k, e) => MapEntry(k, const DecimalConverter().toJson(e))),
      'include_bills_in_waterfall': instance.includeBillsInWaterfall,
      'include_installments_in_waterfall':
          instance.includeInstallmentsInWaterfall,
      'include_debt_payments_in_waterfall':
          instance.includeDebtPaymentsInWaterfall,
    };

const _$DistributionModeEnumMap = {
  DistributionMode.equal: 'equal',
  DistributionMode.proportional: 'proportional',
  DistributionMode.custom: 'custom',
};

_Household _$HouseholdFromJson(Map<String, dynamic> json) => _Household(
      id: json['id'] as String,
      name: json['name'] as String,
      createdBy: json['created_by'] as String,
      timezone: json['timezone'] as String,
      defaultCurrency: json['default_currency'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      strategy: json['strategy'] == null
          ? null
          : HouseholdStrategy.fromJson(
              json['strategy'] as Map<String, dynamic>),
      fxRates: (json['fx_rates'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, FXRate.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$HouseholdToJson(_Household instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'created_by': instance.createdBy,
      'timezone': instance.timezone,
      'default_currency': instance.defaultCurrency,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'strategy': instance.strategy,
      'fx_rates': instance.fxRates,
    };

_HouseholdMember _$HouseholdMemberFromJson(Map<String, dynamic> json) =>
    _HouseholdMember(
      householdId: json['household_id'] as String,
      userId: json['user_id'] as String,
      role: $enumDecode(_$MemberRoleEnumMap, json['role']),
      displayName: json['display_name'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      invitedBy: json['invited_by'] as String?,
    );

Map<String, dynamic> _$HouseholdMemberToJson(_HouseholdMember instance) =>
    <String, dynamic>{
      'household_id': instance.householdId,
      'user_id': instance.userId,
      'role': _$MemberRoleEnumMap[instance.role]!,
      'display_name': instance.displayName,
      'joined_at': instance.joinedAt.toIso8601String(),
      'invited_by': instance.invitedBy,
    };

const _$MemberRoleEnumMap = {
  MemberRole.owner: 'owner',
  MemberRole.admin: 'admin',
  MemberRole.member: 'member',
  MemberRole.viewer: 'viewer',
};

_HouseholdInvitation _$HouseholdInvitationFromJson(Map<String, dynamic> json) =>
    _HouseholdInvitation(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      email: json['email'] as String,
      role: $enumDecode(_$MemberRoleEnumMap, json['role']),
      inviteToken: json['invite_token'] as String,
      invitedBy: json['invited_by'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      acceptedBy: json['accepted_by'] as String?,
      status: $enumDecode(_$InvitationStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$HouseholdInvitationToJson(
        _HouseholdInvitation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'household_id': instance.householdId,
      'email': instance.email,
      'role': _$MemberRoleEnumMap[instance.role]!,
      'invite_token': instance.inviteToken,
      'invited_by': instance.invitedBy,
      'expires_at': instance.expiresAt.toIso8601String(),
      'accepted_at': instance.acceptedAt?.toIso8601String(),
      'accepted_by': instance.acceptedBy,
      'status': _$InvitationStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$InvitationStatusEnumMap = {
  InvitationStatus.pending: 'pending',
  InvitationStatus.accepted: 'accepted',
  InvitationStatus.expired: 'expired',
  InvitationStatus.revoked: 'revoked',
};
