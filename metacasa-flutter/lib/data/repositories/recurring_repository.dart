import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio de transacciones recurrentes (recurring_transactions). Port de
/// `RecurringService` de iOS (`Core/RecurringService.swift`).
///
/// Scoped por household. `user_id` es NOT NULL sin default → SIEMPRE se
/// completa con el usuario autenticado en `insert`. `next_date` arranca igual a
/// `start_date` si no viene seteado (igual que iOS).
class RecurringRepository {
  const RecurringRepository();

  /// Recurrentes del hogar. Por default sólo las activas (igual que iOS); con
  /// [includeInactive] se traen todas. Orden: próxima fecha asc.
  Future<List<RecurringTransaction>> fetchAll({
    required String householdId,
    bool includeInactive = false,
  }) async {
    var query = supabase
        .from('recurring_transactions')
        .select()
        .eq('household_id', householdId);
    if (!includeInactive) {
      query = query.eq('active', true);
    }
    final List<dynamic> rows = await query.order('next_date', ascending: true);
    return rows
        .map((dynamic e) =>
            RecurringTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea una recurrente. Completa `user_id` con el usuario autenticado
  /// (NOT NULL) y descarta claves server-generated (id, created_at).
  Future<RecurringTransaction> insert(RecurringTransaction recurring) async {
    final Map<String, dynamic> payload = _writePayload(recurring);
    final Map<String, dynamic> row = await supabase
        .from('recurring_transactions')
        .insert(payload)
        .select()
        .single();
    return RecurringTransaction.fromJson(row);
  }

  /// Actualiza una recurrente existente.
  Future<RecurringTransaction> update(RecurringTransaction recurring) async {
    final Map<String, dynamic> payload = _writePayload(recurring);
    final Map<String, dynamic> row = await supabase
        .from('recurring_transactions')
        .update(payload)
        .eq('id', recurring.id)
        .select()
        .single();
    return RecurringTransaction.fromJson(row);
  }

  /// Desactiva una recurrente (`active=false`). Espejo de `deactivate` en iOS.
  Future<void> deactivate(String id) async {
    await supabase
        .from('recurring_transactions')
        .update(<String, dynamic>{'active': false})
        .eq('id', id);
  }

  /// Elimina una recurrente.
  Future<void> delete(String id) async {
    await supabase.from('recurring_transactions').delete().eq('id', id);
  }

  /// Payload de insert/update: `recurring.toJson()` sin claves server-generated
  /// (id, created_at), con `user_id` forzado al usuario actual, fechas
  /// normalizadas a 'YYYY-MM-DD' (columnas Postgres `date`) y `next_date`
  /// defaulteado a `start_date` si falta.
  Map<String, dynamic> _writePayload(RecurringTransaction recurring) {
    final String userId = supabase.auth.currentUser!.id;
    final Map<String, dynamic> json = recurring.toJson()
      ..remove('id')
      ..remove('created_at');
    json['user_id'] = userId;
    json['start_date'] = _dateOnly(recurring.startDate);
    final DateTime? endDate = recurring.endDate;
    json['end_date'] = endDate == null ? null : _dateOnly(endDate);
    json['next_date'] = _dateOnly(recurring.nextDate ?? recurring.startDate);
    return json;
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Provider del [RecurringRepository].
final Provider<RecurringRepository> recurringRepositoryProvider =
    Provider<RecurringRepository>((Ref ref) => const RecurringRepository());
