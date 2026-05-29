// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'categories_blob.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CategoryItem {
  String get name;
  String? get emoji;
  List<String>? get subcategories;

  /// Create a copy of CategoryItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CategoryItemCopyWith<CategoryItem> get copyWith =>
      _$CategoryItemCopyWithImpl<CategoryItem>(
          this as CategoryItem, _$identity);

  /// Serializes this CategoryItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CategoryItem &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            const DeepCollectionEquality()
                .equals(other.subcategories, subcategories));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, emoji,
      const DeepCollectionEquality().hash(subcategories));

  @override
  String toString() {
    return 'CategoryItem(name: $name, emoji: $emoji, subcategories: $subcategories)';
  }
}

/// @nodoc
abstract mixin class $CategoryItemCopyWith<$Res> {
  factory $CategoryItemCopyWith(
          CategoryItem value, $Res Function(CategoryItem) _then) =
      _$CategoryItemCopyWithImpl;
  @useResult
  $Res call({String name, String? emoji, List<String>? subcategories});
}

/// @nodoc
class _$CategoryItemCopyWithImpl<$Res> implements $CategoryItemCopyWith<$Res> {
  _$CategoryItemCopyWithImpl(this._self, this._then);

  final CategoryItem _self;
  final $Res Function(CategoryItem) _then;

  /// Create a copy of CategoryItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? emoji = freezed,
    Object? subcategories = freezed,
  }) {
    return _then(_self.copyWith(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      emoji: freezed == emoji
          ? _self.emoji
          : emoji // ignore: cast_nullable_to_non_nullable
              as String?,
      subcategories: freezed == subcategories
          ? _self.subcategories
          : subcategories // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _CategoryItem implements CategoryItem {
  const _CategoryItem(
      {required this.name, this.emoji, final List<String>? subcategories})
      : _subcategories = subcategories;
  factory _CategoryItem.fromJson(Map<String, dynamic> json) =>
      _$CategoryItemFromJson(json);

  @override
  final String name;
  @override
  final String? emoji;
  final List<String>? _subcategories;
  @override
  List<String>? get subcategories {
    final value = _subcategories;
    if (value == null) return null;
    if (_subcategories is EqualUnmodifiableListView) return _subcategories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Create a copy of CategoryItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CategoryItemCopyWith<_CategoryItem> get copyWith =>
      __$CategoryItemCopyWithImpl<_CategoryItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CategoryItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CategoryItem &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            const DeepCollectionEquality()
                .equals(other._subcategories, _subcategories));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, emoji,
      const DeepCollectionEquality().hash(_subcategories));

  @override
  String toString() {
    return 'CategoryItem(name: $name, emoji: $emoji, subcategories: $subcategories)';
  }
}

/// @nodoc
abstract mixin class _$CategoryItemCopyWith<$Res>
    implements $CategoryItemCopyWith<$Res> {
  factory _$CategoryItemCopyWith(
          _CategoryItem value, $Res Function(_CategoryItem) _then) =
      __$CategoryItemCopyWithImpl;
  @override
  @useResult
  $Res call({String name, String? emoji, List<String>? subcategories});
}

/// @nodoc
class __$CategoryItemCopyWithImpl<$Res>
    implements _$CategoryItemCopyWith<$Res> {
  __$CategoryItemCopyWithImpl(this._self, this._then);

  final _CategoryItem _self;
  final $Res Function(_CategoryItem) _then;

  /// Create a copy of CategoryItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? name = null,
    Object? emoji = freezed,
    Object? subcategories = freezed,
  }) {
    return _then(_CategoryItem(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      emoji: freezed == emoji
          ? _self.emoji
          : emoji // ignore: cast_nullable_to_non_nullable
              as String?,
      subcategories: freezed == subcategories
          ? _self._subcategories
          : subcategories // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// @nodoc
mixin _$CategoriesData {
  @JsonKey(name: 'GASTO')
  List<CategoryItem> get gastos;
  @JsonKey(name: 'INGRESO')
  List<CategoryItem> get ingresos;

  /// Create a copy of CategoriesData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CategoriesDataCopyWith<CategoriesData> get copyWith =>
      _$CategoriesDataCopyWithImpl<CategoriesData>(
          this as CategoriesData, _$identity);

  /// Serializes this CategoriesData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CategoriesData &&
            const DeepCollectionEquality().equals(other.gastos, gastos) &&
            const DeepCollectionEquality().equals(other.ingresos, ingresos));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(gastos),
      const DeepCollectionEquality().hash(ingresos));

  @override
  String toString() {
    return 'CategoriesData(gastos: $gastos, ingresos: $ingresos)';
  }
}

/// @nodoc
abstract mixin class $CategoriesDataCopyWith<$Res> {
  factory $CategoriesDataCopyWith(
          CategoriesData value, $Res Function(CategoriesData) _then) =
      _$CategoriesDataCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'GASTO') List<CategoryItem> gastos,
      @JsonKey(name: 'INGRESO') List<CategoryItem> ingresos});
}

/// @nodoc
class _$CategoriesDataCopyWithImpl<$Res>
    implements $CategoriesDataCopyWith<$Res> {
  _$CategoriesDataCopyWithImpl(this._self, this._then);

  final CategoriesData _self;
  final $Res Function(CategoriesData) _then;

  /// Create a copy of CategoriesData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gastos = null,
    Object? ingresos = null,
  }) {
    return _then(_self.copyWith(
      gastos: null == gastos
          ? _self.gastos
          : gastos // ignore: cast_nullable_to_non_nullable
              as List<CategoryItem>,
      ingresos: null == ingresos
          ? _self.ingresos
          : ingresos // ignore: cast_nullable_to_non_nullable
              as List<CategoryItem>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _CategoriesData implements CategoriesData {
  const _CategoriesData(
      {@JsonKey(name: 'GASTO')
      final List<CategoryItem> gastos = const <CategoryItem>[],
      @JsonKey(name: 'INGRESO')
      final List<CategoryItem> ingresos = const <CategoryItem>[]})
      : _gastos = gastos,
        _ingresos = ingresos;
  factory _CategoriesData.fromJson(Map<String, dynamic> json) =>
      _$CategoriesDataFromJson(json);

  final List<CategoryItem> _gastos;
  @override
  @JsonKey(name: 'GASTO')
  List<CategoryItem> get gastos {
    if (_gastos is EqualUnmodifiableListView) return _gastos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_gastos);
  }

  final List<CategoryItem> _ingresos;
  @override
  @JsonKey(name: 'INGRESO')
  List<CategoryItem> get ingresos {
    if (_ingresos is EqualUnmodifiableListView) return _ingresos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ingresos);
  }

  /// Create a copy of CategoriesData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CategoriesDataCopyWith<_CategoriesData> get copyWith =>
      __$CategoriesDataCopyWithImpl<_CategoriesData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CategoriesDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CategoriesData &&
            const DeepCollectionEquality().equals(other._gastos, _gastos) &&
            const DeepCollectionEquality().equals(other._ingresos, _ingresos));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_gastos),
      const DeepCollectionEquality().hash(_ingresos));

  @override
  String toString() {
    return 'CategoriesData(gastos: $gastos, ingresos: $ingresos)';
  }
}

/// @nodoc
abstract mixin class _$CategoriesDataCopyWith<$Res>
    implements $CategoriesDataCopyWith<$Res> {
  factory _$CategoriesDataCopyWith(
          _CategoriesData value, $Res Function(_CategoriesData) _then) =
      __$CategoriesDataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'GASTO') List<CategoryItem> gastos,
      @JsonKey(name: 'INGRESO') List<CategoryItem> ingresos});
}

/// @nodoc
class __$CategoriesDataCopyWithImpl<$Res>
    implements _$CategoriesDataCopyWith<$Res> {
  __$CategoriesDataCopyWithImpl(this._self, this._then);

  final _CategoriesData _self;
  final $Res Function(_CategoriesData) _then;

  /// Create a copy of CategoriesData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? gastos = null,
    Object? ingresos = null,
  }) {
    return _then(_CategoriesData(
      gastos: null == gastos
          ? _self._gastos
          : gastos // ignore: cast_nullable_to_non_nullable
              as List<CategoryItem>,
      ingresos: null == ingresos
          ? _self._ingresos
          : ingresos // ignore: cast_nullable_to_non_nullable
              as List<CategoryItem>,
    ));
  }
}

/// @nodoc
mixin _$CategoriesBlob {
  @JsonKey(name: 'household_id')
  String get householdId;
  CategoriesData get data;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of CategoriesBlob
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CategoriesBlobCopyWith<CategoriesBlob> get copyWith =>
      _$CategoriesBlobCopyWithImpl<CategoriesBlob>(
          this as CategoriesBlob, _$identity);

  /// Serializes this CategoriesBlob to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CategoriesBlob &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, householdId, data, updatedAt);

  @override
  String toString() {
    return 'CategoriesBlob(householdId: $householdId, data: $data, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $CategoriesBlobCopyWith<$Res> {
  factory $CategoriesBlobCopyWith(
          CategoriesBlob value, $Res Function(CategoriesBlob) _then) =
      _$CategoriesBlobCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'household_id') String householdId,
      CategoriesData data,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});

  $CategoriesDataCopyWith<$Res> get data;
}

/// @nodoc
class _$CategoriesBlobCopyWithImpl<$Res>
    implements $CategoriesBlobCopyWith<$Res> {
  _$CategoriesBlobCopyWithImpl(this._self, this._then);

  final CategoriesBlob _self;
  final $Res Function(CategoriesBlob) _then;

  /// Create a copy of CategoriesBlob
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? householdId = null,
    Object? data = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_self.copyWith(
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as CategoriesData,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }

  /// Create a copy of CategoriesBlob
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CategoriesDataCopyWith<$Res> get data {
    return $CategoriesDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _CategoriesBlob implements CategoriesBlob {
  const _CategoriesBlob(
      {@JsonKey(name: 'household_id') required this.householdId,
      required this.data,
      @JsonKey(name: 'updated_at') this.updatedAt});
  factory _CategoriesBlob.fromJson(Map<String, dynamic> json) =>
      _$CategoriesBlobFromJson(json);

  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  final CategoriesData data;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// Create a copy of CategoriesBlob
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CategoriesBlobCopyWith<_CategoriesBlob> get copyWith =>
      __$CategoriesBlobCopyWithImpl<_CategoriesBlob>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CategoriesBlobToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CategoriesBlob &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, householdId, data, updatedAt);

  @override
  String toString() {
    return 'CategoriesBlob(householdId: $householdId, data: $data, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$CategoriesBlobCopyWith<$Res>
    implements $CategoriesBlobCopyWith<$Res> {
  factory _$CategoriesBlobCopyWith(
          _CategoriesBlob value, $Res Function(_CategoriesBlob) _then) =
      __$CategoriesBlobCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'household_id') String householdId,
      CategoriesData data,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});

  @override
  $CategoriesDataCopyWith<$Res> get data;
}

/// @nodoc
class __$CategoriesBlobCopyWithImpl<$Res>
    implements _$CategoriesBlobCopyWith<$Res> {
  __$CategoriesBlobCopyWithImpl(this._self, this._then);

  final _CategoriesBlob _self;
  final $Res Function(_CategoriesBlob) _then;

  /// Create a copy of CategoriesBlob
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? householdId = null,
    Object? data = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_CategoriesBlob(
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as CategoriesData,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }

  /// Create a copy of CategoriesBlob
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CategoriesDataCopyWith<$Res> get data {
    return $CategoriesDataCopyWith<$Res>(_self.data, (value) {
      return _then(_self.copyWith(data: value));
    });
  }
}

// dart format on
