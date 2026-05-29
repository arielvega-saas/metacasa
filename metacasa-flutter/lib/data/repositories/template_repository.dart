import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio de plantillas de transacción / quick shortcuts
/// (`public.transaction_templates`).
///
/// Port de `TemplateService.swift`. Scopeado por `household_id`, ordenado por
/// `position`. RLS server-side.
class TemplateRepository {
  const TemplateRepository();

  static const String _table = 'transaction_templates';

  /// Trae todas las plantillas del hogar ordenadas por `position` asc.
  /// Port de `TemplateService.fetchAll`.
  Future<List<TransactionTemplate>> fetchAll(String householdId) async {
    final List<dynamic> rows = await supabase
        .from(_table)
        .select()
        .eq('household_id', householdId)
        .order('position', ascending: true);
    return rows
        .map((dynamic e) =>
            TransactionTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Inserta una plantilla. Se EXCLUYEN `id` y `created_at` (server-generated);
  /// el resto (incluido `created_by`, que el caller setea con el userId) viaja
  /// como en el `create` de iOS.
  Future<TransactionTemplate> insert(TransactionTemplate template) async {
    final Map<String, dynamic> payload = template.toJson()
      ..remove('id')
      ..remove('created_at');

    final Map<String, dynamic> row =
        await supabase.from(_table).insert(payload).select().single();
    return TransactionTemplate.fromJson(row);
  }

  /// Actualiza una plantilla completa. Se EXCLUYEN id, household_id y
  /// created_at (identidad / server-generated). Quedan name, emoji, type,
  /// amount, currency, category, subcategory, note, position, created_by.
  Future<TransactionTemplate> update(TransactionTemplate template) async {
    final Map<String, dynamic> patch = template.toJson()
      ..remove('id')
      ..remove('household_id')
      ..remove('created_at');

    final Map<String, dynamic> row = await supabase
        .from(_table)
        .update(patch)
        .eq('id', template.id)
        .select()
        .single();
    return TransactionTemplate.fromJson(row);
  }

  /// Actualiza solo la posición (para reordenar drag&drop). Port de
  /// `TemplateService.updatePosition`.
  Future<void> updatePosition(String id, int position) async {
    await supabase
        .from(_table)
        .update(<String, dynamic>{'position': position}).eq('id', id);
  }

  /// Borra una plantilla por id. Port de `TemplateService.delete`.
  Future<void> delete(String id) async {
    await supabase.from(_table).delete().eq('id', id);
  }
}

/// Provider del repositorio de plantillas.
final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => const TemplateRepository(),
);
