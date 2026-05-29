// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Account {
  String get id;
  @JsonKey(name: 'household_id')
  String get householdId;
  String get name;
  AccountType get type;
  String get currency;
  @JsonKey(name: 'starting_balance')
  @DecimalConverter()
  Decimal get startingBalance;
  String? get institution;
  @JsonKey(name: 'account_number_last4')
  String? get accountNumberLast4;
  String? get icon;
  String? get color;
  @JsonKey(name: 'display_order')
  int get displayOrder;
  @JsonKey(name: 'is_active')
  bool get isActive;
  String? get notes;
  AccountOwnership get ownership;
  @JsonKey(name: 'owner_user_id')
  String? get ownerUserId;
  @JsonKey(name: 'created_by')
  String get createdBy;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AccountCopyWith<Account> get copyWith =>
      _$AccountCopyWithImpl<Account>(this as Account, _$identity);

  /// Serializes this Account to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Account &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.startingBalance, startingBalance) ||
                other.startingBalance == startingBalance) &&
            (identical(other.institution, institution) ||
                other.institution == institution) &&
            (identical(other.accountNumberLast4, accountNumberLast4) ||
                other.accountNumberLast4 == accountNumberLast4) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.displayOrder, displayOrder) ||
                other.displayOrder == displayOrder) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.ownership, ownership) ||
                other.ownership == ownership) &&
            (identical(other.ownerUserId, ownerUserId) ||
                other.ownerUserId == ownerUserId) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      householdId,
      name,
      type,
      currency,
      startingBalance,
      institution,
      accountNumberLast4,
      icon,
      color,
      displayOrder,
      isActive,
      notes,
      ownership,
      ownerUserId,
      createdBy,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'Account(id: $id, householdId: $householdId, name: $name, type: $type, currency: $currency, startingBalance: $startingBalance, institution: $institution, accountNumberLast4: $accountNumberLast4, icon: $icon, color: $color, displayOrder: $displayOrder, isActive: $isActive, notes: $notes, ownership: $ownership, ownerUserId: $ownerUserId, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $AccountCopyWith<$Res> {
  factory $AccountCopyWith(Account value, $Res Function(Account) _then) =
      _$AccountCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String name,
      AccountType type,
      String currency,
      @JsonKey(name: 'starting_balance')
      @DecimalConverter()
      Decimal startingBalance,
      String? institution,
      @JsonKey(name: 'account_number_last4') String? accountNumberLast4,
      String? icon,
      String? color,
      @JsonKey(name: 'display_order') int displayOrder,
      @JsonKey(name: 'is_active') bool isActive,
      String? notes,
      AccountOwnership ownership,
      @JsonKey(name: 'owner_user_id') String? ownerUserId,
      @JsonKey(name: 'created_by') String createdBy,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$AccountCopyWithImpl<$Res> implements $AccountCopyWith<$Res> {
  _$AccountCopyWithImpl(this._self, this._then);

  final Account _self;
  final $Res Function(Account) _then;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? name = null,
    Object? type = null,
    Object? currency = null,
    Object? startingBalance = null,
    Object? institution = freezed,
    Object? accountNumberLast4 = freezed,
    Object? icon = freezed,
    Object? color = freezed,
    Object? displayOrder = null,
    Object? isActive = null,
    Object? notes = freezed,
    Object? ownership = null,
    Object? ownerUserId = freezed,
    Object? createdBy = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as AccountType,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      startingBalance: null == startingBalance
          ? _self.startingBalance
          : startingBalance // ignore: cast_nullable_to_non_nullable
              as Decimal,
      institution: freezed == institution
          ? _self.institution
          : institution // ignore: cast_nullable_to_non_nullable
              as String?,
      accountNumberLast4: freezed == accountNumberLast4
          ? _self.accountNumberLast4
          : accountNumberLast4 // ignore: cast_nullable_to_non_nullable
              as String?,
      icon: freezed == icon
          ? _self.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      color: freezed == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
      displayOrder: null == displayOrder
          ? _self.displayOrder
          : displayOrder // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      ownership: null == ownership
          ? _self.ownership
          : ownership // ignore: cast_nullable_to_non_nullable
              as AccountOwnership,
      ownerUserId: freezed == ownerUserId
          ? _self.ownerUserId
          : ownerUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdBy: null == createdBy
          ? _self.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Account implements Account {
  const _Account(
      {required this.id,
      @JsonKey(name: 'household_id') required this.householdId,
      required this.name,
      required this.type,
      required this.currency,
      @JsonKey(name: 'starting_balance')
      @DecimalConverter()
      required this.startingBalance,
      this.institution,
      @JsonKey(name: 'account_number_last4') this.accountNumberLast4,
      this.icon,
      this.color,
      @JsonKey(name: 'display_order') required this.displayOrder,
      @JsonKey(name: 'is_active') required this.isActive,
      this.notes,
      this.ownership = AccountOwnership.personal,
      @JsonKey(name: 'owner_user_id') this.ownerUserId,
      @JsonKey(name: 'created_by') required this.createdBy,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt});
  factory _Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  final String name;
  @override
  final AccountType type;
  @override
  final String currency;
  @override
  @JsonKey(name: 'starting_balance')
  @DecimalConverter()
  final Decimal startingBalance;
  @override
  final String? institution;
  @override
  @JsonKey(name: 'account_number_last4')
  final String? accountNumberLast4;
  @override
  final String? icon;
  @override
  final String? color;
  @override
  @JsonKey(name: 'display_order')
  final int displayOrder;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  final String? notes;
  @override
  @JsonKey()
  final AccountOwnership ownership;
  @override
  @JsonKey(name: 'owner_user_id')
  final String? ownerUserId;
  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AccountCopyWith<_Account> get copyWith =>
      __$AccountCopyWithImpl<_Account>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AccountToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Account &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.startingBalance, startingBalance) ||
                other.startingBalance == startingBalance) &&
            (identical(other.institution, institution) ||
                other.institution == institution) &&
            (identical(other.accountNumberLast4, accountNumberLast4) ||
                other.accountNumberLast4 == accountNumberLast4) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.displayOrder, displayOrder) ||
                other.displayOrder == displayOrder) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.ownership, ownership) ||
                other.ownership == ownership) &&
            (identical(other.ownerUserId, ownerUserId) ||
                other.ownerUserId == ownerUserId) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      householdId,
      name,
      type,
      currency,
      startingBalance,
      institution,
      accountNumberLast4,
      icon,
      color,
      displayOrder,
      isActive,
      notes,
      ownership,
      ownerUserId,
      createdBy,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'Account(id: $id, householdId: $householdId, name: $name, type: $type, currency: $currency, startingBalance: $startingBalance, institution: $institution, accountNumberLast4: $accountNumberLast4, icon: $icon, color: $color, displayOrder: $displayOrder, isActive: $isActive, notes: $notes, ownership: $ownership, ownerUserId: $ownerUserId, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$AccountCopyWith<$Res> implements $AccountCopyWith<$Res> {
  factory _$AccountCopyWith(_Account value, $Res Function(_Account) _then) =
      __$AccountCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String name,
      AccountType type,
      String currency,
      @JsonKey(name: 'starting_balance')
      @DecimalConverter()
      Decimal startingBalance,
      String? institution,
      @JsonKey(name: 'account_number_last4') String? accountNumberLast4,
      String? icon,
      String? color,
      @JsonKey(name: 'display_order') int displayOrder,
      @JsonKey(name: 'is_active') bool isActive,
      String? notes,
      AccountOwnership ownership,
      @JsonKey(name: 'owner_user_id') String? ownerUserId,
      @JsonKey(name: 'created_by') String createdBy,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$AccountCopyWithImpl<$Res> implements _$AccountCopyWith<$Res> {
  __$AccountCopyWithImpl(this._self, this._then);

  final _Account _self;
  final $Res Function(_Account) _then;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? name = null,
    Object? type = null,
    Object? currency = null,
    Object? startingBalance = null,
    Object? institution = freezed,
    Object? accountNumberLast4 = freezed,
    Object? icon = freezed,
    Object? color = freezed,
    Object? displayOrder = null,
    Object? isActive = null,
    Object? notes = freezed,
    Object? ownership = null,
    Object? ownerUserId = freezed,
    Object? createdBy = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_Account(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as AccountType,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      startingBalance: null == startingBalance
          ? _self.startingBalance
          : startingBalance // ignore: cast_nullable_to_non_nullable
              as Decimal,
      institution: freezed == institution
          ? _self.institution
          : institution // ignore: cast_nullable_to_non_nullable
              as String?,
      accountNumberLast4: freezed == accountNumberLast4
          ? _self.accountNumberLast4
          : accountNumberLast4 // ignore: cast_nullable_to_non_nullable
              as String?,
      icon: freezed == icon
          ? _self.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      color: freezed == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
      displayOrder: null == displayOrder
          ? _self.displayOrder
          : displayOrder // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      ownership: null == ownership
          ? _self.ownership
          : ownership // ignore: cast_nullable_to_non_nullable
              as AccountOwnership,
      ownerUserId: freezed == ownerUserId
          ? _self.ownerUserId
          : ownerUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdBy: null == createdBy
          ? _self.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
mixin _$CreditCardDetails {
  @JsonKey(name: 'account_id')
  String get accountId;
  @JsonKey(name: 'credit_limit')
  @DecimalConverter()
  Decimal get creditLimit;
  @JsonKey(name: 'statement_day')
  int get statementDay;
  @JsonKey(name: 'due_day')
  int get dueDay;
  @JsonKey(name: 'interest_rate_monthly')
  @DecimalConverter()
  Decimal get interestRateMonthly;
  @JsonKey(name: 'minimum_payment_pct')
  @DecimalConverter()
  Decimal get minimumPaymentPct;
  @JsonKey(name: 'last_statement_amount')
  @DecimalNullConverter()
  Decimal? get lastStatementAmount;
  @JsonKey(name: 'last_statement_date')
  DateTime? get lastStatementDate;
  CardNetwork? get network;

  /// Create a copy of CreditCardDetails
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CreditCardDetailsCopyWith<CreditCardDetails> get copyWith =>
      _$CreditCardDetailsCopyWithImpl<CreditCardDetails>(
          this as CreditCardDetails, _$identity);

  /// Serializes this CreditCardDetails to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CreditCardDetails &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.creditLimit, creditLimit) ||
                other.creditLimit == creditLimit) &&
            (identical(other.statementDay, statementDay) ||
                other.statementDay == statementDay) &&
            (identical(other.dueDay, dueDay) || other.dueDay == dueDay) &&
            (identical(other.interestRateMonthly, interestRateMonthly) ||
                other.interestRateMonthly == interestRateMonthly) &&
            (identical(other.minimumPaymentPct, minimumPaymentPct) ||
                other.minimumPaymentPct == minimumPaymentPct) &&
            (identical(other.lastStatementAmount, lastStatementAmount) ||
                other.lastStatementAmount == lastStatementAmount) &&
            (identical(other.lastStatementDate, lastStatementDate) ||
                other.lastStatementDate == lastStatementDate) &&
            (identical(other.network, network) || other.network == network));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      accountId,
      creditLimit,
      statementDay,
      dueDay,
      interestRateMonthly,
      minimumPaymentPct,
      lastStatementAmount,
      lastStatementDate,
      network);

  @override
  String toString() {
    return 'CreditCardDetails(accountId: $accountId, creditLimit: $creditLimit, statementDay: $statementDay, dueDay: $dueDay, interestRateMonthly: $interestRateMonthly, minimumPaymentPct: $minimumPaymentPct, lastStatementAmount: $lastStatementAmount, lastStatementDate: $lastStatementDate, network: $network)';
  }
}

/// @nodoc
abstract mixin class $CreditCardDetailsCopyWith<$Res> {
  factory $CreditCardDetailsCopyWith(
          CreditCardDetails value, $Res Function(CreditCardDetails) _then) =
      _$CreditCardDetailsCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'account_id') String accountId,
      @JsonKey(name: 'credit_limit') @DecimalConverter() Decimal creditLimit,
      @JsonKey(name: 'statement_day') int statementDay,
      @JsonKey(name: 'due_day') int dueDay,
      @JsonKey(name: 'interest_rate_monthly')
      @DecimalConverter()
      Decimal interestRateMonthly,
      @JsonKey(name: 'minimum_payment_pct')
      @DecimalConverter()
      Decimal minimumPaymentPct,
      @JsonKey(name: 'last_statement_amount')
      @DecimalNullConverter()
      Decimal? lastStatementAmount,
      @JsonKey(name: 'last_statement_date') DateTime? lastStatementDate,
      CardNetwork? network});
}

/// @nodoc
class _$CreditCardDetailsCopyWithImpl<$Res>
    implements $CreditCardDetailsCopyWith<$Res> {
  _$CreditCardDetailsCopyWithImpl(this._self, this._then);

  final CreditCardDetails _self;
  final $Res Function(CreditCardDetails) _then;

  /// Create a copy of CreditCardDetails
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accountId = null,
    Object? creditLimit = null,
    Object? statementDay = null,
    Object? dueDay = null,
    Object? interestRateMonthly = null,
    Object? minimumPaymentPct = null,
    Object? lastStatementAmount = freezed,
    Object? lastStatementDate = freezed,
    Object? network = freezed,
  }) {
    return _then(_self.copyWith(
      accountId: null == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      creditLimit: null == creditLimit
          ? _self.creditLimit
          : creditLimit // ignore: cast_nullable_to_non_nullable
              as Decimal,
      statementDay: null == statementDay
          ? _self.statementDay
          : statementDay // ignore: cast_nullable_to_non_nullable
              as int,
      dueDay: null == dueDay
          ? _self.dueDay
          : dueDay // ignore: cast_nullable_to_non_nullable
              as int,
      interestRateMonthly: null == interestRateMonthly
          ? _self.interestRateMonthly
          : interestRateMonthly // ignore: cast_nullable_to_non_nullable
              as Decimal,
      minimumPaymentPct: null == minimumPaymentPct
          ? _self.minimumPaymentPct
          : minimumPaymentPct // ignore: cast_nullable_to_non_nullable
              as Decimal,
      lastStatementAmount: freezed == lastStatementAmount
          ? _self.lastStatementAmount
          : lastStatementAmount // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      lastStatementDate: freezed == lastStatementDate
          ? _self.lastStatementDate
          : lastStatementDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      network: freezed == network
          ? _self.network
          : network // ignore: cast_nullable_to_non_nullable
              as CardNetwork?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _CreditCardDetails implements CreditCardDetails {
  const _CreditCardDetails(
      {@JsonKey(name: 'account_id') required this.accountId,
      @JsonKey(name: 'credit_limit')
      @DecimalConverter()
      required this.creditLimit,
      @JsonKey(name: 'statement_day') required this.statementDay,
      @JsonKey(name: 'due_day') required this.dueDay,
      @JsonKey(name: 'interest_rate_monthly')
      @DecimalConverter()
      required this.interestRateMonthly,
      @JsonKey(name: 'minimum_payment_pct')
      @DecimalConverter()
      required this.minimumPaymentPct,
      @JsonKey(name: 'last_statement_amount')
      @DecimalNullConverter()
      this.lastStatementAmount,
      @JsonKey(name: 'last_statement_date') this.lastStatementDate,
      this.network});
  factory _CreditCardDetails.fromJson(Map<String, dynamic> json) =>
      _$CreditCardDetailsFromJson(json);

  @override
  @JsonKey(name: 'account_id')
  final String accountId;
  @override
  @JsonKey(name: 'credit_limit')
  @DecimalConverter()
  final Decimal creditLimit;
  @override
  @JsonKey(name: 'statement_day')
  final int statementDay;
  @override
  @JsonKey(name: 'due_day')
  final int dueDay;
  @override
  @JsonKey(name: 'interest_rate_monthly')
  @DecimalConverter()
  final Decimal interestRateMonthly;
  @override
  @JsonKey(name: 'minimum_payment_pct')
  @DecimalConverter()
  final Decimal minimumPaymentPct;
  @override
  @JsonKey(name: 'last_statement_amount')
  @DecimalNullConverter()
  final Decimal? lastStatementAmount;
  @override
  @JsonKey(name: 'last_statement_date')
  final DateTime? lastStatementDate;
  @override
  final CardNetwork? network;

  /// Create a copy of CreditCardDetails
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CreditCardDetailsCopyWith<_CreditCardDetails> get copyWith =>
      __$CreditCardDetailsCopyWithImpl<_CreditCardDetails>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CreditCardDetailsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CreditCardDetails &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.creditLimit, creditLimit) ||
                other.creditLimit == creditLimit) &&
            (identical(other.statementDay, statementDay) ||
                other.statementDay == statementDay) &&
            (identical(other.dueDay, dueDay) || other.dueDay == dueDay) &&
            (identical(other.interestRateMonthly, interestRateMonthly) ||
                other.interestRateMonthly == interestRateMonthly) &&
            (identical(other.minimumPaymentPct, minimumPaymentPct) ||
                other.minimumPaymentPct == minimumPaymentPct) &&
            (identical(other.lastStatementAmount, lastStatementAmount) ||
                other.lastStatementAmount == lastStatementAmount) &&
            (identical(other.lastStatementDate, lastStatementDate) ||
                other.lastStatementDate == lastStatementDate) &&
            (identical(other.network, network) || other.network == network));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      accountId,
      creditLimit,
      statementDay,
      dueDay,
      interestRateMonthly,
      minimumPaymentPct,
      lastStatementAmount,
      lastStatementDate,
      network);

  @override
  String toString() {
    return 'CreditCardDetails(accountId: $accountId, creditLimit: $creditLimit, statementDay: $statementDay, dueDay: $dueDay, interestRateMonthly: $interestRateMonthly, minimumPaymentPct: $minimumPaymentPct, lastStatementAmount: $lastStatementAmount, lastStatementDate: $lastStatementDate, network: $network)';
  }
}

/// @nodoc
abstract mixin class _$CreditCardDetailsCopyWith<$Res>
    implements $CreditCardDetailsCopyWith<$Res> {
  factory _$CreditCardDetailsCopyWith(
          _CreditCardDetails value, $Res Function(_CreditCardDetails) _then) =
      __$CreditCardDetailsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'account_id') String accountId,
      @JsonKey(name: 'credit_limit') @DecimalConverter() Decimal creditLimit,
      @JsonKey(name: 'statement_day') int statementDay,
      @JsonKey(name: 'due_day') int dueDay,
      @JsonKey(name: 'interest_rate_monthly')
      @DecimalConverter()
      Decimal interestRateMonthly,
      @JsonKey(name: 'minimum_payment_pct')
      @DecimalConverter()
      Decimal minimumPaymentPct,
      @JsonKey(name: 'last_statement_amount')
      @DecimalNullConverter()
      Decimal? lastStatementAmount,
      @JsonKey(name: 'last_statement_date') DateTime? lastStatementDate,
      CardNetwork? network});
}

/// @nodoc
class __$CreditCardDetailsCopyWithImpl<$Res>
    implements _$CreditCardDetailsCopyWith<$Res> {
  __$CreditCardDetailsCopyWithImpl(this._self, this._then);

  final _CreditCardDetails _self;
  final $Res Function(_CreditCardDetails) _then;

  /// Create a copy of CreditCardDetails
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? accountId = null,
    Object? creditLimit = null,
    Object? statementDay = null,
    Object? dueDay = null,
    Object? interestRateMonthly = null,
    Object? minimumPaymentPct = null,
    Object? lastStatementAmount = freezed,
    Object? lastStatementDate = freezed,
    Object? network = freezed,
  }) {
    return _then(_CreditCardDetails(
      accountId: null == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      creditLimit: null == creditLimit
          ? _self.creditLimit
          : creditLimit // ignore: cast_nullable_to_non_nullable
              as Decimal,
      statementDay: null == statementDay
          ? _self.statementDay
          : statementDay // ignore: cast_nullable_to_non_nullable
              as int,
      dueDay: null == dueDay
          ? _self.dueDay
          : dueDay // ignore: cast_nullable_to_non_nullable
              as int,
      interestRateMonthly: null == interestRateMonthly
          ? _self.interestRateMonthly
          : interestRateMonthly // ignore: cast_nullable_to_non_nullable
              as Decimal,
      minimumPaymentPct: null == minimumPaymentPct
          ? _self.minimumPaymentPct
          : minimumPaymentPct // ignore: cast_nullable_to_non_nullable
              as Decimal,
      lastStatementAmount: freezed == lastStatementAmount
          ? _self.lastStatementAmount
          : lastStatementAmount // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      lastStatementDate: freezed == lastStatementDate
          ? _self.lastStatementDate
          : lastStatementDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      network: freezed == network
          ? _self.network
          : network // ignore: cast_nullable_to_non_nullable
              as CardNetwork?,
    ));
  }
}

// dart format on
