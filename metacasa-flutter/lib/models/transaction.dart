import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/decimal_converter.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

/// Tipo de movimiento. Wire-values en MAYÚSCULAS (`GASTO`/`INGRESO`) — espejo
/// de `TxType` en iOS y del enum Postgres.
enum TxType {
  @JsonValue('GASTO')
  gasto,
  @JsonValue('INGRESO')
  ingreso;

  /// Etiqueta legible (es-AR).
  String get label => switch (this) {
        TxType.gasto => 'Gasto',
        TxType.ingreso => 'Ingreso',
      };
}

/// Movimiento (transacción). Espejo 1:1 de `public.transactions`.
@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    @JsonKey(name: 'household_id') required String householdId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'account_id') String? accountId,
    required TxType type,
    @DecimalConverter() required Decimal amount,
    @JsonKey(name: 'amount_original')
    @DecimalNullConverter()
    Decimal? amountOriginal,
    @JsonKey(name: 'currency_original') String? currencyOriginal,
    @JsonKey(name: 'fx_rate_to_base')
    @DecimalNullConverter()
    Decimal? fxRateToBase,
    @JsonKey(name: 'fx_source') String? fxSource,
    @JsonKey(name: 'fx_status') String? fxStatus,
    required String category,
    String? subcategory,
    String? account,
    String? note,
    required DateTime date,
    @JsonKey(name: 'period_year') int? periodYear,
    @JsonKey(name: 'period_month') int? periodMonth,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}

/// Payload para insertar una tx nueva. Supabase completa id/created_at.
/// Espejo de `NewTransactionInput` en iOS.
@freezed
abstract class NewTransactionInput with _$NewTransactionInput {
  const factory NewTransactionInput({
    @JsonKey(name: 'household_id') required String householdId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'account_id') String? accountId,
    required TxType type,
    @DecimalConverter() required Decimal amount,
    @JsonKey(name: 'currency_original') String? currencyOriginal,
    required String category,
    String? subcategory,
    String? note,
    required DateTime date,
  }) = _NewTransactionInput;

  factory NewTransactionInput.fromJson(Map<String, dynamic> json) =>
      _$NewTransactionInputFromJson(json);
}
