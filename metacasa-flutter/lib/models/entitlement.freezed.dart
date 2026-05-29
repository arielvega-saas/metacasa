// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entitlement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserEntitlement {
  @JsonKey(name: 'user_id')
  String get userId;
  String get entitlement;
  @JsonKey(name: 'is_active')
  bool get isActive;
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Create a copy of UserEntitlement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserEntitlementCopyWith<UserEntitlement> get copyWith =>
      _$UserEntitlementCopyWithImpl<UserEntitlement>(
          this as UserEntitlement, _$identity);

  /// Serializes this UserEntitlement to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UserEntitlement &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.entitlement, entitlement) ||
                other.entitlement == entitlement) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, userId, entitlement, isActive, expiresAt, updatedAt);

  @override
  String toString() {
    return 'UserEntitlement(userId: $userId, entitlement: $entitlement, isActive: $isActive, expiresAt: $expiresAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $UserEntitlementCopyWith<$Res> {
  factory $UserEntitlementCopyWith(
          UserEntitlement value, $Res Function(UserEntitlement) _then) =
      _$UserEntitlementCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'user_id') String userId,
      String entitlement,
      @JsonKey(name: 'is_active') bool isActive,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt});
}

/// @nodoc
class _$UserEntitlementCopyWithImpl<$Res>
    implements $UserEntitlementCopyWith<$Res> {
  _$UserEntitlementCopyWithImpl(this._self, this._then);

  final UserEntitlement _self;
  final $Res Function(UserEntitlement) _then;

  /// Create a copy of UserEntitlement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? entitlement = null,
    Object? isActive = null,
    Object? expiresAt = freezed,
    Object? updatedAt = null,
  }) {
    return _then(_self.copyWith(
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      entitlement: null == entitlement
          ? _self.entitlement
          : entitlement // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      expiresAt: freezed == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _UserEntitlement implements UserEntitlement {
  const _UserEntitlement(
      {@JsonKey(name: 'user_id') required this.userId,
      required this.entitlement,
      @JsonKey(name: 'is_active') required this.isActive,
      @JsonKey(name: 'expires_at') this.expiresAt,
      @JsonKey(name: 'updated_at') required this.updatedAt});
  factory _UserEntitlement.fromJson(Map<String, dynamic> json) =>
      _$UserEntitlementFromJson(json);

  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final String entitlement;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  /// Create a copy of UserEntitlement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UserEntitlementCopyWith<_UserEntitlement> get copyWith =>
      __$UserEntitlementCopyWithImpl<_UserEntitlement>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$UserEntitlementToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UserEntitlement &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.entitlement, entitlement) ||
                other.entitlement == entitlement) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, userId, entitlement, isActive, expiresAt, updatedAt);

  @override
  String toString() {
    return 'UserEntitlement(userId: $userId, entitlement: $entitlement, isActive: $isActive, expiresAt: $expiresAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$UserEntitlementCopyWith<$Res>
    implements $UserEntitlementCopyWith<$Res> {
  factory _$UserEntitlementCopyWith(
          _UserEntitlement value, $Res Function(_UserEntitlement) _then) =
      __$UserEntitlementCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'user_id') String userId,
      String entitlement,
      @JsonKey(name: 'is_active') bool isActive,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt});
}

/// @nodoc
class __$UserEntitlementCopyWithImpl<$Res>
    implements _$UserEntitlementCopyWith<$Res> {
  __$UserEntitlementCopyWithImpl(this._self, this._then);

  final _UserEntitlement _self;
  final $Res Function(_UserEntitlement) _then;

  /// Create a copy of UserEntitlement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? userId = null,
    Object? entitlement = null,
    Object? isActive = null,
    Object? expiresAt = freezed,
    Object? updatedAt = null,
  }) {
    return _then(_UserEntitlement(
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      entitlement: null == entitlement
          ? _self.entitlement
          : entitlement // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      expiresAt: freezed == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
mixin _$Subscription {
  String get id;
  @JsonKey(name: 'user_id')
  String get userId;
  @JsonKey(name: 'revenuecat_user_id')
  String? get revenuecatUserId;
  @JsonKey(name: 'product_id')
  String get productId;
  @JsonKey(name: 'entitlement_id')
  String get entitlementId;
  SubscriptionStore get store;
  SubscriptionEnvironment get environment;
  SubscriptionStatus get status;
  @JsonKey(name: 'period_type')
  PeriodKind? get periodType;
  @JsonKey(name: 'purchased_at')
  DateTime? get purchasedAt;
  @JsonKey(name: 'renewed_at')
  DateTime? get renewedAt;
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;
  @JsonKey(name: 'canceled_at')
  DateTime? get canceledAt;

  /// Create a copy of Subscription
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SubscriptionCopyWith<Subscription> get copyWith =>
      _$SubscriptionCopyWithImpl<Subscription>(
          this as Subscription, _$identity);

  /// Serializes this Subscription to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Subscription &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.revenuecatUserId, revenuecatUserId) ||
                other.revenuecatUserId == revenuecatUserId) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.entitlementId, entitlementId) ||
                other.entitlementId == entitlementId) &&
            (identical(other.store, store) || other.store == store) &&
            (identical(other.environment, environment) ||
                other.environment == environment) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.periodType, periodType) ||
                other.periodType == periodType) &&
            (identical(other.purchasedAt, purchasedAt) ||
                other.purchasedAt == purchasedAt) &&
            (identical(other.renewedAt, renewedAt) ||
                other.renewedAt == renewedAt) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.canceledAt, canceledAt) ||
                other.canceledAt == canceledAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      revenuecatUserId,
      productId,
      entitlementId,
      store,
      environment,
      status,
      periodType,
      purchasedAt,
      renewedAt,
      expiresAt,
      canceledAt);

  @override
  String toString() {
    return 'Subscription(id: $id, userId: $userId, revenuecatUserId: $revenuecatUserId, productId: $productId, entitlementId: $entitlementId, store: $store, environment: $environment, status: $status, periodType: $periodType, purchasedAt: $purchasedAt, renewedAt: $renewedAt, expiresAt: $expiresAt, canceledAt: $canceledAt)';
  }
}

/// @nodoc
abstract mixin class $SubscriptionCopyWith<$Res> {
  factory $SubscriptionCopyWith(
          Subscription value, $Res Function(Subscription) _then) =
      _$SubscriptionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'revenuecat_user_id') String? revenuecatUserId,
      @JsonKey(name: 'product_id') String productId,
      @JsonKey(name: 'entitlement_id') String entitlementId,
      SubscriptionStore store,
      SubscriptionEnvironment environment,
      SubscriptionStatus status,
      @JsonKey(name: 'period_type') PeriodKind? periodType,
      @JsonKey(name: 'purchased_at') DateTime? purchasedAt,
      @JsonKey(name: 'renewed_at') DateTime? renewedAt,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      @JsonKey(name: 'canceled_at') DateTime? canceledAt});
}

/// @nodoc
class _$SubscriptionCopyWithImpl<$Res> implements $SubscriptionCopyWith<$Res> {
  _$SubscriptionCopyWithImpl(this._self, this._then);

  final Subscription _self;
  final $Res Function(Subscription) _then;

  /// Create a copy of Subscription
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? revenuecatUserId = freezed,
    Object? productId = null,
    Object? entitlementId = null,
    Object? store = null,
    Object? environment = null,
    Object? status = null,
    Object? periodType = freezed,
    Object? purchasedAt = freezed,
    Object? renewedAt = freezed,
    Object? expiresAt = freezed,
    Object? canceledAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      revenuecatUserId: freezed == revenuecatUserId
          ? _self.revenuecatUserId
          : revenuecatUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      productId: null == productId
          ? _self.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as String,
      entitlementId: null == entitlementId
          ? _self.entitlementId
          : entitlementId // ignore: cast_nullable_to_non_nullable
              as String,
      store: null == store
          ? _self.store
          : store // ignore: cast_nullable_to_non_nullable
              as SubscriptionStore,
      environment: null == environment
          ? _self.environment
          : environment // ignore: cast_nullable_to_non_nullable
              as SubscriptionEnvironment,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SubscriptionStatus,
      periodType: freezed == periodType
          ? _self.periodType
          : periodType // ignore: cast_nullable_to_non_nullable
              as PeriodKind?,
      purchasedAt: freezed == purchasedAt
          ? _self.purchasedAt
          : purchasedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      renewedAt: freezed == renewedAt
          ? _self.renewedAt
          : renewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      expiresAt: freezed == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      canceledAt: freezed == canceledAt
          ? _self.canceledAt
          : canceledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Subscription implements Subscription {
  const _Subscription(
      {required this.id,
      @JsonKey(name: 'user_id') required this.userId,
      @JsonKey(name: 'revenuecat_user_id') this.revenuecatUserId,
      @JsonKey(name: 'product_id') required this.productId,
      @JsonKey(name: 'entitlement_id') required this.entitlementId,
      required this.store,
      required this.environment,
      required this.status,
      @JsonKey(name: 'period_type') this.periodType,
      @JsonKey(name: 'purchased_at') this.purchasedAt,
      @JsonKey(name: 'renewed_at') this.renewedAt,
      @JsonKey(name: 'expires_at') this.expiresAt,
      @JsonKey(name: 'canceled_at') this.canceledAt});
  factory _Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'revenuecat_user_id')
  final String? revenuecatUserId;
  @override
  @JsonKey(name: 'product_id')
  final String productId;
  @override
  @JsonKey(name: 'entitlement_id')
  final String entitlementId;
  @override
  final SubscriptionStore store;
  @override
  final SubscriptionEnvironment environment;
  @override
  final SubscriptionStatus status;
  @override
  @JsonKey(name: 'period_type')
  final PeriodKind? periodType;
  @override
  @JsonKey(name: 'purchased_at')
  final DateTime? purchasedAt;
  @override
  @JsonKey(name: 'renewed_at')
  final DateTime? renewedAt;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @override
  @JsonKey(name: 'canceled_at')
  final DateTime? canceledAt;

  /// Create a copy of Subscription
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SubscriptionCopyWith<_Subscription> get copyWith =>
      __$SubscriptionCopyWithImpl<_Subscription>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SubscriptionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Subscription &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.revenuecatUserId, revenuecatUserId) ||
                other.revenuecatUserId == revenuecatUserId) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.entitlementId, entitlementId) ||
                other.entitlementId == entitlementId) &&
            (identical(other.store, store) || other.store == store) &&
            (identical(other.environment, environment) ||
                other.environment == environment) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.periodType, periodType) ||
                other.periodType == periodType) &&
            (identical(other.purchasedAt, purchasedAt) ||
                other.purchasedAt == purchasedAt) &&
            (identical(other.renewedAt, renewedAt) ||
                other.renewedAt == renewedAt) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.canceledAt, canceledAt) ||
                other.canceledAt == canceledAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      revenuecatUserId,
      productId,
      entitlementId,
      store,
      environment,
      status,
      periodType,
      purchasedAt,
      renewedAt,
      expiresAt,
      canceledAt);

  @override
  String toString() {
    return 'Subscription(id: $id, userId: $userId, revenuecatUserId: $revenuecatUserId, productId: $productId, entitlementId: $entitlementId, store: $store, environment: $environment, status: $status, periodType: $periodType, purchasedAt: $purchasedAt, renewedAt: $renewedAt, expiresAt: $expiresAt, canceledAt: $canceledAt)';
  }
}

/// @nodoc
abstract mixin class _$SubscriptionCopyWith<$Res>
    implements $SubscriptionCopyWith<$Res> {
  factory _$SubscriptionCopyWith(
          _Subscription value, $Res Function(_Subscription) _then) =
      __$SubscriptionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'revenuecat_user_id') String? revenuecatUserId,
      @JsonKey(name: 'product_id') String productId,
      @JsonKey(name: 'entitlement_id') String entitlementId,
      SubscriptionStore store,
      SubscriptionEnvironment environment,
      SubscriptionStatus status,
      @JsonKey(name: 'period_type') PeriodKind? periodType,
      @JsonKey(name: 'purchased_at') DateTime? purchasedAt,
      @JsonKey(name: 'renewed_at') DateTime? renewedAt,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      @JsonKey(name: 'canceled_at') DateTime? canceledAt});
}

/// @nodoc
class __$SubscriptionCopyWithImpl<$Res>
    implements _$SubscriptionCopyWith<$Res> {
  __$SubscriptionCopyWithImpl(this._self, this._then);

  final _Subscription _self;
  final $Res Function(_Subscription) _then;

  /// Create a copy of Subscription
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? revenuecatUserId = freezed,
    Object? productId = null,
    Object? entitlementId = null,
    Object? store = null,
    Object? environment = null,
    Object? status = null,
    Object? periodType = freezed,
    Object? purchasedAt = freezed,
    Object? renewedAt = freezed,
    Object? expiresAt = freezed,
    Object? canceledAt = freezed,
  }) {
    return _then(_Subscription(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      revenuecatUserId: freezed == revenuecatUserId
          ? _self.revenuecatUserId
          : revenuecatUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      productId: null == productId
          ? _self.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as String,
      entitlementId: null == entitlementId
          ? _self.entitlementId
          : entitlementId // ignore: cast_nullable_to_non_nullable
              as String,
      store: null == store
          ? _self.store
          : store // ignore: cast_nullable_to_non_nullable
              as SubscriptionStore,
      environment: null == environment
          ? _self.environment
          : environment // ignore: cast_nullable_to_non_nullable
              as SubscriptionEnvironment,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SubscriptionStatus,
      periodType: freezed == periodType
          ? _self.periodType
          : periodType // ignore: cast_nullable_to_non_nullable
              as PeriodKind?,
      purchasedAt: freezed == purchasedAt
          ? _self.purchasedAt
          : purchasedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      renewedAt: freezed == renewedAt
          ? _self.renewedAt
          : renewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      expiresAt: freezed == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      canceledAt: freezed == canceledAt
          ? _self.canceledAt
          : canceledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
