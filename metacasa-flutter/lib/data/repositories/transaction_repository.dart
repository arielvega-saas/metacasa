import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Resultado de [TransactionRepository.totals]: ingresos y gastos del período.
/// Espejo de la tupla `(ingresos, gastos)` que devuelve `TransactionService`
/// en iOS, pero como tipo nominal (Dart no tiene tuplas con labels estables
/// entre paquetes y un record nos da igual exactitud con mejor legibilidad).
class TransactionTotals {
  const TransactionTotals({required this.ingresos, required this.gastos});

  final Decimal ingresos;
  final Decimal gastos;

  /// Balance del período (ingresos − gastos).
  Decimal get balance => ingresos - gastos;

  static final TransactionTotals zero =
      TransactionTotals(ingresos: Decimal.zero, gastos: Decimal.zero);
}

/// Repositorio de movimientos (`public.transactions`).
///
/// Port 1:1 de `TransactionService.swift`. Todo está scopeado por
/// `household_id`; RLS lo refuerza server-side igual que en iOS/web. Los
/// montos se decodifican como [Decimal] (la columna es `numeric`).
class TransactionRepository {
  const TransactionRepository();

  static const String _table = 'transactions';

  /// Trae los movimientos de un período concreto filtrando por las columnas
  /// `period_year` / `period_month` (igual que la PWA). iOS filtra por rango
  /// de `date`; acá exponemos AMBOS: este método por período exacto y
  /// [fetchRange] por rango de fechas.
  Future<List<Transaction>> fetchForPeriod({
    required String householdId,
    required int year,
    required int month,
  }) async {
    final List<dynamic> rows = await supabase
        .from(_table)
        .select()
        .eq('household_id', householdId)
        .eq('period_year', year)
        .eq('period_month', month)
        .order('date', ascending: false);
    return rows
        .map((dynamic e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Trae los movimientos en un rango de fechas (`date` gte/lte). Espejo del
  /// `fetchForPeriod(from:to:)` de iOS. [from]/[to] son inclusivos.
  Future<List<Transaction>> fetchRange({
    required String householdId,
    required DateTime from,
    required DateTime to,
    int limit = 200,
  }) async {
    final List<dynamic> rows = await supabase
        .from(_table)
        .select()
        .eq('household_id', householdId)
        .gte('date', from.toIso8601String())
        .lte('date', to.toIso8601String())
        .order('date', ascending: false)
        .limit(limit);
    return rows
        .map((dynamic e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Suma `amount` por tipo (ingresos / gastos) sobre un rango de fechas.
  /// Port de `TransactionService.totals`: fetch + reduce en cliente con
  /// [Decimal] para no perder precisión. Usa el mismo rango que [fetchRange].
  Future<TransactionTotals> totals({
    required String householdId,
    required DateTime from,
    required DateTime to,
  }) async {
    final List<Transaction> txs = await fetchRange(
      householdId: householdId,
      from: from,
      to: to,
      limit: 1000,
    );
    return totalsOf(txs);
  }

  /// Variante pura (sin red): calcula totales sobre una lista ya fetcheada.
  /// Útil cuando el caller (HomeViewModel) ya tiene las txs en memoria.
  TransactionTotals totalsOf(List<Transaction> transactions) {
    var ingresos = Decimal.zero;
    var gastos = Decimal.zero;
    for (final Transaction tx in transactions) {
      switch (tx.type) {
        case TxType.ingreso:
          ingresos += tx.amount;
        case TxType.gasto:
          gastos += tx.amount;
      }
    }
    return TransactionTotals(ingresos: ingresos, gastos: gastos);
  }

  /// Inserta un movimiento nuevo. Supabase completa `id`, `created_at` y las
  /// columnas FX/`period_*` por trigger/default. Mandamos exactamente el
  /// payload de [NewTransactionInput] (espejo del Encodable de iOS).
  Future<Transaction> insert(NewTransactionInput input) async {
    final Map<String, dynamic> payload = input.toJson();
    final Map<String, dynamic> row =
        await supabase.from(_table).insert(payload).select().single();
    return Transaction.fromJson(row);
  }

  /// Actualiza un movimiento existente. Solo mandamos los campos EDITABLES
  /// (espejo exacto del `Patch` de `TransactionService.update`): evita pisar
  /// columnas read-only / generadas. Se EXCLUYEN del `toJson()`:
  ///   id, household_id, user_id, period_year, period_month, created_at,
  ///   amount_original, fx_rate_to_base, fx_source, fx_status.
  /// Quedan: account_id, type, amount, currency_original, category,
  ///         subcategory, account, note, date.
  Future<Transaction> update(Transaction transaction) async {
    final Map<String, dynamic> patch = transaction.toJson()
      ..remove('id')
      ..remove('household_id')
      ..remove('user_id')
      ..remove('period_year')
      ..remove('period_month')
      ..remove('created_at')
      ..remove('amount_original')
      ..remove('fx_rate_to_base')
      ..remove('fx_source')
      ..remove('fx_status');

    final Map<String, dynamic> row = await supabase
        .from(_table)
        .update(patch)
        .eq('id', transaction.id)
        .select()
        .single();
    return Transaction.fromJson(row);
  }

  /// Borra un movimiento por id.
  Future<void> delete(String id) async {
    await supabase.from(_table).delete().eq('id', id);
  }
}

/// Provider del repositorio de movimientos.
final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => const TransactionRepository(),
);
