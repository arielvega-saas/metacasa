import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio de deudas (debts). Port de `DebtService` de iOS
/// (`Core/DebtService.swift`). Scoped por household.
class DebtRepository {
  const DebtRepository();

  /// Deudas del hogar. Si [includeSettled] es `false`, sólo las activas.
  /// Orden: creación desc (igual que iOS).
  Future<List<Debt>> fetchAll({
    required String householdId,
    bool includeSettled = true,
  }) async {
    var query =
        supabase.from('debts').select().eq('household_id', householdId);
    if (!includeSettled) {
      query = query.eq('status', 'active');
    }
    final List<dynamic> rows = await query.order('created_at', ascending: false);
    return rows
        .map((dynamic e) => Debt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea una deuda. Descarta claves server-generated.
  Future<Debt> insert(Debt debt) async {
    final Map<String, dynamic> payload = _writePayload(debt);
    final Map<String, dynamic> row =
        await supabase.from('debts').insert(payload).select().single();
    return Debt.fromJson(row);
  }

  /// Actualiza una deuda existente.
  Future<Debt> update(Debt debt) async {
    final Map<String, dynamic> payload = _writePayload(debt);
    final Map<String, dynamic> row = await supabase
        .from('debts')
        .update(payload)
        .eq('id', debt.id)
        .select()
        .single();
    return Debt.fromJson(row);
  }

  /// Salda la deuda: `status='settled'`, `current_balance=0`. Espejo de
  /// `settle` en iOS.
  Future<void> settle(String id) async {
    await supabase
        .from('debts')
        .update(<String, dynamic>{'status': 'settled', 'current_balance': '0'})
        .eq('id', id);
  }

  /// Elimina una deuda.
  Future<void> delete(String id) async {
    await supabase.from('debts').delete().eq('id', id);
  }

  /// Payload de insert/update: `debt.toJson()` sin claves server-generated
  /// (id, created_at, updated_at), con `start_date`/`maturity_date`
  /// normalizadas a 'YYYY-MM-DD' (columnas Postgres `date`).
  Map<String, dynamic> _writePayload(Debt debt) {
    final Map<String, dynamic> json = debt.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at');
    json['start_date'] = _dateOnly(debt.startDate);
    final DateTime? mat = debt.maturityDate;
    if (mat != null) {
      json['maturity_date'] = _dateOnly(mat);
    }
    return json;
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Provider del [DebtRepository].
final Provider<DebtRepository> debtRepositoryProvider =
    Provider<DebtRepository>((Ref ref) => const DebtRepository());
