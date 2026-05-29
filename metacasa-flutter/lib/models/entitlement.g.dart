// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entitlement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserEntitlement _$UserEntitlementFromJson(Map<String, dynamic> json) =>
    _UserEntitlement(
      userId: json['user_id'] as String,
      entitlement: json['entitlement'] as String,
      isActive: json['is_active'] as bool,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$UserEntitlementToJson(_UserEntitlement instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'entitlement': instance.entitlement,
      'is_active': instance.isActive,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

_Subscription _$SubscriptionFromJson(Map<String, dynamic> json) =>
    _Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      revenuecatUserId: json['revenuecat_user_id'] as String?,
      productId: json['product_id'] as String,
      entitlementId: json['entitlement_id'] as String,
      store: $enumDecode(_$SubscriptionStoreEnumMap, json['store']),
      environment:
          $enumDecode(_$SubscriptionEnvironmentEnumMap, json['environment']),
      status: $enumDecode(_$SubscriptionStatusEnumMap, json['status']),
      periodType: $enumDecodeNullable(_$PeriodKindEnumMap, json['period_type']),
      purchasedAt: json['purchased_at'] == null
          ? null
          : DateTime.parse(json['purchased_at'] as String),
      renewedAt: json['renewed_at'] == null
          ? null
          : DateTime.parse(json['renewed_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      canceledAt: json['canceled_at'] == null
          ? null
          : DateTime.parse(json['canceled_at'] as String),
    );

Map<String, dynamic> _$SubscriptionToJson(_Subscription instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'revenuecat_user_id': instance.revenuecatUserId,
      'product_id': instance.productId,
      'entitlement_id': instance.entitlementId,
      'store': _$SubscriptionStoreEnumMap[instance.store]!,
      'environment': _$SubscriptionEnvironmentEnumMap[instance.environment]!,
      'status': _$SubscriptionStatusEnumMap[instance.status]!,
      'period_type': _$PeriodKindEnumMap[instance.periodType],
      'purchased_at': instance.purchasedAt?.toIso8601String(),
      'renewed_at': instance.renewedAt?.toIso8601String(),
      'expires_at': instance.expiresAt?.toIso8601String(),
      'canceled_at': instance.canceledAt?.toIso8601String(),
    };

const _$SubscriptionStoreEnumMap = {
  SubscriptionStore.appStore: 'app_store',
  SubscriptionStore.playStore: 'play_store',
  SubscriptionStore.stripe: 'stripe',
  SubscriptionStore.promotional: 'promotional',
};

const _$SubscriptionEnvironmentEnumMap = {
  SubscriptionEnvironment.production: 'production',
  SubscriptionEnvironment.sandbox: 'sandbox',
};

const _$SubscriptionStatusEnumMap = {
  SubscriptionStatus.active: 'active',
  SubscriptionStatus.trialing: 'trialing',
  SubscriptionStatus.gracePeriod: 'grace_period',
  SubscriptionStatus.canceled: 'canceled',
  SubscriptionStatus.expired: 'expired',
  SubscriptionStatus.paused: 'paused',
  SubscriptionStatus.billingIssue: 'billing_issue',
};

const _$PeriodKindEnumMap = {
  PeriodKind.normal: 'normal',
  PeriodKind.intro: 'intro',
  PeriodKind.trial: 'trial',
};
