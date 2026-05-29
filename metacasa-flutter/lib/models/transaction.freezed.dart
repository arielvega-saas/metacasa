// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Transaction {
  String get id;
  @JsonKey(name: 'household_id')
  String get householdId;
  @JsonKey(name: 'user_id')
  String get userId;
  @JsonKey(name: 'account_id')
  String? get accountId;
  TxType get type;
  @DecimalConverter()
  Decimal get amount;
  @JsonKey(name: 'amount_original')
  @DecimalNullConverter()
  Decimal? get amountOriginal;
  @JsonKey(name: 'currency_original')
  String? get currencyOriginal;
  @JsonKey(name: 'fx_rate_to_base')
  @DecimalNullConverter()
  Decimal? get fxRateToBase;
  @JsonKey(name: 'fx_source')
  String? get fxSource;
  @JsonKey(name: 'fx_status')
  String? get fxStatus;
  String get category;
  String? get subcategory;
  String? get account;
  String? get note;
  DateTime get date;
  @JsonKey(name: 'period_year')
  int? get periodYear;
  @JsonKey(name: 'period_month')
  int? get periodMonth;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TransactionCopyWith<Transaction> get copyWith =>
      _$TransactionCopyWithImpl<Transaction>(this as Transaction, _$identity);

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Transaction &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.amountOriginal, amountOriginal) ||
                other.amountOriginal == amountOriginal) &&
            (identical(other.currencyOriginal, currencyOriginal) ||
                other.currencyOriginal == currencyOriginal) &&
            (identical(other.fxRateToBase, fxRateToBase) ||
                other.fxRateToBase == fxRateToBase) &&
            (identical(other.fxSource, fxSource) ||
                other.fxSource == fxSource) &&
            (identical(other.fxStatus, fxStatus) ||
                other.fxStatus == fxStatus) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.account, account) || other.account == account) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.periodYear, periodYear) ||
                other.periodYear == periodYear) &&
            (identical(other.periodMonth, periodMonth) ||
                other.periodMonth == periodMonth) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        householdId,
        userId,
        accountId,
        type,
        amount,
        amountOriginal,
        currencyOriginal,
        fxRateToBase,
        fxSource,
        fxStatus,
        category,
        subcategory,
        account,
        note,
        date,
        periodYear,
        periodMonth,
        createdAt
      ]);

  @override
  String toString() {
    return 'Transaction(id: $id, householdId: $householdId, userId: $userId, accountId: $accountId, type: $type, amount: $amount, amountOriginal: $amountOriginal, currencyOriginal: $currencyOriginal, fxRateToBase: $fxRateToBase, fxSource: $fxSource, fxStatus: $fxStatus, category: $category, subcategory: $subcategory, account: $account, note: $note, date: $date, periodYear: $periodYear, periodMonth: $periodMonth, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $TransactionCopyWith<$Res> {
  factory $TransactionCopyWith(
          Transaction value, $Res Function(Transaction) _then) =
      _$TransactionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'account_id') String? accountId,
      TxType type,
      @DecimalConverter() Decimal amount,
      @JsonKey(name: 'amount_original')
      @DecimalNullConverter()
      Decimal? amountOriginal,
      @JsonKey(name: 'currency_original') String? currencyOriginal,
      @JsonKey(name: 'fx_rate_to_base')
      @DecimalNullConverter()
      Decimal? fxRateToBase,
      @JsonKey(name: 'fx_source') String? fxSource,
      @JsonKey(name: 'fx_status') String? fxStatus,
      String category,
      String? subcategory,
      String? account,
      String? note,
      DateTime date,
      @JsonKey(name: 'period_year') int? periodYear,
      @JsonKey(name: 'period_month') int? periodMonth,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res> implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._self, this._then);

  final Transaction _self;
  final $Res Function(Transaction) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? userId = null,
    Object? accountId = freezed,
    Object? type = null,
    Object? amount = null,
    Object? amountOriginal = freezed,
    Object? currencyOriginal = freezed,
    Object? fxRateToBase = freezed,
    Object? fxSource = freezed,
    Object? fxStatus = freezed,
    Object? category = null,
    Object? subcategory = freezed,
    Object? account = freezed,
    Object? note = freezed,
    Object? date = null,
    Object? periodYear = freezed,
    Object? periodMonth = freezed,
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
      accountId: freezed == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as TxType,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
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
      fxSource: freezed == fxSource
          ? _self.fxSource
          : fxSource // ignore: cast_nullable_to_non_nullable
              as String?,
      fxStatus: freezed == fxStatus
          ? _self.fxStatus
          : fxStatus // ignore: cast_nullable_to_non_nullable
              as String?,
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
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      periodYear: freezed == periodYear
          ? _self.periodYear
          : periodYear // ignore: cast_nullable_to_non_nullable
              as int?,
      periodMonth: freezed == periodMonth
          ? _self.periodMonth
          : periodMonth // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Transaction implements Transaction {
  const _Transaction(
      {required this.id,
      @JsonKey(name: 'household_id') required this.householdId,
      @JsonKey(name: 'user_id') required this.userId,
      @JsonKey(name: 'account_id') this.accountId,
      required this.type,
      @DecimalConverter() required this.amount,
      @JsonKey(name: 'amount_original')
      @DecimalNullConverter()
      this.amountOriginal,
      @JsonKey(name: 'currency_original') this.currencyOriginal,
      @JsonKey(name: 'fx_rate_to_base')
      @DecimalNullConverter()
      this.fxRateToBase,
      @JsonKey(name: 'fx_source') this.fxSource,
      @JsonKey(name: 'fx_status') this.fxStatus,
      required this.category,
      this.subcategory,
      this.account,
      this.note,
      required this.date,
      @JsonKey(name: 'period_year') this.periodYear,
      @JsonKey(name: 'period_month') this.periodMonth,
      @JsonKey(name: 'created_at') this.createdAt});
  factory _Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'account_id')
  final String? accountId;
  @override
  final TxType type;
  @override
  @DecimalConverter()
  final Decimal amount;
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
  @JsonKey(name: 'fx_source')
  final String? fxSource;
  @override
  @JsonKey(name: 'fx_status')
  final String? fxStatus;
  @override
  final String category;
  @override
  final String? subcategory;
  @override
  final String? account;
  @override
  final String? note;
  @override
  final DateTime date;
  @override
  @JsonKey(name: 'period_year')
  final int? periodYear;
  @override
  @JsonKey(name: 'period_month')
  final int? periodMonth;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TransactionCopyWith<_Transaction> get copyWith =>
      __$TransactionCopyWithImpl<_Transaction>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TransactionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Transaction &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.amountOriginal, amountOriginal) ||
                other.amountOriginal == amountOriginal) &&
            (identical(other.currencyOriginal, currencyOriginal) ||
                other.currencyOriginal == currencyOriginal) &&
            (identical(other.fxRateToBase, fxRateToBase) ||
                other.fxRateToBase == fxRateToBase) &&
            (identical(other.fxSource, fxSource) ||
                other.fxSource == fxSource) &&
            (identical(other.fxStatus, fxStatus) ||
                other.fxStatus == fxStatus) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.account, account) || other.account == account) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.periodYear, periodYear) ||
                other.periodYear == periodYear) &&
            (identical(other.periodMonth, periodMonth) ||
                other.periodMonth == periodMonth) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        householdId,
        userId,
        accountId,
        type,
        amount,
        amountOriginal,
        currencyOriginal,
        fxRateToBase,
        fxSource,
        fxStatus,
        category,
        subcategory,
        account,
        note,
        date,
        periodYear,
        periodMonth,
        createdAt
      ]);

  @override
  String toString() {
    return 'Transaction(id: $id, householdId: $householdId, userId: $userId, accountId: $accountId, type: $type, amount: $amount, amountOriginal: $amountOriginal, currencyOriginal: $currencyOriginal, fxRateToBase: $fxRateToBase, fxSource: $fxSource, fxStatus: $fxStatus, category: $category, subcategory: $subcategory, account: $account, note: $note, date: $date, periodYear: $periodYear, periodMonth: $periodMonth, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$TransactionCopyWith<$Res>
    implements $TransactionCopyWith<$Res> {
  factory _$TransactionCopyWith(
          _Transaction value, $Res Function(_Transaction) _then) =
      __$TransactionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'account_id') String? accountId,
      TxType type,
      @DecimalConverter() Decimal amount,
      @JsonKey(name: 'amount_original')
      @DecimalNullConverter()
      Decimal? amountOriginal,
      @JsonKey(name: 'currency_original') String? currencyOriginal,
      @JsonKey(name: 'fx_rate_to_base')
      @DecimalNullConverter()
      Decimal? fxRateToBase,
      @JsonKey(name: 'fx_source') String? fxSource,
      @JsonKey(name: 'fx_status') String? fxStatus,
      String category,
      String? subcategory,
      String? account,
      String? note,
      DateTime date,
      @JsonKey(name: 'period_year') int? periodYear,
      @JsonKey(name: 'period_month') int? periodMonth,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class __$TransactionCopyWithImpl<$Res> implements _$TransactionCopyWith<$Res> {
  __$TransactionCopyWithImpl(this._self, this._then);

  final _Transaction _self;
  final $Res Function(_Transaction) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? userId = null,
    Object? accountId = freezed,
    Object? type = null,
    Object? amount = null,
    Object? amountOriginal = freezed,
    Object? currencyOriginal = freezed,
    Object? fxRateToBase = freezed,
    Object? fxSource = freezed,
    Object? fxStatus = freezed,
    Object? category = null,
    Object? subcategory = freezed,
    Object? account = freezed,
    Object? note = freezed,
    Object? date = null,
    Object? periodYear = freezed,
    Object? periodMonth = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_Transaction(
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
      accountId: freezed == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as TxType,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
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
      fxSource: freezed == fxSource
          ? _self.fxSource
          : fxSource // ignore: cast_nullable_to_non_nullable
              as String?,
      fxStatus: freezed == fxStatus
          ? _self.fxStatus
          : fxStatus // ignore: cast_nullable_to_non_nullable
              as String?,
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
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      periodYear: freezed == periodYear
          ? _self.periodYear
          : periodYear // ignore: cast_nullable_to_non_nullable
              as int?,
      periodMonth: freezed == periodMonth
          ? _self.periodMonth
          : periodMonth // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
mixin _$NewTransactionInput {
  @JsonKey(name: 'household_id')
  String get householdId;
  @JsonKey(name: 'user_id')
  String get userId;
  @JsonKey(name: 'account_id')
  String? get accountId;
  TxType get type;
  @DecimalConverter()
  Decimal get amount;
  @JsonKey(name: 'currency_original')
  String? get currencyOriginal;
  String get category;
  String? get subcategory;
  String? get note;
  DateTime get date;

  /// Create a copy of NewTransactionInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NewTransactionInputCopyWith<NewTransactionInput> get copyWith =>
      _$NewTransactionInputCopyWithImpl<NewTransactionInput>(
          this as NewTransactionInput, _$identity);

  /// Serializes this NewTransactionInput to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NewTransactionInput &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currencyOriginal, currencyOriginal) ||
                other.currencyOriginal == currencyOriginal) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.date, date) || other.date == date));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, householdId, userId, accountId,
      type, amount, currencyOriginal, category, subcategory, note, date);

  @override
  String toString() {
    return 'NewTransactionInput(householdId: $householdId, userId: $userId, accountId: $accountId, type: $type, amount: $amount, currencyOriginal: $currencyOriginal, category: $category, subcategory: $subcategory, note: $note, date: $date)';
  }
}

/// @nodoc
abstract mixin class $NewTransactionInputCopyWith<$Res> {
  factory $NewTransactionInputCopyWith(
          NewTransactionInput value, $Res Function(NewTransactionInput) _then) =
      _$NewTransactionInputCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'household_id') String householdId,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'account_id') String? accountId,
      TxType type,
      @DecimalConverter() Decimal amount,
      @JsonKey(name: 'currency_original') String? currencyOriginal,
      String category,
      String? subcategory,
      String? note,
      DateTime date});
}

/// @nodoc
class _$NewTransactionInputCopyWithImpl<$Res>
    implements $NewTransactionInputCopyWith<$Res> {
  _$NewTransactionInputCopyWithImpl(this._self, this._then);

  final NewTransactionInput _self;
  final $Res Function(NewTransactionInput) _then;

  /// Create a copy of NewTransactionInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? householdId = null,
    Object? userId = null,
    Object? accountId = freezed,
    Object? type = null,
    Object? amount = null,
    Object? currencyOriginal = freezed,
    Object? category = null,
    Object? subcategory = freezed,
    Object? note = freezed,
    Object? date = null,
  }) {
    return _then(_self.copyWith(
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      accountId: freezed == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as TxType,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currencyOriginal: freezed == currencyOriginal
          ? _self.currencyOriginal
          : currencyOriginal // ignore: cast_nullable_to_non_nullable
              as String?,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      subcategory: freezed == subcategory
          ? _self.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as String?,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _NewTransactionInput implements NewTransactionInput {
  const _NewTransactionInput(
      {@JsonKey(name: 'household_id') required this.householdId,
      @JsonKey(name: 'user_id') required this.userId,
      @JsonKey(name: 'account_id') this.accountId,
      required this.type,
      @DecimalConverter() required this.amount,
      @JsonKey(name: 'currency_original') this.currencyOriginal,
      required this.category,
      this.subcategory,
      this.note,
      required this.date});
  factory _NewTransactionInput.fromJson(Map<String, dynamic> json) =>
      _$NewTransactionInputFromJson(json);

  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'account_id')
  final String? accountId;
  @override
  final TxType type;
  @override
  @DecimalConverter()
  final Decimal amount;
  @override
  @JsonKey(name: 'currency_original')
  final String? currencyOriginal;
  @override
  final String category;
  @override
  final String? subcategory;
  @override
  final String? note;
  @override
  final DateTime date;

  /// Create a copy of NewTransactionInput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NewTransactionInputCopyWith<_NewTransactionInput> get copyWith =>
      __$NewTransactionInputCopyWithImpl<_NewTransactionInput>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$NewTransactionInputToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NewTransactionInput &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currencyOriginal, currencyOriginal) ||
                other.currencyOriginal == currencyOriginal) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.date, date) || other.date == date));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, householdId, userId, accountId,
      type, amount, currencyOriginal, category, subcategory, note, date);

  @override
  String toString() {
    return 'NewTransactionInput(householdId: $householdId, userId: $userId, accountId: $accountId, type: $type, amount: $amount, currencyOriginal: $currencyOriginal, category: $category, subcategory: $subcategory, note: $note, date: $date)';
  }
}

/// @nodoc
abstract mixin class _$NewTransactionInputCopyWith<$Res>
    implements $NewTransactionInputCopyWith<$Res> {
  factory _$NewTransactionInputCopyWith(_NewTransactionInput value,
          $Res Function(_NewTransactionInput) _then) =
      __$NewTransactionInputCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'household_id') String householdId,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'account_id') String? accountId,
      TxType type,
      @DecimalConverter() Decimal amount,
      @JsonKey(name: 'currency_original') String? currencyOriginal,
      String category,
      String? subcategory,
      String? note,
      DateTime date});
}

/// @nodoc
class __$NewTransactionInputCopyWithImpl<$Res>
    implements _$NewTransactionInputCopyWith<$Res> {
  __$NewTransactionInputCopyWithImpl(this._self, this._then);

  final _NewTransactionInput _self;
  final $Res Function(_NewTransactionInput) _then;

  /// Create a copy of NewTransactionInput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? householdId = null,
    Object? userId = null,
    Object? accountId = freezed,
    Object? type = null,
    Object? amount = null,
    Object? currencyOriginal = freezed,
    Object? category = null,
    Object? subcategory = freezed,
    Object? note = freezed,
    Object? date = null,
  }) {
    return _then(_NewTransactionInput(
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      accountId: freezed == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as TxType,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currencyOriginal: freezed == currencyOriginal
          ? _self.currencyOriginal
          : currencyOriginal // ignore: cast_nullable_to_non_nullable
              as String?,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      subcategory: freezed == subcategory
          ? _self.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as String?,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
