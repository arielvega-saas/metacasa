// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'installment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InstallmentPlan {
  String get id;
  @JsonKey(name: 'household_id')
  String get householdId;
  String get name;
  @JsonKey(name: 'total_amount')
  @DecimalConverter()
  Decimal get totalAmount;
  @JsonKey(name: 'total_installments')
  int get totalInstallments;
  String get currency;
  @JsonKey(name: 'start_year')
  int get startYear;
  @JsonKey(name: 'start_month')
  int get startMonth;
  String? get category;
  @JsonKey(name: 'account_id')
  String? get accountId;
  String? get note;
  PlanStatus get status;
  @JsonKey(name: 'created_by')
  String get createdBy;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of InstallmentPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $InstallmentPlanCopyWith<InstallmentPlan> get copyWith =>
      _$InstallmentPlanCopyWithImpl<InstallmentPlan>(
          this as InstallmentPlan, _$identity);

  /// Serializes this InstallmentPlan to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is InstallmentPlan &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.totalInstallments, totalInstallments) ||
                other.totalInstallments == totalInstallments) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.startYear, startYear) ||
                other.startYear == startYear) &&
            (identical(other.startMonth, startMonth) ||
                other.startMonth == startMonth) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.status, status) || other.status == status) &&
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
      totalAmount,
      totalInstallments,
      currency,
      startYear,
      startMonth,
      category,
      accountId,
      note,
      status,
      createdBy,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'InstallmentPlan(id: $id, householdId: $householdId, name: $name, totalAmount: $totalAmount, totalInstallments: $totalInstallments, currency: $currency, startYear: $startYear, startMonth: $startMonth, category: $category, accountId: $accountId, note: $note, status: $status, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $InstallmentPlanCopyWith<$Res> {
  factory $InstallmentPlanCopyWith(
          InstallmentPlan value, $Res Function(InstallmentPlan) _then) =
      _$InstallmentPlanCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String name,
      @JsonKey(name: 'total_amount') @DecimalConverter() Decimal totalAmount,
      @JsonKey(name: 'total_installments') int totalInstallments,
      String currency,
      @JsonKey(name: 'start_year') int startYear,
      @JsonKey(name: 'start_month') int startMonth,
      String? category,
      @JsonKey(name: 'account_id') String? accountId,
      String? note,
      PlanStatus status,
      @JsonKey(name: 'created_by') String createdBy,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$InstallmentPlanCopyWithImpl<$Res>
    implements $InstallmentPlanCopyWith<$Res> {
  _$InstallmentPlanCopyWithImpl(this._self, this._then);

  final InstallmentPlan _self;
  final $Res Function(InstallmentPlan) _then;

  /// Create a copy of InstallmentPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? name = null,
    Object? totalAmount = null,
    Object? totalInstallments = null,
    Object? currency = null,
    Object? startYear = null,
    Object? startMonth = null,
    Object? category = freezed,
    Object? accountId = freezed,
    Object? note = freezed,
    Object? status = null,
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
      totalAmount: null == totalAmount
          ? _self.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalInstallments: null == totalInstallments
          ? _self.totalInstallments
          : totalInstallments // ignore: cast_nullable_to_non_nullable
              as int,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      startYear: null == startYear
          ? _self.startYear
          : startYear // ignore: cast_nullable_to_non_nullable
              as int,
      startMonth: null == startMonth
          ? _self.startMonth
          : startMonth // ignore: cast_nullable_to_non_nullable
              as int,
      category: freezed == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      accountId: freezed == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String?,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as PlanStatus,
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
class _InstallmentPlan extends InstallmentPlan {
  const _InstallmentPlan(
      {required this.id,
      @JsonKey(name: 'household_id') required this.householdId,
      required this.name,
      @JsonKey(name: 'total_amount')
      @DecimalConverter()
      required this.totalAmount,
      @JsonKey(name: 'total_installments') required this.totalInstallments,
      required this.currency,
      @JsonKey(name: 'start_year') required this.startYear,
      @JsonKey(name: 'start_month') required this.startMonth,
      this.category,
      @JsonKey(name: 'account_id') this.accountId,
      this.note,
      required this.status,
      @JsonKey(name: 'created_by') required this.createdBy,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt})
      : super._();
  factory _InstallmentPlan.fromJson(Map<String, dynamic> json) =>
      _$InstallmentPlanFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  final String name;
  @override
  @JsonKey(name: 'total_amount')
  @DecimalConverter()
  final Decimal totalAmount;
  @override
  @JsonKey(name: 'total_installments')
  final int totalInstallments;
  @override
  final String currency;
  @override
  @JsonKey(name: 'start_year')
  final int startYear;
  @override
  @JsonKey(name: 'start_month')
  final int startMonth;
  @override
  final String? category;
  @override
  @JsonKey(name: 'account_id')
  final String? accountId;
  @override
  final String? note;
  @override
  final PlanStatus status;
  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// Create a copy of InstallmentPlan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$InstallmentPlanCopyWith<_InstallmentPlan> get copyWith =>
      __$InstallmentPlanCopyWithImpl<_InstallmentPlan>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$InstallmentPlanToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _InstallmentPlan &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.totalInstallments, totalInstallments) ||
                other.totalInstallments == totalInstallments) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.startYear, startYear) ||
                other.startYear == startYear) &&
            (identical(other.startMonth, startMonth) ||
                other.startMonth == startMonth) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.status, status) || other.status == status) &&
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
      totalAmount,
      totalInstallments,
      currency,
      startYear,
      startMonth,
      category,
      accountId,
      note,
      status,
      createdBy,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'InstallmentPlan(id: $id, householdId: $householdId, name: $name, totalAmount: $totalAmount, totalInstallments: $totalInstallments, currency: $currency, startYear: $startYear, startMonth: $startMonth, category: $category, accountId: $accountId, note: $note, status: $status, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$InstallmentPlanCopyWith<$Res>
    implements $InstallmentPlanCopyWith<$Res> {
  factory _$InstallmentPlanCopyWith(
          _InstallmentPlan value, $Res Function(_InstallmentPlan) _then) =
      __$InstallmentPlanCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String name,
      @JsonKey(name: 'total_amount') @DecimalConverter() Decimal totalAmount,
      @JsonKey(name: 'total_installments') int totalInstallments,
      String currency,
      @JsonKey(name: 'start_year') int startYear,
      @JsonKey(name: 'start_month') int startMonth,
      String? category,
      @JsonKey(name: 'account_id') String? accountId,
      String? note,
      PlanStatus status,
      @JsonKey(name: 'created_by') String createdBy,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$InstallmentPlanCopyWithImpl<$Res>
    implements _$InstallmentPlanCopyWith<$Res> {
  __$InstallmentPlanCopyWithImpl(this._self, this._then);

  final _InstallmentPlan _self;
  final $Res Function(_InstallmentPlan) _then;

  /// Create a copy of InstallmentPlan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? name = null,
    Object? totalAmount = null,
    Object? totalInstallments = null,
    Object? currency = null,
    Object? startYear = null,
    Object? startMonth = null,
    Object? category = freezed,
    Object? accountId = freezed,
    Object? note = freezed,
    Object? status = null,
    Object? createdBy = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_InstallmentPlan(
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
      totalAmount: null == totalAmount
          ? _self.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalInstallments: null == totalInstallments
          ? _self.totalInstallments
          : totalInstallments // ignore: cast_nullable_to_non_nullable
              as int,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      startYear: null == startYear
          ? _self.startYear
          : startYear // ignore: cast_nullable_to_non_nullable
              as int,
      startMonth: null == startMonth
          ? _self.startMonth
          : startMonth // ignore: cast_nullable_to_non_nullable
              as int,
      category: freezed == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      accountId: freezed == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String?,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as PlanStatus,
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
mixin _$InstallmentPayment {
  String get id;
  @JsonKey(name: 'plan_id')
  String get planId;
  @JsonKey(name: 'period_year')
  int get periodYear;
  @JsonKey(name: 'period_month')
  int get periodMonth;
  @JsonKey(name: 'installment_number')
  int get installmentNumber;
  @DecimalConverter()
  Decimal get amount;
  bool get paid;
  @JsonKey(name: 'paid_at')
  DateTime? get paidAt;
  @JsonKey(name: 'transaction_id')
  String? get transactionId;

  /// Create a copy of InstallmentPayment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $InstallmentPaymentCopyWith<InstallmentPayment> get copyWith =>
      _$InstallmentPaymentCopyWithImpl<InstallmentPayment>(
          this as InstallmentPayment, _$identity);

  /// Serializes this InstallmentPayment to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is InstallmentPayment &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.periodYear, periodYear) ||
                other.periodYear == periodYear) &&
            (identical(other.periodMonth, periodMonth) ||
                other.periodMonth == periodMonth) &&
            (identical(other.installmentNumber, installmentNumber) ||
                other.installmentNumber == installmentNumber) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.paid, paid) || other.paid == paid) &&
            (identical(other.paidAt, paidAt) || other.paidAt == paidAt) &&
            (identical(other.transactionId, transactionId) ||
                other.transactionId == transactionId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, planId, periodYear,
      periodMonth, installmentNumber, amount, paid, paidAt, transactionId);

  @override
  String toString() {
    return 'InstallmentPayment(id: $id, planId: $planId, periodYear: $periodYear, periodMonth: $periodMonth, installmentNumber: $installmentNumber, amount: $amount, paid: $paid, paidAt: $paidAt, transactionId: $transactionId)';
  }
}

/// @nodoc
abstract mixin class $InstallmentPaymentCopyWith<$Res> {
  factory $InstallmentPaymentCopyWith(
          InstallmentPayment value, $Res Function(InstallmentPayment) _then) =
      _$InstallmentPaymentCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'plan_id') String planId,
      @JsonKey(name: 'period_year') int periodYear,
      @JsonKey(name: 'period_month') int periodMonth,
      @JsonKey(name: 'installment_number') int installmentNumber,
      @DecimalConverter() Decimal amount,
      bool paid,
      @JsonKey(name: 'paid_at') DateTime? paidAt,
      @JsonKey(name: 'transaction_id') String? transactionId});
}

/// @nodoc
class _$InstallmentPaymentCopyWithImpl<$Res>
    implements $InstallmentPaymentCopyWith<$Res> {
  _$InstallmentPaymentCopyWithImpl(this._self, this._then);

  final InstallmentPayment _self;
  final $Res Function(InstallmentPayment) _then;

  /// Create a copy of InstallmentPayment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? periodYear = null,
    Object? periodMonth = null,
    Object? installmentNumber = null,
    Object? amount = null,
    Object? paid = null,
    Object? paidAt = freezed,
    Object? transactionId = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _self.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      periodYear: null == periodYear
          ? _self.periodYear
          : periodYear // ignore: cast_nullable_to_non_nullable
              as int,
      periodMonth: null == periodMonth
          ? _self.periodMonth
          : periodMonth // ignore: cast_nullable_to_non_nullable
              as int,
      installmentNumber: null == installmentNumber
          ? _self.installmentNumber
          : installmentNumber // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      paid: null == paid
          ? _self.paid
          : paid // ignore: cast_nullable_to_non_nullable
              as bool,
      paidAt: freezed == paidAt
          ? _self.paidAt
          : paidAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      transactionId: freezed == transactionId
          ? _self.transactionId
          : transactionId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _InstallmentPayment implements InstallmentPayment {
  const _InstallmentPayment(
      {required this.id,
      @JsonKey(name: 'plan_id') required this.planId,
      @JsonKey(name: 'period_year') required this.periodYear,
      @JsonKey(name: 'period_month') required this.periodMonth,
      @JsonKey(name: 'installment_number') required this.installmentNumber,
      @DecimalConverter() required this.amount,
      required this.paid,
      @JsonKey(name: 'paid_at') this.paidAt,
      @JsonKey(name: 'transaction_id') this.transactionId});
  factory _InstallmentPayment.fromJson(Map<String, dynamic> json) =>
      _$InstallmentPaymentFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'plan_id')
  final String planId;
  @override
  @JsonKey(name: 'period_year')
  final int periodYear;
  @override
  @JsonKey(name: 'period_month')
  final int periodMonth;
  @override
  @JsonKey(name: 'installment_number')
  final int installmentNumber;
  @override
  @DecimalConverter()
  final Decimal amount;
  @override
  final bool paid;
  @override
  @JsonKey(name: 'paid_at')
  final DateTime? paidAt;
  @override
  @JsonKey(name: 'transaction_id')
  final String? transactionId;

  /// Create a copy of InstallmentPayment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$InstallmentPaymentCopyWith<_InstallmentPayment> get copyWith =>
      __$InstallmentPaymentCopyWithImpl<_InstallmentPayment>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$InstallmentPaymentToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _InstallmentPayment &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.periodYear, periodYear) ||
                other.periodYear == periodYear) &&
            (identical(other.periodMonth, periodMonth) ||
                other.periodMonth == periodMonth) &&
            (identical(other.installmentNumber, installmentNumber) ||
                other.installmentNumber == installmentNumber) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.paid, paid) || other.paid == paid) &&
            (identical(other.paidAt, paidAt) || other.paidAt == paidAt) &&
            (identical(other.transactionId, transactionId) ||
                other.transactionId == transactionId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, planId, periodYear,
      periodMonth, installmentNumber, amount, paid, paidAt, transactionId);

  @override
  String toString() {
    return 'InstallmentPayment(id: $id, planId: $planId, periodYear: $periodYear, periodMonth: $periodMonth, installmentNumber: $installmentNumber, amount: $amount, paid: $paid, paidAt: $paidAt, transactionId: $transactionId)';
  }
}

/// @nodoc
abstract mixin class _$InstallmentPaymentCopyWith<$Res>
    implements $InstallmentPaymentCopyWith<$Res> {
  factory _$InstallmentPaymentCopyWith(
          _InstallmentPayment value, $Res Function(_InstallmentPayment) _then) =
      __$InstallmentPaymentCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'plan_id') String planId,
      @JsonKey(name: 'period_year') int periodYear,
      @JsonKey(name: 'period_month') int periodMonth,
      @JsonKey(name: 'installment_number') int installmentNumber,
      @DecimalConverter() Decimal amount,
      bool paid,
      @JsonKey(name: 'paid_at') DateTime? paidAt,
      @JsonKey(name: 'transaction_id') String? transactionId});
}

/// @nodoc
class __$InstallmentPaymentCopyWithImpl<$Res>
    implements _$InstallmentPaymentCopyWith<$Res> {
  __$InstallmentPaymentCopyWithImpl(this._self, this._then);

  final _InstallmentPayment _self;
  final $Res Function(_InstallmentPayment) _then;

  /// Create a copy of InstallmentPayment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? periodYear = null,
    Object? periodMonth = null,
    Object? installmentNumber = null,
    Object? amount = null,
    Object? paid = null,
    Object? paidAt = freezed,
    Object? transactionId = freezed,
  }) {
    return _then(_InstallmentPayment(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _self.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      periodYear: null == periodYear
          ? _self.periodYear
          : periodYear // ignore: cast_nullable_to_non_nullable
              as int,
      periodMonth: null == periodMonth
          ? _self.periodMonth
          : periodMonth // ignore: cast_nullable_to_non_nullable
              as int,
      installmentNumber: null == installmentNumber
          ? _self.installmentNumber
          : installmentNumber // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      paid: null == paid
          ? _self.paid
          : paid // ignore: cast_nullable_to_non_nullable
              as bool,
      paidAt: freezed == paidAt
          ? _self.paidAt
          : paidAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      transactionId: freezed == transactionId
          ? _self.transactionId
          : transactionId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
