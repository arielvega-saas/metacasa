import 'package:freezed_annotation/freezed_annotation.dart';

part 'categories_blob.freezed.dart';
part 'categories_blob.g.dart';

/// Una categoría custom dentro del blob JSONB. Espejo de `CategoryItem` en iOS.
@freezed
abstract class CategoryItem with _$CategoryItem {
  const factory CategoryItem({
    required String name,
    String? emoji,
    List<String>? subcategories,
  }) = _CategoryItem;

  factory CategoryItem.fromJson(Map<String, dynamic> json) =>
      _$CategoryItemFromJson(json);
}

/// Contenido del blob JSONB de categorías. Las CLAVES son MAYÚSCULAS
/// (`GASTO`/`INGRESO`) — espejo de `CategoriesData.CodingKeys` en iOS.
@freezed
abstract class CategoriesData with _$CategoriesData {
  const factory CategoriesData({
    @JsonKey(name: 'GASTO')
    @Default(<CategoryItem>[])
    List<CategoryItem> gastos,
    @JsonKey(name: 'INGRESO')
    @Default(<CategoryItem>[])
    List<CategoryItem> ingresos,
  }) = _CategoriesData;

  factory CategoriesData.fromJson(Map<String, dynamic> json) =>
      _$CategoriesDataFromJson(json);
}

/// Fila de `public.categories` (una por household_id) con su blob JSONB.
/// Espejo 1:1 de `CategoriesBlob` en iOS.
@freezed
abstract class CategoriesBlob with _$CategoriesBlob {
  const factory CategoriesBlob({
    @JsonKey(name: 'household_id') required String householdId,
    required CategoriesData data,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _CategoriesBlob;

  factory CategoriesBlob.fromJson(Map<String, dynamic> json) =>
      _$CategoriesBlobFromJson(json);
}

/// Presets iniciales de categorías (espejo de `CategoryCatalog` en
/// `Models/Categories.swift`). Se usan para sembrar el blob de un hogar nuevo.
abstract final class CategoryCatalog {
  const CategoryCatalog._();

  static const List<String> defaultGastos = <String>[
    'Vivienda',
    'Transporte',
    'Salud',
    'Ocio',
    'Alimentación',
    'Servicios',
  ];

  static const List<String> defaultIngresos = <String>[
    'Sueldo',
    'Inversiones',
    'Ventas',
  ];

  static const Map<String, String> defaultEmojis = <String, String>{
    'Vivienda': '🏠',
    'Transporte': '🚗',
    'Salud': '🏥',
    'Ocio': '🎮',
    'Alimentación': '🍽️',
    'Servicios': '⚡',
    'Sueldo': '💼',
    'Inversiones': '📈',
    'Ventas': '🛍️',
  };

  static const List<String> emojiPalette = <String>[
    '🏠',
    '🚗',
    '🏥',
    '🎮',
    '🍽️',
    '⚡',
    '💼',
    '📈',
    '🛍️',
    '🎓',
    '✈️',
    '🏋️',
    '🐶',
    '🐱',
    '🌿',
    '🎵',
    '📱',
    '💊',
    '🛒',
    '🎁',
    '🏦',
    '💳',
    '🍕',
    '☕',
    '🚌',
    '⛽',
    '🎬',
    '📚',
    '👕',
    '🏡',
    '🔧',
    '🧹',
    '🌙',
    '☀️',
    '🍺',
    '🎯',
    '💰',
    '💸',
    '🤝',
    '📊',
    '🔑',
    '🏊',
    '🎨',
    '💡',
    '🧘',
    '🌊',
    '🚀',
    '🍎',
  ];

  /// Emoji por defecto para [category] (cae a "📌").
  static String emojiFor(String category) => defaultEmojis[category] ?? '📌';
}
