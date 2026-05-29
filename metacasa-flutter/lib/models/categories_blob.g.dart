// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categories_blob.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CategoryItem _$CategoryItemFromJson(Map<String, dynamic> json) =>
    _CategoryItem(
      name: json['name'] as String,
      emoji: json['emoji'] as String?,
      subcategories: (json['subcategories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$CategoryItemToJson(_CategoryItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'emoji': instance.emoji,
      'subcategories': instance.subcategories,
    };

_CategoriesData _$CategoriesDataFromJson(Map<String, dynamic> json) =>
    _CategoriesData(
      gastos: (json['GASTO'] as List<dynamic>?)
              ?.map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <CategoryItem>[],
      ingresos: (json['INGRESO'] as List<dynamic>?)
              ?.map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <CategoryItem>[],
    );

Map<String, dynamic> _$CategoriesDataToJson(_CategoriesData instance) =>
    <String, dynamic>{
      'GASTO': instance.gastos,
      'INGRESO': instance.ingresos,
    };

_CategoriesBlob _$CategoriesBlobFromJson(Map<String, dynamic> json) =>
    _CategoriesBlob(
      householdId: json['household_id'] as String,
      data: CategoriesData.fromJson(json['data'] as Map<String, dynamic>),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$CategoriesBlobToJson(_CategoriesBlob instance) =>
    <String, dynamic>{
      'household_id': instance.householdId,
      'data': instance.data,
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
