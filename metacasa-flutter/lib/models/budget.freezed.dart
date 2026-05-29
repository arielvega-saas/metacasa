// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'budget.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BudgetPeriod {
  String get id;
  @JsonKey(name: 'household_id')
  String get householdId;
  @JsonKey(name: 'period_type')
  PeriodType get periodType;
  @JsonKey(name: 'period_start')
  DateTime get periodStart;
  @JsonKey(name: 'period_end')
  DateTime get periodEnd;
  @JsonKey(name: 'total_income')
  @DecimalConverter()
  Decimal get totalIncome;
  @JsonKey(name: 'total_allocated')
  @DecimalConverter()
  Decimal get totalAllocated;
  @JsonKey(name: 'ready_to_assign')
  @DecimalConverter()
  Decimal get readyToAssign;
  String? get notes;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of BudgetPeriod
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BudgetPeriodCopyWith<BudgetPeriod> get copyWith =>
      _$BudgetPeriodCopyWithImpl<BudgetPeriod>(
          this as BudgetPeriod, _$identity);

  /// Serializes this BudgetPeriod to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BudgetPeriod &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.periodType, periodType) ||
                other.periodType == periodType) &&
            (identical(other.periodStart, periodStart) ||
                other.periodStart == periodStart) &&
            (identical(other.periodEnd, periodEnd) ||
                other.periodEnd == periodEnd) &&
            (identical(other.totalIncome, totalIncome) ||
                other.totalIncome == totalIncome) &&
            (identical(other.totalAllocated, totalAllocated) ||
                other.totalAllocated == totalAllocated) &&
            (identical(other.readyToAssign, readyToAssign) ||
                other.readyToAssign == readyToAssign) &&
            (identical(other.notes, notes) || other.notes == notes) &&
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
      periodType,
      periodStart,
      periodEnd,
      totalIncome,
      totalAllocated,
      readyToAssign,
      notes,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'BudgetPeriod(id: $id, householdId: $householdId, periodType: $periodType, periodStart: $periodStart, periodEnd: $periodEnd, totalIncome: $totalIncome, totalAllocated: $totalAllocated, readyToAssign: $readyToAssign, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $BudgetPeriodCopyWith<$Res> {
  factory $BudgetPeriodCopyWith(
          BudgetPeriod value, $Res Function(BudgetPeriod) _then) =
      _$BudgetPeriodCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      @JsonKey(name: 'period_type') PeriodType periodType,
      @JsonKey(name: 'period_start') DateTime periodStart,
      @JsonKey(name: 'period_end') DateTime periodEnd,
      @JsonKey(name: 'total_income') @DecimalConverter() Decimal totalIncome,
      @JsonKey(name: 'total_allocated')
      @DecimalConverter()
      Decimal totalAllocated,
      @JsonKey(name: 'ready_to_assign')
      @DecimalConverter()
      Decimal readyToAssign,
      String? notes,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$BudgetPeriodCopyWithImpl<$Res> implements $BudgetPeriodCopyWith<$Res> {
  _$BudgetPeriodCopyWithImpl(this._self, this._then);

  final BudgetPeriod _self;
  final $Res Function(BudgetPeriod) _then;

  /// Create a copy of BudgetPeriod
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? periodType = null,
    Object? periodStart = null,
    Object? periodEnd = null,
    Object? totalIncome = null,
    Object? totalAllocated = null,
    Object? readyToAssign = null,
    Object? notes = freezed,
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
      periodType: null == periodType
          ? _self.periodType
          : periodType // ignore: cast_nullable_to_non_nullable
              as PeriodType,
      periodStart: null == periodStart
          ? _self.periodStart
          : periodStart // ignore: cast_nullable_to_non_nullable
              as DateTime,
      periodEnd: null == periodEnd
          ? _self.periodEnd
          : periodEnd // ignore: cast_nullable_to_non_nullable
              as DateTime,
      totalIncome: null == totalIncome
          ? _self.totalIncome
          : totalIncome // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalAllocated: null == totalAllocated
          ? _self.totalAllocated
          : totalAllocated // ignore: cast_nullable_to_non_nullable
              as Decimal,
      readyToAssign: null == readyToAssign
          ? _self.readyToAssign
          : readyToAssign // ignore: cast_nullable_to_non_nullable
              as Decimal,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
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
class _BudgetPeriod implements BudgetPeriod {
  const _BudgetPeriod(
      {required this.id,
      @JsonKey(name: 'household_id') required this.householdId,
      @JsonKey(name: 'period_type') required this.periodType,
      @JsonKey(name: 'period_start') required this.periodStart,
      @JsonKey(name: 'period_end') required this.periodEnd,
      @JsonKey(name: 'total_income')
      @DecimalConverter()
      required this.totalIncome,
      @JsonKey(name: 'total_allocated')
      @DecimalConverter()
      required this.totalAllocated,
      @JsonKey(name: 'ready_to_assign')
      @DecimalConverter()
      required this.readyToAssign,
      this.notes,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt});
  factory _BudgetPeriod.fromJson(Map<String, dynamic> json) =>
      _$BudgetPeriodFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  @JsonKey(name: 'period_type')
  final PeriodType periodType;
  @override
  @JsonKey(name: 'period_start')
  final DateTime periodStart;
  @override
  @JsonKey(name: 'period_end')
  final DateTime periodEnd;
  @override
  @JsonKey(name: 'total_income')
  @DecimalConverter()
  final Decimal totalIncome;
  @override
  @JsonKey(name: 'total_allocated')
  @DecimalConverter()
  final Decimal totalAllocated;
  @override
  @JsonKey(name: 'ready_to_assign')
  @DecimalConverter()
  final Decimal readyToAssign;
  @override
  final String? notes;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// Create a copy of BudgetPeriod
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BudgetPeriodCopyWith<_BudgetPeriod> get copyWith =>
      __$BudgetPeriodCopyWithImpl<_BudgetPeriod>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BudgetPeriodToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BudgetPeriod &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.periodType, periodType) ||
                other.periodType == periodType) &&
            (identical(other.periodStart, periodStart) ||
                other.periodStart == periodStart) &&
            (identical(other.periodEnd, periodEnd) ||
                other.periodEnd == periodEnd) &&
            (identical(other.totalIncome, totalIncome) ||
                other.totalIncome == totalIncome) &&
            (identical(other.totalAllocated, totalAllocated) ||
                other.totalAllocated == totalAllocated) &&
            (identical(other.readyToAssign, readyToAssign) ||
                other.readyToAssign == readyToAssign) &&
            (identical(other.notes, notes) || other.notes == notes) &&
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
      periodType,
      periodStart,
      periodEnd,
      totalIncome,
      totalAllocated,
      readyToAssign,
      notes,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'BudgetPeriod(id: $id, householdId: $householdId, periodType: $periodType, periodStart: $periodStart, periodEnd: $periodEnd, totalIncome: $totalIncome, totalAllocated: $totalAllocated, readyToAssign: $readyToAssign, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$BudgetPeriodCopyWith<$Res>
    implements $BudgetPeriodCopyWith<$Res> {
  factory _$BudgetPeriodCopyWith(
          _BudgetPeriod value, $Res Function(_BudgetPeriod) _then) =
      __$BudgetPeriodCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      @JsonKey(name: 'period_type') PeriodType periodType,
      @JsonKey(name: 'period_start') DateTime periodStart,
      @JsonKey(name: 'period_end') DateTime periodEnd,
      @JsonKey(name: 'total_income') @DecimalConverter() Decimal totalIncome,
      @JsonKey(name: 'total_allocated')
      @DecimalConverter()
      Decimal totalAllocated,
      @JsonKey(name: 'ready_to_assign')
      @DecimalConverter()
      Decimal readyToAssign,
      String? notes,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$BudgetPeriodCopyWithImpl<$Res>
    implements _$BudgetPeriodCopyWith<$Res> {
  __$BudgetPeriodCopyWithImpl(this._self, this._then);

  final _BudgetPeriod _self;
  final $Res Function(_BudgetPeriod) _then;

  /// Create a copy of BudgetPeriod
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? periodType = null,
    Object? periodStart = null,
    Object? periodEnd = null,
    Object? totalIncome = null,
    Object? totalAllocated = null,
    Object? readyToAssign = null,
    Object? notes = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_BudgetPeriod(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      periodType: null == periodType
          ? _self.periodType
          : periodType // ignore: cast_nullable_to_non_nullable
              as PeriodType,
      periodStart: null == periodStart
          ? _self.periodStart
          : periodStart // ignore: cast_nullable_to_non_nullable
              as DateTime,
      periodEnd: null == periodEnd
          ? _self.periodEnd
          : periodEnd // ignore: cast_nullable_to_non_nullable
              as DateTime,
      totalIncome: null == totalIncome
          ? _self.totalIncome
          : totalIncome // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalAllocated: null == totalAllocated
          ? _self.totalAllocated
          : totalAllocated // ignore: cast_nullable_to_non_nullable
              as Decimal,
      readyToAssign: null == readyToAssign
          ? _self.readyToAssign
          : readyToAssign // ignore: cast_nullable_to_non_nullable
              as Decimal,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
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
mixin _$BudgetAllocation {
  String get id;
  @JsonKey(name: 'period_id')
  String get periodId;
  String get category;
  String get subcategory;
  @DecimalConverter()
  Decimal get allocated;
  @JsonKey(name: 'rollover_from_prev')
  @DecimalConverter()
  Decimal get rolloverFromPrev;
  @JsonKey(name: 'rollover_mode')
  RolloverMode get rolloverMode;
  String get currency;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of BudgetAllocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BudgetAllocationCopyWith<BudgetAllocation> get copyWith =>
      _$BudgetAllocationCopyWithImpl<BudgetAllocation>(
          this as BudgetAllocation, _$identity);

  /// Serializes this BudgetAllocation to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BudgetAllocation &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.periodId, periodId) ||
                other.periodId == periodId) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.allocated, allocated) ||
                other.allocated == allocated) &&
            (identical(other.rolloverFromPrev, rolloverFromPrev) ||
                other.rolloverFromPrev == rolloverFromPrev) &&
            (identical(other.rolloverMode, rolloverMode) ||
                other.rolloverMode == rolloverMode) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
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
      periodId,
      category,
      subcategory,
      allocated,
      rolloverFromPrev,
      rolloverMode,
      currency,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'BudgetAllocation(id: $id, periodId: $periodId, category: $category, subcategory: $subcategory, allocated: $allocated, rolloverFromPrev: $rolloverFromPrev, rolloverMode: $rolloverMode, currency: $currency, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $BudgetAllocationCopyWith<$Res> {
  factory $BudgetAllocationCopyWith(
          BudgetAllocation value, $Res Function(BudgetAllocation) _then) =
      _$BudgetAllocationCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'period_id') String periodId,
      String category,
      String subcategory,
      @DecimalConverter() Decimal allocated,
      @JsonKey(name: 'rollover_from_prev')
      @DecimalConverter()
      Decimal rolloverFromPrev,
      @JsonKey(name: 'rollover_mode') RolloverMode rolloverMode,
      String currency,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$BudgetAllocationCopyWithImpl<$Res>
    implements $BudgetAllocationCopyWith<$Res> {
  _$BudgetAllocationCopyWithImpl(this._self, this._then);

  final BudgetAllocation _self;
  final $Res Function(BudgetAllocation) _then;

  /// Create a copy of BudgetAllocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? periodId = null,
    Object? category = null,
    Object? subcategory = null,
    Object? allocated = null,
    Object? rolloverFromPrev = null,
    Object? rolloverMode = null,
    Object? currency = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      periodId: null == periodId
          ? _self.periodId
          : periodId // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      subcategory: null == subcategory
          ? _self.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as String,
      allocated: null == allocated
          ? _self.allocated
          : allocated // ignore: cast_nullable_to_non_nullable
              as Decimal,
      rolloverFromPrev: null == rolloverFromPrev
          ? _self.rolloverFromPrev
          : rolloverFromPrev // ignore: cast_nullable_to_non_nullable
              as Decimal,
      rolloverMode: null == rolloverMode
          ? _self.rolloverMode
          : rolloverMode // ignore: cast_nullable_to_non_nullable
              as RolloverMode,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
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
class _BudgetAllocation implements BudgetAllocation {
  const _BudgetAllocation(
      {required this.id,
      @JsonKey(name: 'period_id') required this.periodId,
      required this.category,
      required this.subcategory,
      @DecimalConverter() required this.allocated,
      @JsonKey(name: 'rollover_from_prev')
      @DecimalConverter()
      required this.rolloverFromPrev,
      @JsonKey(name: 'rollover_mode') required this.rolloverMode,
      required this.currency,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt});
  factory _BudgetAllocation.fromJson(Map<String, dynamic> json) =>
      _$BudgetAllocationFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'period_id')
  final String periodId;
  @override
  final String category;
  @override
  final String subcategory;
  @override
  @DecimalConverter()
  final Decimal allocated;
  @override
  @JsonKey(name: 'rollover_from_prev')
  @DecimalConverter()
  final Decimal rolloverFromPrev;
  @override
  @JsonKey(name: 'rollover_mode')
  final RolloverMode rolloverMode;
  @override
  final String currency;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// Create a copy of BudgetAllocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BudgetAllocationCopyWith<_BudgetAllocation> get copyWith =>
      __$BudgetAllocationCopyWithImpl<_BudgetAllocation>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BudgetAllocationToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BudgetAllocation &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.periodId, periodId) ||
                other.periodId == periodId) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.allocated, allocated) ||
                other.allocated == allocated) &&
            (identical(other.rolloverFromPrev, rolloverFromPrev) ||
                other.rolloverFromPrev == rolloverFromPrev) &&
            (identical(other.rolloverMode, rolloverMode) ||
                other.rolloverMode == rolloverMode) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
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
      periodId,
      category,
      subcategory,
      allocated,
      rolloverFromPrev,
      rolloverMode,
      currency,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'BudgetAllocation(id: $id, periodId: $periodId, category: $category, subcategory: $subcategory, allocated: $allocated, rolloverFromPrev: $rolloverFromPrev, rolloverMode: $rolloverMode, currency: $currency, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$BudgetAllocationCopyWith<$Res>
    implements $BudgetAllocationCopyWith<$Res> {
  factory _$BudgetAllocationCopyWith(
          _BudgetAllocation value, $Res Function(_BudgetAllocation) _then) =
      __$BudgetAllocationCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'period_id') String periodId,
      String category,
      String subcategory,
      @DecimalConverter() Decimal allocated,
      @JsonKey(name: 'rollover_from_prev')
      @DecimalConverter()
      Decimal rolloverFromPrev,
      @JsonKey(name: 'rollover_mode') RolloverMode rolloverMode,
      String currency,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$BudgetAllocationCopyWithImpl<$Res>
    implements _$BudgetAllocationCopyWith<$Res> {
  __$BudgetAllocationCopyWithImpl(this._self, this._then);

  final _BudgetAllocation _self;
  final $Res Function(_BudgetAllocation) _then;

  /// Create a copy of BudgetAllocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? periodId = null,
    Object? category = null,
    Object? subcategory = null,
    Object? allocated = null,
    Object? rolloverFromPrev = null,
    Object? rolloverMode = null,
    Object? currency = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_BudgetAllocation(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      periodId: null == periodId
          ? _self.periodId
          : periodId // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      subcategory: null == subcategory
          ? _self.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as String,
      allocated: null == allocated
          ? _self.allocated
          : allocated // ignore: cast_nullable_to_non_nullable
              as Decimal,
      rolloverFromPrev: null == rolloverFromPrev
          ? _self.rolloverFromPrev
          : rolloverFromPrev // ignore: cast_nullable_to_non_nullable
              as Decimal,
      rolloverMode: null == rolloverMode
          ? _self.rolloverMode
          : rolloverMode // ignore: cast_nullable_to_non_nullable
              as RolloverMode,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
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
mixin _$EnvelopeStatus {
  String get category;
  String get subcategory;
  @DecimalConverter()
  Decimal get allocated;
  @DecimalConverter()
  Decimal get spent;

  /// Create a copy of EnvelopeStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EnvelopeStatusCopyWith<EnvelopeStatus> get copyWith =>
      _$EnvelopeStatusCopyWithImpl<EnvelopeStatus>(
          this as EnvelopeStatus, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EnvelopeStatus &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.allocated, allocated) ||
                other.allocated == allocated) &&
            (identical(other.spent, spent) || other.spent == spent));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, category, subcategory, allocated, spent);

  @override
  String toString() {
    return 'EnvelopeStatus(category: $category, subcategory: $subcategory, allocated: $allocated, spent: $spent)';
  }
}

/// @nodoc
abstract mixin class $EnvelopeStatusCopyWith<$Res> {
  factory $EnvelopeStatusCopyWith(
          EnvelopeStatus value, $Res Function(EnvelopeStatus) _then) =
      _$EnvelopeStatusCopyWithImpl;
  @useResult
  $Res call(
      {String category,
      String subcategory,
      @DecimalConverter() Decimal allocated,
      @DecimalConverter() Decimal spent});
}

/// @nodoc
class _$EnvelopeStatusCopyWithImpl<$Res>
    implements $EnvelopeStatusCopyWith<$Res> {
  _$EnvelopeStatusCopyWithImpl(this._self, this._then);

  final EnvelopeStatus _self;
  final $Res Function(EnvelopeStatus) _then;

  /// Create a copy of EnvelopeStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? category = null,
    Object? subcategory = null,
    Object? allocated = null,
    Object? spent = null,
  }) {
    return _then(_self.copyWith(
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      subcategory: null == subcategory
          ? _self.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as String,
      allocated: null == allocated
          ? _self.allocated
          : allocated // ignore: cast_nullable_to_non_nullable
              as Decimal,
      spent: null == spent
          ? _self.spent
          : spent // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// @nodoc

class _EnvelopeStatus extends EnvelopeStatus {
  const _EnvelopeStatus(
      {required this.category,
      required this.subcategory,
      @DecimalConverter() required this.allocated,
      @DecimalConverter() required this.spent})
      : super._();

  @override
  final String category;
  @override
  final String subcategory;
  @override
  @DecimalConverter()
  final Decimal allocated;
  @override
  @DecimalConverter()
  final Decimal spent;

  /// Create a copy of EnvelopeStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$EnvelopeStatusCopyWith<_EnvelopeStatus> get copyWith =>
      __$EnvelopeStatusCopyWithImpl<_EnvelopeStatus>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _EnvelopeStatus &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.allocated, allocated) ||
                other.allocated == allocated) &&
            (identical(other.spent, spent) || other.spent == spent));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, category, subcategory, allocated, spent);

  @override
  String toString() {
    return 'EnvelopeStatus(category: $category, subcategory: $subcategory, allocated: $allocated, spent: $spent)';
  }
}

/// @nodoc
abstract mixin class _$EnvelopeStatusCopyWith<$Res>
    implements $EnvelopeStatusCopyWith<$Res> {
  factory _$EnvelopeStatusCopyWith(
          _EnvelopeStatus value, $Res Function(_EnvelopeStatus) _then) =
      __$EnvelopeStatusCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String category,
      String subcategory,
      @DecimalConverter() Decimal allocated,
      @DecimalConverter() Decimal spent});
}

/// @nodoc
class __$EnvelopeStatusCopyWithImpl<$Res>
    implements _$EnvelopeStatusCopyWith<$Res> {
  __$EnvelopeStatusCopyWithImpl(this._self, this._then);

  final _EnvelopeStatus _self;
  final $Res Function(_EnvelopeStatus) _then;

  /// Create a copy of EnvelopeStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? category = null,
    Object? subcategory = null,
    Object? allocated = null,
    Object? spent = null,
  }) {
    return _then(_EnvelopeStatus(
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      subcategory: null == subcategory
          ? _self.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as String,
      allocated: null == allocated
          ? _self.allocated
          : allocated // ignore: cast_nullable_to_non_nullable
              as Decimal,
      spent: null == spent
          ? _self.spent
          : spent // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

// dart format on
