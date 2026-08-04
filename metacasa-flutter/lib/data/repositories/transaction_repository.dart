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
        // El extremo se extiende al FINAL de su día. Sin esto, un [to] que venga a
        // medianoche deja afuera todas las transacciones de ese día cargadas después
        // de las 00:00 — que en la práctica son casi todas.
        .lte('date', _endOfDayUtc(to).toIso8601String())
        .order('date', ascending: false)
        .limit(limit);
    return rows
        .map((dynamic e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cierra el rango al final del día, en UTC.
  static DateTime _endOfDayUtc(DateTime d) {
    final DateTime u = d.toUtc();
    return DateTime.utc(u.year, u.month, u.day, 23, 59, 59, 999);
  }

  /// Ingresos y gastos del rango, **agregados en el servidor**.
  ///
  /// Antes bajaba hasta 1000 filas ordenadas por fecha DESC y las sumaba acá. Pasado ese
  /// tope se descartaban las transacciones MÁS VIEJAS del rango y los totales salían
  /// bajos sin ningún aviso — el usuario veía menos gastos de los que tuvo. Un hogar con
  /// movimientos diarios llega a 1000 en pocos meses.
  ///
  /// El fix no es subir el límite: es dejar de bajar filas para sumar. Además, sumar en
  /// el cliente obliga a repetir acá las reglas de negocio (excluir transferencias, el
  /// rango inclusivo del último día); el RPC las tiene una sola vez, compartidas con iOS
  /// y con la web.
  Future<TransactionTotals> totals({
    required String householdId,
    required DateTime from,
    required DateTime to,
  }) async {
    final List<dynamic> rows = await supabase.rpc<List<dynamic>>(
      'transaction_totals',
      params: <String, dynamic>{
        'p_household': householdId,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      },
    );
    if (rows.isEmpty) {
      return TransactionTotals(ingresos: Decimal.zero, gastos: Decimal.zero);
    }
    final Map<String, dynamic> r = rows.first as Map<String, dynamic>;
    return TransactionTotals(
      ingresos: Decimal.parse('${r['ingresos'] ?? 0}'),
      gastos: Decimal.parse('${r['gastos'] ?? 0}'),
    );
  }

  /// Variante pura (sin red): totales sobre una lista ya fetcheada.
  ///
  /// Excluye las transferencias, igual que el RPC. Si no lo hiciera, la misma pantalla
  /// mostraría un número distinto según viniera del servidor o de la lista en memoria —
  /// y el que se calcula acá es el que se ve mientras carga.
  TransactionTotals totalsOf(List<Transaction> transactions) {
    var ingresos = Decimal.zero;
    var gastos = Decimal.zero;
    for (final Transaction tx in transactions.excludingTransfers) {
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
