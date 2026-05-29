import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio del blob de categorías custom del hogar (`public.categories`).
///
/// Port de `CategoryService.swift`. La tabla tiene PK `household_id` y un único
/// blob JSONB en la columna `data`. Si todavía no existe fila, [fetch]
/// devuelve null y el cliente debe mergear con los defaults
/// ([CategoryCatalog]).
class CategoryRepository {
  const CategoryRepository();

  static const String _table = 'categories';

  /// Trae el blob del hogar (o null si todavía no se sembró).
  /// Port de `CategoryService.fetch`.
  Future<CategoriesBlob?> fetch(String householdId) async {
    final Map<String, dynamic>? row = await supabase
        .from(_table)
        .select()
        .eq('household_id', householdId)
        .maybeSingle();
    if (row == null) return null;
    return CategoriesBlob.fromJson(row);
  }

  /// Upsert del blob (onConflict = household_id). Port de
  /// `CategoryService.save`, con un detalle del schema live: la tabla
  /// `categories` tiene `user_id` NOT NULL (sin default), así que lo
  /// inyectamos desde la sesión actual — iOS no lo manda porque su RPC corre
  /// con un default distinto, pero PostgREST acá lo exige.
  ///
  /// Se manda `household_id`, `user_id` y `data`. Se EXCLUYE `updated_at`
  /// (default `now()` server-side).
  Future<CategoriesBlob> save(CategoriesBlob blob) async {
    final String? userId = supabase.auth.currentUser?.id;

    final Map<String, dynamic> payload = blob.toJson()
      ..remove('updated_at')
      ..['user_id'] = userId;

    final Map<String, dynamic> row = await supabase
        .from(_table)
        .upsert(payload, onConflict: 'household_id')
        .select()
        .single();
    return CategoriesBlob.fromJson(row);
  }
}

/// Provider del repositorio de categorías.
final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => const CategoryRepository(),
);
