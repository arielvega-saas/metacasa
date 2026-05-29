import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

/// Convierte entre `Decimal` (precisión exacta) y el wire-format de Supabase.
///
/// Postgres `numeric` viaja por PostgREST como **String** (para no perder
/// precisión), pero también toleramos `num` por si algún campo llega como
/// número JSON. Nunca usamos `double` para dinero: el round-trip se hace
/// siempre vía `String`.
///
/// Espejo de los `Decimal` de los modelos iOS (Swift `Decimal` ↔ Postgres
/// numeric). El `JsonConverter` se aplica con `@DecimalConverter()` sobre cada
/// campo monetario.
class DecimalConverter implements JsonConverter<Decimal, dynamic> {
  const DecimalConverter();

  @override
  Decimal fromJson(dynamic value) {
    // Aceptamos String ("1234.56") o num (1234.56) → parse vía String para
    // preservar la precisión decimal exacta.
    if (value is Decimal) return value;
    return Decimal.parse(value.toString());
  }

  @override
  dynamic toJson(Decimal value) => value.toString();
}

/// Variante nullable: devuelve `null` cuando el JSON trae `null`.
/// Se aplica con `@DecimalNullConverter()` sobre campos `Decimal?`.
class DecimalNullConverter implements JsonConverter<Decimal?, dynamic> {
  const DecimalNullConverter();

  @override
  Decimal? fromJson(dynamic value) {
    if (value == null) return null;
    if (value is Decimal) return value;
    return Decimal.parse(value.toString());
  }

  @override
  dynamic toJson(Decimal? value) => value?.toString();
}
