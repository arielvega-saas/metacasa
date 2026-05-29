import 'package:freezed_annotation/freezed_annotation.dart';

part 'entitlement.freezed.dart';
part 'entitlement.g.dart';

/// Nombres canónicos de entitlements. Deben coincidir con RevenueCat.
abstract final class EntitlementName {
  static const String premium = 'premium';
  static const String pro = 'pro';
}

/// Entitlement del usuario (acceso a features premium). Espejo 1:1 de
/// `public.user_entitlements`.
@freezed
abstract class UserEntitlement with _$UserEntitlement {
  const factory UserEntitlement({
    @JsonKey(name: 'user_id') required String userId,
    required String entitlement,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _UserEntitlement;

  factory UserEntitlement.fromJson(Map<String, dynamic> json) =>
      _$UserEntitlementFromJson(json);
}

/// Store de la suscripción.
enum SubscriptionStore {
  @JsonValue('app_store')
  appStore,
  @JsonValue('play_store')
  playStore,
  @JsonValue('stripe')
  stripe,
  @JsonValue('promotional')
  promotional,
}

/// Entorno de la suscripción.
enum SubscriptionEnvironment {
  @JsonValue('production')
  production,
  @JsonValue('sandbox')
  sandbox,
}

/// Estado de la suscripción.
enum SubscriptionStatus {
  @JsonValue('active')
  active,
  @JsonValue('trialing')
  trialing,
  @JsonValue('grace_period')
  gracePeriod,
  @JsonValue('canceled')
  canceled,
  @JsonValue('expired')
  expired,
  @JsonValue('paused')
  paused,
  @JsonValue('billing_issue')
  billingIssue,
}

/// Tipo de período de facturación.
enum PeriodKind {
  @JsonValue('normal')
  normal,
  @JsonValue('intro')
  intro,
  @JsonValue('trial')
  trial,
}

/// Suscripción RevenueCat/StoreKit espejada en Supabase. Espejo 1:1 de
/// `public.subscriptions`.
@freezed
abstract class Subscription with _$Subscription {
  const factory Subscription({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'revenuecat_user_id') String? revenuecatUserId,
    @JsonKey(name: 'product_id') required String productId,
    @JsonKey(name: 'entitlement_id') required String entitlementId,
    required SubscriptionStore store,
    required SubscriptionEnvironment environment,
    required SubscriptionStatus status,
    @JsonKey(name: 'period_type') PeriodKind? periodType,
    @JsonKey(name: 'purchased_at') DateTime? purchasedAt,
    @JsonKey(name: 'renewed_at') DateTime? renewedAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'canceled_at') DateTime? canceledAt,
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);
}
