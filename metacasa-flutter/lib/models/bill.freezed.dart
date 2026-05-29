// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bill.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Bill {
  String get id;
  @JsonKey(name: 'user_id')
  String get userId;
  @JsonKey(name: 'household_id')
  String get householdId;
  String get title;
  @DecimalConverter()
  Decimal get amount;
  String get currency;
  @JsonKey(name: 'due_date')
  DateTime get dueDate;
  BillStatus get status;
  String get category;
  @JsonKey(name: 'recurrence_type')
  String? get recurrenceType;
  @JsonKey(name: 'reminder_days')
  int? get reminderDays;
  @JsonKey(name: 'amount_original')
  @DecimalNullConverter()
  Decimal? get amountOriginal;
  @JsonKey(name: 'currency_original')
  String? get currencyOriginal;
  @JsonKey(name: 'fx_rate_to_base')
  @DecimalNullConverter()
  Decimal? get fxRateToBase;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of Bill
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BillCopyWith<Bill> get copyWith =>
      _$BillCopyWithImpl<Bill>(this as Bill, _$identity);

  /// Serializes this Bill to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Bill &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.recurrenceType, recurrenceType) ||
                other.recurrenceType == recurrenceType) &&
            (identical(other.reminderDays, reminderDays) ||
                other.reminderDays == reminderDays) &&
            (identical(other.amountOriginal, amountOriginal) ||
                other.amountOriginal == amountOriginal) &&
            (identical(other.currencyOriginal, currencyOriginal) ||
                other.currencyOriginal == currencyOriginal) &&
            (identical(other.fxRateToBase, fxRateToBase) ||
                other.fxRateToBase == fxRateToBase) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      householdId,
      title,
      amount,
      currency,
      dueDate,
      status,
      category,
      recurrenceType,
      reminderDays,
      amountOriginal,
      currencyOriginal,
      fxRateToBase,
      createdAt);

  @override
  String toString() {
    return 'Bill(id: $id, userId: $userId, householdId: $householdId, title: $title, amount: $amount, currency: $currency, dueDate: $dueDate, status: $status, category: $category, recurrenceType: $recurrenceType, reminderDays: $reminderDays, amountOriginal: $amountOriginal, currencyOriginal: $currencyOriginal, fxRateToBase: $fxRateToBase, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $BillCopyWith<$Res> {
  factory $BillCopyWith(Bill value, $Res Function(Bill) _then) =
      _$BillCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'household_id') String householdId,
      String title,
      @DecimalConverter() Decimal amount,
      String currency,
      @JsonKey(name: 'due_date') DateTime dueDate,
      BillStatus status,
      String category,
      @JsonKey(name: 'recurrence_type') String? recurrenceType,
      @JsonKey(name: 'reminder_days') int? reminderDays,
      @JsonKey(name: 'amount_original')
      @DecimalNullConverter()
      Decimal? amountOriginal,
      @JsonKey(name: 'currency_original') String? currencyOriginal,
      @JsonKey(name: 'fx_rate_to_base')
      @DecimalNullConverter()
      Decimal? fxRateToBase,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class _$BillCopyWithImpl<$Res> implements $BillCopyWith<$Res> {
  _$BillCopyWithImpl(this._self, this._then);

  final Bill _self;
  final $Res Function(Bill) _then;

  /// Create a copy of Bill
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? householdId = null,
    Object? title = null,
    Object? amount = null,
    Object? currency = null,
    Object? dueDate = null,
    Object? status = null,
    Object? category = null,
    Object? recurrenceType = freezed,
    Object? reminderDays = freezed,
    Object? amountOriginal = freezed,
    Object? currencyOriginal = freezed,
    Object? fxRateToBase = freezed,
    Object? createdAt = freezed,
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
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      dueDate: null == dueDate
          ? _self.dueDate
          : dueDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as BillStatus,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      recurrenceType: freezed == recurrenceType
          ? _self.recurrenceType
          : recurrenceType // ignore: cast_nullable_to_non_nullable
              as String?,
      reminderDays: freezed == reminderDays
          ? _self.reminderDays
          : reminderDays // ignore: cast_nullable_to_non_nullable
              as int?,
      amountOriginal: freezed == amountOriginal
          ? _self.amountOriginal
          : amountOriginal // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      currencyOriginal: freezed == currencyOriginal
          ? _self.currencyOriginal
          : currencyOriginal // ignore: cast_nullable_to_non_nullable
              as String?,
      fxRateToBase: freezed == fxRateToBase
          ? _self.fxRateToBase
          : fxRateToBase // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Bill extends Bill {
  const _Bill(
      {required this.id,
      @JsonKey(name: 'user_id') required this.userId,
      @JsonKey(name: 'household_id') required this.householdId,
      required this.title,
      @DecimalConverter() required this.amount,
      this.currency = 'USD',
      @JsonKey(name: 'due_date') required this.dueDate,
      this.status = BillStatus.pending,
      this.category = '',
      @JsonKey(name: 'recurrence_type') this.recurrenceType,
      @JsonKey(name: 'reminder_days') this.reminderDays,
      @JsonKey(name: 'amount_original')
      @DecimalNullConverter()
      this.amountOriginal,
      @JsonKey(name: 'currency_original') this.currencyOriginal,
      @JsonKey(name: 'fx_rate_to_base')
      @DecimalNullConverter()
      this.fxRateToBase,
      @JsonKey(name: 'created_at') this.createdAt})
      : super._();
  factory _Bill.fromJson(Map<String, dynamic> json) => _$BillFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  final String title;
  @override
  @DecimalConverter()
  final Decimal amount;
  @override
  @JsonKey()
  final String currency;
  @override
  @JsonKey(name: 'due_date')
  final DateTime dueDate;
  @override
  @JsonKey()
  final BillStatus status;
  @override
  @JsonKey()
  final String category;
  @override
  @JsonKey(name: 'recurrence_type')
  final String? recurrenceType;
  @override
  @JsonKey(name: 'reminder_days')
  final int? reminderDays;
  @override
  @JsonKey(name: 'amount_original')
  @DecimalNullConverter()
  final Decimal? amountOriginal;
  @override
  @JsonKey(name: 'currency_original')
  final String? currencyOriginal;
  @override
  @JsonKey(name: 'fx_rate_to_base')
  @DecimalNullConverter()
  final Decimal? fxRateToBase;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  /// Create a copy of Bill
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BillCopyWith<_Bill> get copyWith =>
      __$BillCopyWithImpl<_Bill>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BillToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Bill &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.recurrenceType, recurrenceType) ||
                other.recurrenceType == recurrenceType) &&
            (identical(other.reminderDays, reminderDays) ||
                other.reminderDays == reminderDays) &&
            (identical(other.amountOriginal, amountOriginal) ||
                other.amountOriginal == amountOriginal) &&
            (identical(other.currencyOriginal, currencyOriginal) ||
                other.currencyOriginal == currencyOriginal) &&
            (identical(other.fxRateToBase, fxRateToBase) ||
                other.fxRateToBase == fxRateToBase) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      householdId,
      title,
      amount,
      currency,
      dueDate,
      status,
      category,
      recurrenceType,
      reminderDays,
      amountOriginal,
      currencyOriginal,
      fxRateToBase,
      createdAt);

  @override
  String toString() {
    return 'Bill(id: $id, userId: $userId, householdId: $householdId, title: $title, amount: $amount, currency: $currency, dueDate: $dueDate, status: $status, category: $category, recurrenceType: $recurrenceType, reminderDays: $reminderDays, amountOriginal: $amountOriginal, currencyOriginal: $currencyOriginal, fxRateToBase: $fxRateToBase, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$BillCopyWith<$Res> implements $BillCopyWith<$Res> {
  factory _$BillCopyWith(_Bill value, $Res Function(_Bill) _then) =
      __$BillCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'household_id') String householdId,
      String title,
      @DecimalConverter() Decimal amount,
      String currency,
      @JsonKey(name: 'due_date') DateTime dueDate,
      BillStatus status,
      String category,
      @JsonKey(name: 'recurrence_type') String? recurrenceType,
      @JsonKey(name: 'reminder_days') int? reminderDays,
      @JsonKey(name: 'amount_original')
      @DecimalNullConverter()
      Decimal? amountOriginal,
      @JsonKey(name: 'currency_original') String? currencyOriginal,
      @JsonKey(name: 'fx_rate_to_base')
      @DecimalNullConverter()
      Decimal? fxRateToBase,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class __$BillCopyWithImpl<$Res> implements _$BillCopyWith<$Res> {
  __$BillCopyWithImpl(this._self, this._then);

  final _Bill _self;
  final $Res Function(_Bill) _then;

  /// Create a copy of Bill
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? householdId = null,
    Object? title = null,
    Object? amount = null,
    Object? currency = null,
    Object? dueDate = null,
    Object? status = null,
    Object? category = null,
    Object? recurrenceType = freezed,
    Object? reminderDays = freezed,
    Object? amountOriginal = freezed,
    Object? currencyOriginal = freezed,
    Object? fxRateToBase = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_Bill(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      dueDate: null == dueDate
          ? _self.dueDate
          : dueDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as BillStatus,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      recurrenceType: freezed == recurrenceType
          ? _self.recurrenceType
          : recurrenceType // ignore: cast_nullable_to_non_nullable
              as String?,
      reminderDays: freezed == reminderDays
          ? _self.reminderDays
          : reminderDays // ignore: cast_nullable_to_non_nullable
              as int?,
      amountOriginal: freezed == amountOriginal
          ? _self.amountOriginal
          : amountOriginal // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      currencyOriginal: freezed == currencyOriginal
          ? _self.currencyOriginal
          : currencyOriginal // ignore: cast_nullable_to_non_nullable
              as String?,
      fxRateToBase: freezed == fxRateToBase
          ? _self.fxRateToBase
          : fxRateToBase // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
