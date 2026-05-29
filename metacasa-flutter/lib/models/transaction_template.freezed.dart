// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction_template.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TransactionTemplate {
  String get id;
  @JsonKey(name: 'household_id')
  String get householdId;
  String get name;
  String? get emoji;
  TxType get type;
  @DecimalConverter()
  Decimal get amount;
  String get currency;
  String get category;
  String? get subcategory;
  String? get note;
  int get position;
  @JsonKey(name: 'created_by')
  String get createdBy;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of TransactionTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TransactionTemplateCopyWith<TransactionTemplate> get copyWith =>
      _$TransactionTemplateCopyWithImpl<TransactionTemplate>(
          this as TransactionTemplate, _$identity);

  /// Serializes this TransactionTemplate to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TransactionTemplate &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      householdId,
      name,
      emoji,
      type,
      amount,
      currency,
      category,
      subcategory,
      note,
      position,
      createdBy,
      createdAt);

  @override
  String toString() {
    return 'TransactionTemplate(id: $id, householdId: $householdId, name: $name, emoji: $emoji, type: $type, amount: $amount, currency: $currency, category: $category, subcategory: $subcategory, note: $note, position: $position, createdBy: $createdBy, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $TransactionTemplateCopyWith<$Res> {
  factory $TransactionTemplateCopyWith(
          TransactionTemplate value, $Res Function(TransactionTemplate) _then) =
      _$TransactionTemplateCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String name,
      String? emoji,
      TxType type,
      @DecimalConverter() Decimal amount,
      String currency,
      String category,
      String? subcategory,
      String? note,
      int position,
      @JsonKey(name: 'created_by') String createdBy,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class _$TransactionTemplateCopyWithImpl<$Res>
    implements $TransactionTemplateCopyWith<$Res> {
  _$TransactionTemplateCopyWithImpl(this._self, this._then);

  final TransactionTemplate _self;
  final $Res Function(TransactionTemplate) _then;

  /// Create a copy of TransactionTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? name = null,
    Object? emoji = freezed,
    Object? type = null,
    Object? amount = null,
    Object? currency = null,
    Object? category = null,
    Object? subcategory = freezed,
    Object? note = freezed,
    Object? position = null,
    Object? createdBy = null,
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
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      emoji: freezed == emoji
          ? _self.emoji
          : emoji // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as TxType,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
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
      position: null == position
          ? _self.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      createdBy: null == createdBy
          ? _self.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _TransactionTemplate implements TransactionTemplate {
  const _TransactionTemplate(
      {required this.id,
      @JsonKey(name: 'household_id') required this.householdId,
      required this.name,
      this.emoji,
      required this.type,
      @DecimalConverter() required this.amount,
      required this.currency,
      required this.category,
      this.subcategory,
      this.note,
      required this.position,
      @JsonKey(name: 'created_by') required this.createdBy,
      @JsonKey(name: 'created_at') this.createdAt});
  factory _TransactionTemplate.fromJson(Map<String, dynamic> json) =>
      _$TransactionTemplateFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  final String name;
  @override
  final String? emoji;
  @override
  final TxType type;
  @override
  @DecimalConverter()
  final Decimal amount;
  @override
  final String currency;
  @override
  final String category;
  @override
  final String? subcategory;
  @override
  final String? note;
  @override
  final int position;
  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  /// Create a copy of TransactionTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TransactionTemplateCopyWith<_TransactionTemplate> get copyWith =>
      __$TransactionTemplateCopyWithImpl<_TransactionTemplate>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TransactionTemplateToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TransactionTemplate &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      householdId,
      name,
      emoji,
      type,
      amount,
      currency,
      category,
      subcategory,
      note,
      position,
      createdBy,
      createdAt);

  @override
  String toString() {
    return 'TransactionTemplate(id: $id, householdId: $householdId, name: $name, emoji: $emoji, type: $type, amount: $amount, currency: $currency, category: $category, subcategory: $subcategory, note: $note, position: $position, createdBy: $createdBy, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$TransactionTemplateCopyWith<$Res>
    implements $TransactionTemplateCopyWith<$Res> {
  factory _$TransactionTemplateCopyWith(_TransactionTemplate value,
          $Res Function(_TransactionTemplate) _then) =
      __$TransactionTemplateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String name,
      String? emoji,
      TxType type,
      @DecimalConverter() Decimal amount,
      String currency,
      String category,
      String? subcategory,
      String? note,
      int position,
      @JsonKey(name: 'created_by') String createdBy,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class __$TransactionTemplateCopyWithImpl<$Res>
    implements _$TransactionTemplateCopyWith<$Res> {
  __$TransactionTemplateCopyWithImpl(this._self, this._then);

  final _TransactionTemplate _self;
  final $Res Function(_TransactionTemplate) _then;

  /// Create a copy of TransactionTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? name = null,
    Object? emoji = freezed,
    Object? type = null,
    Object? amount = null,
    Object? currency = null,
    Object? category = null,
    Object? subcategory = freezed,
    Object? note = freezed,
    Object? position = null,
    Object? createdBy = null,
    Object? createdAt = freezed,
  }) {
    return _then(_TransactionTemplate(
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
      emoji: freezed == emoji
          ? _self.emoji
          : emoji // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as TxType,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
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
      position: null == position
          ? _self.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      createdBy: null == createdBy
          ? _self.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
