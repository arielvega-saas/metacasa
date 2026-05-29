import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio del presupuesto zero-based / envelopes. Port de
/// `BudgetService` de iOS (`Core/BudgetService.swift`) contra el MISMO backend
/// Supabase.
///
/// Tablas: `budget_periods` (scoped por household), `budget_allocations`
/// (scoped por period). El saldo de cada envelope NO se reimplementa: se llama
/// a la función SQL `public.envelope_balance(p_period_id, p_category,
/// p_subcategory)` que devuelve el REMANENTE.
class BudgetRepository {
  const BudgetRepository();

  /// Devuelve el período que contiene el mes [year]/[month]; si no existe, crea
  /// uno tipo `month` que abarca todo el mes (UTC). Espejo de
  /// `ensurePeriodForMonth` en iOS.
  Future<BudgetPeriod> ensurePeriodForMonth({
    required String householdId,
    required int year,
    required int month,
  }) async {
    // Rango del mes en UTC: [primer día, último día]. Postgres `date`, así que
    // serializamos como 'YYYY-MM-DD'.
    final DateTime start = DateTime.utc(year, month, 1);
    final DateTime end = DateTime.utc(year, month + 1, 0); // día 0 del mes+1 = último del mes
    final String startStr = _dateOnly(start);
    final String endStr = _dateOnly(end);

    // Buscar un período cuyo [period_start, period_end] contenga el inicio del
    // mes. Tomamos el más reciente por period_start (igual que iOS).
    final List<dynamic> existing = await supabase
        .from('budget_periods')
        .select()
        .eq('household_id', householdId)
        .lte('period_start', startStr)
        .gte('period_end', startStr)
        .order('period_start', ascending: false)
        .limit(1);
    if (existing.isNotEmpty) {
      return BudgetPeriod.fromJson(existing.first as Map<String, dynamic>);
    }

    // Crear el período del mes. id/total_*/ready_to_assign/timestamps los pone
    // el servidor (defaults).
    final Map<String, dynamic> payload = <String, dynamic>{
      'household_id': householdId,
      'period_type': 'month',
      'period_start': startStr,
      'period_end': endStr,
    };
    final Map<String, dynamic> inserted = await supabase
        .from('budget_periods')
        .insert(payload)
        .select()
        .single();
    return BudgetPeriod.fromJson(inserted);
  }

  /// Allocations (envelopes) de un período, ordenadas por categoría.
  Future<List<BudgetAllocation>> fetchAllocations(String periodId) async {
    final List<dynamic> rows = await supabase
        .from('budget_allocations')
        .select()
        .eq('period_id', periodId)
        .order('category', ascending: true)
        .order('subcategory', ascending: true);
    return rows
        .map((dynamic e) => BudgetAllocation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea o actualiza un envelope. Upsert con conflicto en
  /// `period_id,category,subcategory` (clave lógica del envelope). Espejo de
  /// `upsertAllocation` en iOS.
  Future<BudgetAllocation> upsertAllocation({
    required String periodId,
    required String category,
    String subcategory = '',
    required Decimal allocated,
    String currency = 'USD',
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'period_id': periodId,
      'category': category,
      'subcategory': subcategory,
      'allocated': allocated.toString(),
      'currency': currency,
    };
    final Map<String, dynamic> row = await supabase
        .from('budget_allocations')
        .upsert(payload, onConflict: 'period_id,category,subcategory')
        .select()
        .single();
    return BudgetAllocation.fromJson(row);
  }

  /// Cambia el `rollover_mode` (none/surplus/full) de un envelope.
  Future<void> updateRolloverMode({
    required String allocationId,
    required RolloverMode mode,
  }) async {
    await supabase
        .from('budget_allocations')
        .update(<String, dynamic>{'rollover_mode': _rolloverWire(mode)})
        .eq('id', allocationId);
  }

  /// Elimina un envelope del período.
  Future<void> deleteAllocation(String id) async {
    await supabase.from('budget_allocations').delete().eq('id', id);
  }

  /// Saldo restante del envelope vía la función SQL `envelope_balance`. La
  /// función devuelve `numeric`, que PostgREST entrega como String/num: se
  /// parsea a [Decimal] (nunca `double`). Espejo de `envelopeBalance` en iOS.
  Future<Decimal> envelopeBalance(
    String periodId,
    String category, [
    String subcategory = '',
  ]) async {
    final dynamic result = await supabase.rpc(
      'envelope_balance',
      params: <String, dynamic>{
        'p_period_id': periodId,
        'p_category': category,
        'p_subcategory': subcategory,
      },
    );
    if (result == null) return Decimal.zero;
    return Decimal.parse(result.toString());
  }

  /// Wire-value del enum [RolloverMode] (none/surplus/full).
  String _rolloverWire(RolloverMode mode) => switch (mode) {
        RolloverMode.none => 'none',
        RolloverMode.surplus => 'surplus',
        RolloverMode.full => 'full',
      };

  /// 'YYYY-MM-DD' a partir de un [DateTime] (para columnas Postgres `date`).
  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Provider del [BudgetRepository]. Singleton sin estado (el cliente Supabase
/// global es la única dependencia).
final Provider<BudgetRepository> budgetRepositoryProvider =
    Provider<BudgetRepository>((Ref ref) => const BudgetRepository());
