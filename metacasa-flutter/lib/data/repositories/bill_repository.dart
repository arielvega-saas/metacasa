import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio de vencimientos (bills). Port de `BillService` de iOS
/// (`Core/BillService.swift`), pero alineado al schema REAL de la DB viva (que
/// está más actualizado que el struct Swift):
///   id, user_id, household_id, title, amount, currency, due_date, status,
///   recurrence_type, reminder_days, amount_original, currency_original,
///   fx_rate_to_base, category, created_at.
///
/// OJO: la DB NO tiene `paid_at`/`account_id`/`note`/`recurring`; por eso
/// `markPaid` sólo setea `status='paid'`. Las notificaciones locales (que en
/// iOS dispara este service) viven fuera de la capa de datos en Flutter.
///
/// `user_id` es NOT NULL sin default → SIEMPRE se completa con el usuario
/// autenticado en `insert`.
class BillRepository {
  const BillRepository();

  /// Vencimientos del hogar para un mes calendario [year]/[month] (UTC),
  /// ordenados por fecha. Espejo de `fetchForMonth` en iOS.
  Future<List<Bill>> fetchForMonth({
    required String householdId,
    required int year,
    required int month,
  }) async {
    final String start = _dateOnly(DateTime.utc(year, month, 1));
    final String end = _dateOnly(DateTime.utc(year, month + 1, 0));
    final List<dynamic> rows = await supabase
        .from('bills')
        .select()
        .eq('household_id', householdId)
        .gte('due_date', start)
        .lte('due_date', end)
        .order('due_date', ascending: true);
    return _mapList(rows);
  }

  /// Próximos vencimientos PENDIENTES dentro de [daysAhead] días. Espejo de
  /// `fetchUpcoming` en iOS.
  Future<List<Bill>> fetchUpcoming({
    required String householdId,
    int daysAhead = 30,
  }) async {
    final DateTime now = DateTime.now();
    final String to = _dateOnly(now.add(Duration(days: daysAhead)));
    final List<dynamic> rows = await supabase
        .from('bills')
        .select()
        .eq('household_id', householdId)
        .eq('status', 'pending')
        .lte('due_date', to)
        .order('due_date', ascending: true);
    return _mapList(rows);
  }

  /// Inserta un vencimiento. Completa `user_id` con el usuario autenticado
  /// (NOT NULL en DB) y descarta las claves server-generated (id, created_at).
  Future<Bill> insert(Bill bill) async {
    final Map<String, dynamic> payload = _insertPayload(bill);
    final Map<String, dynamic> row =
        await supabase.from('bills').insert(payload).select().single();
    return Bill.fromJson(row);
  }

  /// Marca el vencimiento como pagado (`status='paid'`). La DB no tiene
  /// `paid_at`, así que sólo cambia el estado. Espejo de `markPaid` en iOS.
  Future<void> markPaid(String id) async {
    await supabase
        .from('bills')
        .update(<String, dynamic>{'status': 'paid'})
        .eq('id', id);
  }

  /// Actualiza un vencimiento existente. Descarta id/created_at; mantiene
  /// household_id/user_id (idempotente respecto del owner).
  Future<Bill> update(Bill bill) async {
    final Map<String, dynamic> payload = _insertPayload(bill);
    final Map<String, dynamic> row = await supabase
        .from('bills')
        .update(payload)
        .eq('id', bill.id)
        .select()
        .single();
    return Bill.fromJson(row);
  }

  /// Elimina un vencimiento.
  Future<void> delete(String id) async {
    await supabase.from('bills').delete().eq('id', id);
  }

  // MARK: - Helpers

  /// Payload de insert/update: `bill.toJson()` sin claves generadas por el
  /// servidor (id, created_at), con `user_id` forzado al usuario actual y
  /// `due_date` normalizada a 'YYYY-MM-DD' (columna Postgres `date`).
  Map<String, dynamic> _insertPayload(Bill bill) {
    final String userId = supabase.auth.currentUser!.id;
    final Map<String, dynamic> json = bill.toJson()
      ..remove('id')
      ..remove('created_at');
    json['user_id'] = userId;
    json['due_date'] = _dateOnly(bill.dueDate);
    return json;
  }

  List<Bill> _mapList(List<dynamic> rows) => rows
      .map((dynamic e) => Bill.fromJson(e as Map<String, dynamic>))
      .toList();

  /// 'YYYY-MM-DD' para columnas Postgres `date`.
  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Provider del [BillRepository].
final Provider<BillRepository> billRepositoryProvider =
    Provider<BillRepository>((Ref ref) => const BillRepository());
