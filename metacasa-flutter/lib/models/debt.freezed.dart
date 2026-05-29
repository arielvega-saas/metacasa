// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'debt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Debt {
  String get id;
  @JsonKey(name: 'household_id')
  String get householdId;
  String get creditor;
  @JsonKey(name: 'original_amount')
  @DecimalConverter()
  Decimal get originalAmount;
  @JsonKey(name: 'current_balance')
  @DecimalConverter()
  Decimal get currentBalance;

  /// Tasa de interés **anual** en porcentaje (ej. 45.5 = 45.5%).
  @JsonKey(name: 'annual_rate')
  @DecimalConverter()
  Decimal get annualRate;

  /// Pago mensual sugerido (si está definido).
  @JsonKey(name: 'monthly_payment')
  @DecimalNullConverter()
  Decimal? get monthlyPayment;
  String get currency;
  @JsonKey(name: 'start_date')
  DateTime get startDate;
  @JsonKey(name: 'maturity_date')
  DateTime? get maturityDate;
  String? get category;
  String? get note;
  DebtStatus get status;
  @JsonKey(name: 'created_by')
  String get createdBy;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of Debt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DebtCopyWith<Debt> get copyWith =>
      _$DebtCopyWithImpl<Debt>(this as Debt, _$identity);

  /// Serializes this Debt to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Debt &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.creditor, creditor) ||
                other.creditor == creditor) &&
            (identical(other.originalAmount, originalAmount) ||
                other.originalAmount == originalAmount) &&
            (identical(other.currentBalance, currentBalance) ||
                other.currentBalance == currentBalance) &&
            (identical(other.annualRate, annualRate) ||
                other.annualRate == annualRate) &&
            (identical(other.monthlyPayment, monthlyPayment) ||
                other.monthlyPayment == monthlyPayment) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.maturityDate, maturityDate) ||
                other.maturityDate == maturityDate) &&
            (identical(other.category, category) ||
                other.category == category) &&
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
      creditor,
      originalAmount,
      currentBalance,
      annualRate,
      monthlyPayment,
      currency,
      startDate,
      maturityDate,
      category,
      note,
      status,
      createdBy,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'Debt(id: $id, householdId: $householdId, creditor: $creditor, originalAmount: $originalAmount, currentBalance: $currentBalance, annualRate: $annualRate, monthlyPayment: $monthlyPayment, currency: $currency, startDate: $startDate, maturityDate: $maturityDate, category: $category, note: $note, status: $status, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $DebtCopyWith<$Res> {
  factory $DebtCopyWith(Debt value, $Res Function(Debt) _then) =
      _$DebtCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String creditor,
      @JsonKey(name: 'original_amount')
      @DecimalConverter()
      Decimal originalAmount,
      @JsonKey(name: 'current_balance')
      @DecimalConverter()
      Decimal currentBalance,
      @JsonKey(name: 'annual_rate') @DecimalConverter() Decimal annualRate,
      @JsonKey(name: 'monthly_payment')
      @DecimalNullConverter()
      Decimal? monthlyPayment,
      String currency,
      @JsonKey(name: 'start_date') DateTime startDate,
      @JsonKey(name: 'maturity_date') DateTime? maturityDate,
      String? category,
      String? note,
      DebtStatus status,
      @JsonKey(name: 'created_by') String createdBy,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$DebtCopyWithImpl<$Res> implements $DebtCopyWith<$Res> {
  _$DebtCopyWithImpl(this._self, this._then);

  final Debt _self;
  final $Res Function(Debt) _then;

  /// Create a copy of Debt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? creditor = null,
    Object? originalAmount = null,
    Object? currentBalance = null,
    Object? annualRate = null,
    Object? monthlyPayment = freezed,
    Object? currency = null,
    Object? startDate = null,
    Object? maturityDate = freezed,
    Object? category = freezed,
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
      creditor: null == creditor
          ? _self.creditor
          : creditor // ignore: cast_nullable_to_non_nullable
              as String,
      originalAmount: null == originalAmount
          ? _self.originalAmount
          : originalAmount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currentBalance: null == currentBalance
          ? _self.currentBalance
          : currentBalance // ignore: cast_nullable_to_non_nullable
              as Decimal,
      annualRate: null == annualRate
          ? _self.annualRate
          : annualRate // ignore: cast_nullable_to_non_nullable
              as Decimal,
      monthlyPayment: freezed == monthlyPayment
          ? _self.monthlyPayment
          : monthlyPayment // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _self.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      maturityDate: freezed == maturityDate
          ? _self.maturityDate
          : maturityDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      category: freezed == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as DebtStatus,
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
class _Debt extends Debt {
  const _Debt(
      {required this.id,
      @JsonKey(name: 'household_id') required this.householdId,
      required this.creditor,
      @JsonKey(name: 'original_amount')
      @DecimalConverter()
      required this.originalAmount,
      @JsonKey(name: 'current_balance')
      @DecimalConverter()
      required this.currentBalance,
      @JsonKey(name: 'annual_rate')
      @DecimalConverter()
      required this.annualRate,
      @JsonKey(name: 'monthly_payment')
      @DecimalNullConverter()
      this.monthlyPayment,
      required this.currency,
      @JsonKey(name: 'start_date') required this.startDate,
      @JsonKey(name: 'maturity_date') this.maturityDate,
      this.category,
      this.note,
      required this.status,
      @JsonKey(name: 'created_by') required this.createdBy,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt})
      : super._();
  factory _Debt.fromJson(Map<String, dynamic> json) => _$DebtFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  final String creditor;
  @override
  @JsonKey(name: 'original_amount')
  @DecimalConverter()
  final Decimal originalAmount;
  @override
  @JsonKey(name: 'current_balance')
  @DecimalConverter()
  final Decimal currentBalance;

  /// Tasa de interés **anual** en porcentaje (ej. 45.5 = 45.5%).
  @override
  @JsonKey(name: 'annual_rate')
  @DecimalConverter()
  final Decimal annualRate;

  /// Pago mensual sugerido (si está definido).
  @override
  @JsonKey(name: 'monthly_payment')
  @DecimalNullConverter()
  final Decimal? monthlyPayment;
  @override
  final String currency;
  @override
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  @override
  @JsonKey(name: 'maturity_date')
  final DateTime? maturityDate;
  @override
  final String? category;
  @override
  final String? note;
  @override
  final DebtStatus status;
  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// Create a copy of Debt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DebtCopyWith<_Debt> get copyWith =>
      __$DebtCopyWithImpl<_Debt>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DebtToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Debt &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.creditor, creditor) ||
                other.creditor == creditor) &&
            (identical(other.originalAmount, originalAmount) ||
                other.originalAmount == originalAmount) &&
            (identical(other.currentBalance, currentBalance) ||
                other.currentBalance == currentBalance) &&
            (identical(other.annualRate, annualRate) ||
                other.annualRate == annualRate) &&
            (identical(other.monthlyPayment, monthlyPayment) ||
                other.monthlyPayment == monthlyPayment) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.maturityDate, maturityDate) ||
                other.maturityDate == maturityDate) &&
            (identical(other.category, category) ||
                other.category == category) &&
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
      creditor,
      originalAmount,
      currentBalance,
      annualRate,
      monthlyPayment,
      currency,
      startDate,
      maturityDate,
      category,
      note,
      status,
      createdBy,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'Debt(id: $id, householdId: $householdId, creditor: $creditor, originalAmount: $originalAmount, currentBalance: $currentBalance, annualRate: $annualRate, monthlyPayment: $monthlyPayment, currency: $currency, startDate: $startDate, maturityDate: $maturityDate, category: $category, note: $note, status: $status, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$DebtCopyWith<$Res> implements $DebtCopyWith<$Res> {
  factory _$DebtCopyWith(_Debt value, $Res Function(_Debt) _then) =
      __$DebtCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String creditor,
      @JsonKey(name: 'original_amount')
      @DecimalConverter()
      Decimal originalAmount,
      @JsonKey(name: 'current_balance')
      @DecimalConverter()
      Decimal currentBalance,
      @JsonKey(name: 'annual_rate') @DecimalConverter() Decimal annualRate,
      @JsonKey(name: 'monthly_payment')
      @DecimalNullConverter()
      Decimal? monthlyPayment,
      String currency,
      @JsonKey(name: 'start_date') DateTime startDate,
      @JsonKey(name: 'maturity_date') DateTime? maturityDate,
      String? category,
      String? note,
      DebtStatus status,
      @JsonKey(name: 'created_by') String createdBy,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$DebtCopyWithImpl<$Res> implements _$DebtCopyWith<$Res> {
  __$DebtCopyWithImpl(this._self, this._then);

  final _Debt _self;
  final $Res Function(_Debt) _then;

  /// Create a copy of Debt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? creditor = null,
    Object? originalAmount = null,
    Object? currentBalance = null,
    Object? annualRate = null,
    Object? monthlyPayment = freezed,
    Object? currency = null,
    Object? startDate = null,
    Object? maturityDate = freezed,
    Object? category = freezed,
    Object? note = freezed,
    Object? status = null,
    Object? createdBy = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_Debt(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      creditor: null == creditor
          ? _self.creditor
          : creditor // ignore: cast_nullable_to_non_nullable
              as String,
      originalAmount: null == originalAmount
          ? _self.originalAmount
          : originalAmount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currentBalance: null == currentBalance
          ? _self.currentBalance
          : currentBalance // ignore: cast_nullable_to_non_nullable
              as Decimal,
      annualRate: null == annualRate
          ? _self.annualRate
          : annualRate // ignore: cast_nullable_to_non_nullable
              as Decimal,
      monthlyPayment: freezed == monthlyPayment
          ? _self.monthlyPayment
          : monthlyPayment // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _self.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      maturityDate: freezed == maturityDate
          ? _self.maturityDate
          : maturityDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      category: freezed == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as DebtStatus,
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

// dart format on
