// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Goal {
  String get id;
  @JsonKey(name: 'household_id')
  String get householdId;
  String get name;
  String? get description;
  @JsonKey(name: 'target_amount')
  @DecimalConverter()
  Decimal get targetAmount;
  @JsonKey(name: 'current_amount')
  @DecimalConverter()
  Decimal get currentAmount;
  String get currency;
  @JsonKey(name: 'target_date')
  DateTime? get targetDate;
  GoalStatus get status;
  String? get icon;
  String? get color;
  int get priority;
  String? get category;
  @JsonKey(name: 'account_id')
  String? get accountId;
  String? get notes;
  @JsonKey(name: 'created_by')
  String get createdBy;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;
  @JsonKey(name: 'completed_at')
  DateTime? get completedAt;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GoalCopyWith<Goal> get copyWith =>
      _$GoalCopyWithImpl<Goal>(this as Goal, _$identity);

  /// Serializes this Goal to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Goal &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.targetAmount, targetAmount) ||
                other.targetAmount == targetAmount) &&
            (identical(other.currentAmount, currentAmount) ||
                other.currentAmount == currentAmount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.targetDate, targetDate) ||
                other.targetDate == targetDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        householdId,
        name,
        description,
        targetAmount,
        currentAmount,
        currency,
        targetDate,
        status,
        icon,
        color,
        priority,
        category,
        accountId,
        notes,
        createdBy,
        createdAt,
        updatedAt,
        completedAt
      ]);

  @override
  String toString() {
    return 'Goal(id: $id, householdId: $householdId, name: $name, description: $description, targetAmount: $targetAmount, currentAmount: $currentAmount, currency: $currency, targetDate: $targetDate, status: $status, icon: $icon, color: $color, priority: $priority, category: $category, accountId: $accountId, notes: $notes, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, completedAt: $completedAt)';
  }
}

/// @nodoc
abstract mixin class $GoalCopyWith<$Res> {
  factory $GoalCopyWith(Goal value, $Res Function(Goal) _then) =
      _$GoalCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String name,
      String? description,
      @JsonKey(name: 'target_amount') @DecimalConverter() Decimal targetAmount,
      @JsonKey(name: 'current_amount')
      @DecimalConverter()
      Decimal currentAmount,
      String currency,
      @JsonKey(name: 'target_date') DateTime? targetDate,
      GoalStatus status,
      String? icon,
      String? color,
      int priority,
      String? category,
      @JsonKey(name: 'account_id') String? accountId,
      String? notes,
      @JsonKey(name: 'created_by') String createdBy,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt,
      @JsonKey(name: 'completed_at') DateTime? completedAt});
}

/// @nodoc
class _$GoalCopyWithImpl<$Res> implements $GoalCopyWith<$Res> {
  _$GoalCopyWithImpl(this._self, this._then);

  final Goal _self;
  final $Res Function(Goal) _then;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? name = null,
    Object? description = freezed,
    Object? targetAmount = null,
    Object? currentAmount = null,
    Object? currency = null,
    Object? targetDate = freezed,
    Object? status = null,
    Object? icon = freezed,
    Object? color = freezed,
    Object? priority = null,
    Object? category = freezed,
    Object? accountId = freezed,
    Object? notes = freezed,
    Object? createdBy = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? completedAt = freezed,
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
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      targetAmount: null == targetAmount
          ? _self.targetAmount
          : targetAmount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currentAmount: null == currentAmount
          ? _self.currentAmount
          : currentAmount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      targetDate: freezed == targetDate
          ? _self.targetDate
          : targetDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as GoalStatus,
      icon: freezed == icon
          ? _self.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      color: freezed == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
      priority: null == priority
          ? _self.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      category: freezed == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      accountId: freezed == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
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
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Goal extends Goal {
  const _Goal(
      {required this.id,
      @JsonKey(name: 'household_id') required this.householdId,
      required this.name,
      this.description,
      @JsonKey(name: 'target_amount')
      @DecimalConverter()
      required this.targetAmount,
      @JsonKey(name: 'current_amount')
      @DecimalConverter()
      required this.currentAmount,
      required this.currency,
      @JsonKey(name: 'target_date') this.targetDate,
      required this.status,
      this.icon,
      this.color,
      required this.priority,
      this.category,
      @JsonKey(name: 'account_id') this.accountId,
      this.notes,
      @JsonKey(name: 'created_by') required this.createdBy,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt,
      @JsonKey(name: 'completed_at') this.completedAt})
      : super._();
  factory _Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  final String name;
  @override
  final String? description;
  @override
  @JsonKey(name: 'target_amount')
  @DecimalConverter()
  final Decimal targetAmount;
  @override
  @JsonKey(name: 'current_amount')
  @DecimalConverter()
  final Decimal currentAmount;
  @override
  final String currency;
  @override
  @JsonKey(name: 'target_date')
  final DateTime? targetDate;
  @override
  final GoalStatus status;
  @override
  final String? icon;
  @override
  final String? color;
  @override
  final int priority;
  @override
  final String? category;
  @override
  @JsonKey(name: 'account_id')
  final String? accountId;
  @override
  final String? notes;
  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @override
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GoalCopyWith<_Goal> get copyWith =>
      __$GoalCopyWithImpl<_Goal>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GoalToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Goal &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.targetAmount, targetAmount) ||
                other.targetAmount == targetAmount) &&
            (identical(other.currentAmount, currentAmount) ||
                other.currentAmount == currentAmount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.targetDate, targetDate) ||
                other.targetDate == targetDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        householdId,
        name,
        description,
        targetAmount,
        currentAmount,
        currency,
        targetDate,
        status,
        icon,
        color,
        priority,
        category,
        accountId,
        notes,
        createdBy,
        createdAt,
        updatedAt,
        completedAt
      ]);

  @override
  String toString() {
    return 'Goal(id: $id, householdId: $householdId, name: $name, description: $description, targetAmount: $targetAmount, currentAmount: $currentAmount, currency: $currency, targetDate: $targetDate, status: $status, icon: $icon, color: $color, priority: $priority, category: $category, accountId: $accountId, notes: $notes, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, completedAt: $completedAt)';
  }
}

/// @nodoc
abstract mixin class _$GoalCopyWith<$Res> implements $GoalCopyWith<$Res> {
  factory _$GoalCopyWith(_Goal value, $Res Function(_Goal) _then) =
      __$GoalCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String name,
      String? description,
      @JsonKey(name: 'target_amount') @DecimalConverter() Decimal targetAmount,
      @JsonKey(name: 'current_amount')
      @DecimalConverter()
      Decimal currentAmount,
      String currency,
      @JsonKey(name: 'target_date') DateTime? targetDate,
      GoalStatus status,
      String? icon,
      String? color,
      int priority,
      String? category,
      @JsonKey(name: 'account_id') String? accountId,
      String? notes,
      @JsonKey(name: 'created_by') String createdBy,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt,
      @JsonKey(name: 'completed_at') DateTime? completedAt});
}

/// @nodoc
class __$GoalCopyWithImpl<$Res> implements _$GoalCopyWith<$Res> {
  __$GoalCopyWithImpl(this._self, this._then);

  final _Goal _self;
  final $Res Function(_Goal) _then;

  /// Create a copy of Goal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? name = null,
    Object? description = freezed,
    Object? targetAmount = null,
    Object? currentAmount = null,
    Object? currency = null,
    Object? targetDate = freezed,
    Object? status = null,
    Object? icon = freezed,
    Object? color = freezed,
    Object? priority = null,
    Object? category = freezed,
    Object? accountId = freezed,
    Object? notes = freezed,
    Object? createdBy = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? completedAt = freezed,
  }) {
    return _then(_Goal(
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
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      targetAmount: null == targetAmount
          ? _self.targetAmount
          : targetAmount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currentAmount: null == currentAmount
          ? _self.currentAmount
          : currentAmount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      targetDate: freezed == targetDate
          ? _self.targetDate
          : targetDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as GoalStatus,
      icon: freezed == icon
          ? _self.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      color: freezed == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
      priority: null == priority
          ? _self.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      category: freezed == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      accountId: freezed == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
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
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
mixin _$GoalContribution {
  String get id;
  @JsonKey(name: 'goal_id')
  String get goalId;
  @DecimalConverter()
  Decimal get amount;
  @JsonKey(name: 'contributed_by')
  String get contributedBy;
  @JsonKey(name: 'contributed_at')
  DateTime get contributedAt;
  String? get notes;
  @JsonKey(name: 'transaction_id')
  String? get transactionId;

  /// Create a copy of GoalContribution
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GoalContributionCopyWith<GoalContribution> get copyWith =>
      _$GoalContributionCopyWithImpl<GoalContribution>(
          this as GoalContribution, _$identity);

  /// Serializes this GoalContribution to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GoalContribution &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.goalId, goalId) || other.goalId == goalId) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.contributedBy, contributedBy) ||
                other.contributedBy == contributedBy) &&
            (identical(other.contributedAt, contributedAt) ||
                other.contributedAt == contributedAt) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.transactionId, transactionId) ||
                other.transactionId == transactionId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, goalId, amount,
      contributedBy, contributedAt, notes, transactionId);

  @override
  String toString() {
    return 'GoalContribution(id: $id, goalId: $goalId, amount: $amount, contributedBy: $contributedBy, contributedAt: $contributedAt, notes: $notes, transactionId: $transactionId)';
  }
}

/// @nodoc
abstract mixin class $GoalContributionCopyWith<$Res> {
  factory $GoalContributionCopyWith(
          GoalContribution value, $Res Function(GoalContribution) _then) =
      _$GoalContributionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'goal_id') String goalId,
      @DecimalConverter() Decimal amount,
      @JsonKey(name: 'contributed_by') String contributedBy,
      @JsonKey(name: 'contributed_at') DateTime contributedAt,
      String? notes,
      @JsonKey(name: 'transaction_id') String? transactionId});
}

/// @nodoc
class _$GoalContributionCopyWithImpl<$Res>
    implements $GoalContributionCopyWith<$Res> {
  _$GoalContributionCopyWithImpl(this._self, this._then);

  final GoalContribution _self;
  final $Res Function(GoalContribution) _then;

  /// Create a copy of GoalContribution
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? goalId = null,
    Object? amount = null,
    Object? contributedBy = null,
    Object? contributedAt = null,
    Object? notes = freezed,
    Object? transactionId = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      goalId: null == goalId
          ? _self.goalId
          : goalId // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      contributedBy: null == contributedBy
          ? _self.contributedBy
          : contributedBy // ignore: cast_nullable_to_non_nullable
              as String,
      contributedAt: null == contributedAt
          ? _self.contributedAt
          : contributedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      transactionId: freezed == transactionId
          ? _self.transactionId
          : transactionId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _GoalContribution implements GoalContribution {
  const _GoalContribution(
      {required this.id,
      @JsonKey(name: 'goal_id') required this.goalId,
      @DecimalConverter() required this.amount,
      @JsonKey(name: 'contributed_by') required this.contributedBy,
      @JsonKey(name: 'contributed_at') required this.contributedAt,
      this.notes,
      @JsonKey(name: 'transaction_id') this.transactionId});
  factory _GoalContribution.fromJson(Map<String, dynamic> json) =>
      _$GoalContributionFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'goal_id')
  final String goalId;
  @override
  @DecimalConverter()
  final Decimal amount;
  @override
  @JsonKey(name: 'contributed_by')
  final String contributedBy;
  @override
  @JsonKey(name: 'contributed_at')
  final DateTime contributedAt;
  @override
  final String? notes;
  @override
  @JsonKey(name: 'transaction_id')
  final String? transactionId;

  /// Create a copy of GoalContribution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GoalContributionCopyWith<_GoalContribution> get copyWith =>
      __$GoalContributionCopyWithImpl<_GoalContribution>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GoalContributionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _GoalContribution &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.goalId, goalId) || other.goalId == goalId) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.contributedBy, contributedBy) ||
                other.contributedBy == contributedBy) &&
            (identical(other.contributedAt, contributedAt) ||
                other.contributedAt == contributedAt) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.transactionId, transactionId) ||
                other.transactionId == transactionId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, goalId, amount,
      contributedBy, contributedAt, notes, transactionId);

  @override
  String toString() {
    return 'GoalContribution(id: $id, goalId: $goalId, amount: $amount, contributedBy: $contributedBy, contributedAt: $contributedAt, notes: $notes, transactionId: $transactionId)';
  }
}

/// @nodoc
abstract mixin class _$GoalContributionCopyWith<$Res>
    implements $GoalContributionCopyWith<$Res> {
  factory _$GoalContributionCopyWith(
          _GoalContribution value, $Res Function(_GoalContribution) _then) =
      __$GoalContributionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'goal_id') String goalId,
      @DecimalConverter() Decimal amount,
      @JsonKey(name: 'contributed_by') String contributedBy,
      @JsonKey(name: 'contributed_at') DateTime contributedAt,
      String? notes,
      @JsonKey(name: 'transaction_id') String? transactionId});
}

/// @nodoc
class __$GoalContributionCopyWithImpl<$Res>
    implements _$GoalContributionCopyWith<$Res> {
  __$GoalContributionCopyWithImpl(this._self, this._then);

  final _GoalContribution _self;
  final $Res Function(_GoalContribution) _then;

  /// Create a copy of GoalContribution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? goalId = null,
    Object? amount = null,
    Object? contributedBy = null,
    Object? contributedAt = null,
    Object? notes = freezed,
    Object? transactionId = freezed,
  }) {
    return _then(_GoalContribution(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      goalId: null == goalId
          ? _self.goalId
          : goalId // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      contributedBy: null == contributedBy
          ? _self.contributedBy
          : contributedBy // ignore: cast_nullable_to_non_nullable
              as String,
      contributedAt: null == contributedAt
          ? _self.contributedAt
          : contributedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      transactionId: freezed == transactionId
          ? _self.transactionId
          : transactionId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
