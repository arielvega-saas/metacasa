// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recurring_transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RecurringTransaction {
  String get id;
  @JsonKey(name: 'household_id')
  String get householdId;
  @JsonKey(name: 'user_id')
  String get userId;
  TxType get type;
  @DecimalConverter()
  Decimal get amount;
  String get category;
  String? get subcategory;
  String? get account;
  @JsonKey(name: 'start_date')
  DateTime get startDate;
  @JsonKey(name: 'end_date')
  DateTime? get endDate;
  @JsonKey(name: 'next_date')
  DateTime? get nextDate;
  String? get note;
  Frequency get frequency;
  bool get active;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of RecurringTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RecurringTransactionCopyWith<RecurringTransaction> get copyWith =>
      _$RecurringTransactionCopyWithImpl<RecurringTransaction>(
          this as RecurringTransaction, _$identity);

  /// Serializes this RecurringTransaction to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RecurringTransaction &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.account, account) || other.account == account) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.nextDate, nextDate) ||
                other.nextDate == nextDate) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.frequency, frequency) ||
                other.frequency == frequency) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      householdId,
      userId,
      type,
      amount,
      category,
      subcategory,
      account,
      startDate,
      endDate,
      nextDate,
      note,
      frequency,
      active,
      createdAt);

  @override
  String toString() {
    return 'RecurringTransaction(id: $id, householdId: $householdId, userId: $userId, type: $type, amount: $amount, category: $category, subcategory: $subcategory, account: $account, startDate: $startDate, endDate: $endDate, nextDate: $nextDate, note: $note, frequency: $frequency, active: $active, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $RecurringTransactionCopyWith<$Res> {
  factory $RecurringTransactionCopyWith(RecurringTransaction value,
          $Res Function(RecurringTransaction) _then) =
      _$RecurringTransactionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      @JsonKey(name: 'user_id') String userId,
      TxType type,
      @DecimalConverter() Decimal amount,
      String category,
      String? subcategory,
      String? account,
      @JsonKey(name: 'start_date') DateTime startDate,
      @JsonKey(name: 'end_date') DateTime? endDate,
      @JsonKey(name: 'next_date') DateTime? nextDate,
      String? note,
      Frequency frequency,
      bool active,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class _$RecurringTransactionCopyWithImpl<$Res>
    implements $RecurringTransactionCopyWith<$Res> {
  _$RecurringTransactionCopyWithImpl(this._self, this._then);

  final RecurringTransaction _self;
  final $Res Function(RecurringTransaction) _then;

  /// Create a copy of RecurringTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? userId = null,
    Object? type = null,
    Object? amount = null,
    Object? category = null,
    Object? subcategory = freezed,
    Object? account = freezed,
    Object? startDate = null,
    Object? endDate = freezed,
    Object? nextDate = freezed,
    Object? note = freezed,
    Object? frequency = null,
    Object? active = null,
    Object? createdAt = freezed,
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
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as TxType,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      subcategory: freezed == subcategory
          ? _self.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as String?,
      account: freezed == account
          ? _self.account
          : account // ignore: cast_nullable_to_non_nullable
              as String?,
      startDate: null == startDate
          ? _self.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: freezed == endDate
          ? _self.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      nextDate: freezed == nextDate
          ? _self.nextDate
          : nextDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      frequency: null == frequency
          ? _self.frequency
          : frequency // ignore: cast_nullable_to_non_nullable
              as Frequency,
      active: null == active
          ? _self.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _RecurringTransaction implements RecurringTransaction {
  const _RecurringTransaction(
      {required this.id,
      @JsonKey(name: 'household_id') required this.householdId,
      @JsonKey(name: 'user_id') required this.userId,
      required this.type,
      @DecimalConverter() required this.amount,
      required this.category,
      this.subcategory,
      this.account,
      @JsonKey(name: 'start_date') required this.startDate,
      @JsonKey(name: 'end_date') this.endDate,
      @JsonKey(name: 'next_date') this.nextDate,
      this.note,
      required this.frequency,
      required this.active,
      @JsonKey(name: 'created_at') this.createdAt});
  factory _RecurringTransaction.fromJson(Map<String, dynamic> json) =>
      _$RecurringTransactionFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final TxType type;
  @override
  @DecimalConverter()
  final Decimal amount;
  @override
  final String category;
  @override
  final String? subcategory;
  @override
  final String? account;
  @override
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  @override
  @JsonKey(name: 'end_date')
  final DateTime? endDate;
  @override
  @JsonKey(name: 'next_date')
  final DateTime? nextDate;
  @override
  final String? note;
  @override
  final Frequency frequency;
  @override
  final bool active;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  /// Create a copy of RecurringTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RecurringTransactionCopyWith<_RecurringTransaction> get copyWith =>
      __$RecurringTransactionCopyWithImpl<_RecurringTransaction>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RecurringTransactionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RecurringTransaction &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.account, account) || other.account == account) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.nextDate, nextDate) ||
                other.nextDate == nextDate) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.frequency, frequency) ||
                other.frequency == frequency) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      householdId,
      userId,
      type,
      amount,
      category,
      subcategory,
      account,
      startDate,
      endDate,
      nextDate,
      note,
      frequency,
      active,
      createdAt);

  @override
  String toString() {
    return 'RecurringTransaction(id: $id, householdId: $householdId, userId: $userId, type: $type, amount: $amount, category: $category, subcategory: $subcategory, account: $account, startDate: $startDate, endDate: $endDate, nextDate: $nextDate, note: $note, frequency: $frequency, active: $active, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$RecurringTransactionCopyWith<$Res>
    implements $RecurringTransactionCopyWith<$Res> {
  factory _$RecurringTransactionCopyWith(_RecurringTransaction value,
          $Res Function(_RecurringTransaction) _then) =
      __$RecurringTransactionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      @JsonKey(name: 'user_id') String userId,
      TxType type,
      @DecimalConverter() Decimal amount,
      String category,
      String? subcategory,
      String? account,
      @JsonKey(name: 'start_date') DateTime startDate,
      @JsonKey(name: 'end_date') DateTime? endDate,
      @JsonKey(name: 'next_date') DateTime? nextDate,
      String? note,
      Frequency frequency,
      bool active,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class __$RecurringTransactionCopyWithImpl<$Res>
    implements _$RecurringTransactionCopyWith<$Res> {
  __$RecurringTransactionCopyWithImpl(this._self, this._then);

  final _RecurringTransaction _self;
  final $Res Function(_RecurringTransaction) _then;

  /// Create a copy of RecurringTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? userId = null,
    Object? type = null,
    Object? amount = null,
    Object? category = null,
    Object? subcategory = freezed,
    Object? account = freezed,
    Object? startDate = null,
    Object? endDate = freezed,
    Object? nextDate = freezed,
    Object? note = freezed,
    Object? frequency = null,
    Object? active = null,
    Object? createdAt = freezed,
  }) {
    return _then(_RecurringTransaction(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as TxType,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      subcategory: freezed == subcategory
          ? _self.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as String?,
      account: freezed == account
          ? _self.account
          : account // ignore: cast_nullable_to_non_nullable
              as String?,
      startDate: null == startDate
          ? _self.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: freezed == endDate
          ? _self.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      nextDate: freezed == nextDate
          ? _self.nextDate
          : nextDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      frequency: null == frequency
          ? _self.frequency
          : frequency // ignore: cast_nullable_to_non_nullable
              as Frequency,
      active: null == active
          ? _self.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
