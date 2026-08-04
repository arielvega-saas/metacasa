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
    /// Une las DOS piernas de una transferencia entre cuentas propias: un GASTO en
    /// la cuenta de origen y un INGRESO en la de destino, con el mismo id.
    ///
    /// Es una columna aditiva y no un valor nuevo de [TxType] a propósito. Un valor
    /// de enum desconocido hace fallar `$enumDecode` con `ArgumentError`, y como el
    /// decode es de lista, UNA fila rara vacía la pantalla entera en vez de mostrar
    /// un movimiento raro. Una key JSON extra, en cambio, la ignora cualquier
    /// cliente viejo que no la conozca.
    @JsonKey(name: 'transfer_group_id') String? transferGroupId,
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
    /// **Siempre en la moneda BASE del hogar** — es el contrato de
    /// `metacasa-web/AGENTS_CONTRACT.md`: todos los agregados lo asumen.
    @DecimalConverter() required Decimal amount,
    /// Monto tal como lo tipeó el usuario, en [currencyOriginal].
    @JsonKey(name: 'amount_original')
    @DecimalNullConverter()
    Decimal? amountOriginal,
    @JsonKey(name: 'currency_original') String? currencyOriginal,
    /// Cuántas unidades de base equivalen a 1 de [currencyOriginal]. 1 si no hubo
    /// conversión. Invariante: `amount == amountOriginal * fxRateToBase`.
    @JsonKey(name: 'fx_rate_to_base')
    @DecimalNullConverter()
    Decimal? fxRateToBase,
    required String category,
    String? subcategory,
    String? note,
    required DateTime date,
  }) = _NewTransactionInput;

  factory NewTransactionInput.fromJson(Map<String, dynamic> json) =>
      _$NewTransactionInputFromJson(json);
}

/// La regla de las transferencias, con nombre.
///
/// Una transferencia entre cuentas propias son DOS movimientos con el mismo
/// [Transaction.transferGroupId]. Eso es lo que mueve bien los saldos por cuenta, pero la
/// plata nunca salió del hogar: **agregarle una transferencia a un conjunto de movimientos
/// no puede cambiar ningún total de ingreso, gasto ni categoría**.
///
/// Va como extensión con nombre y no como un `where(...)` suelto por lo mismo que
/// `txs.excludingTransfers` en iOS: con muchos sitios que suman dinero, escribir el
/// predicado a mano en cada uno es cómo se olvida el último. Con el nombre, un `grep`
/// muestra quién ya lo aplica.
///
/// **Dónde NO va:** en los saldos por cuenta las dos piernas son el mecanismo, no ruido;
/// filtrarlas ahí rompe el saldo, que es peor que el bug original. Tampoco en la lista de
/// movimientos: el usuario tiene que poder ver sus transferencias.
extension TransferFiltering on List<Transaction> {
  List<Transaction> get excludingTransfers =>
      where((Transaction t) => t.transferGroupId == null).toList();
}

extension TransferPredicate on Transaction {
  bool get isTransfer => transferGroupId != null;
}
