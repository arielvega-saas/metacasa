import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio de entitlements (acceso a features premium).
///
/// Lee el cache local `public.user_entitlements` (que escribe el webhook de
/// RevenueCat) y/o consulta el helper SQL `has_active_entitlement`, que ya
/// aplica la lógica de expiración server-side — no la replicamos en cliente.
///
/// Espejo del `EntitlementService` de iOS.
class EntitlementRepository {
  EntitlementRepository(this._client);

  final SupabaseClient _client;

  /// `true` si el usuario actual tiene el entitlement activo (no expirado).
  /// Delega la lógica de expiración a la RPC `has_active_entitlement(ent)`.
  Future<bool> hasActive(String entitlement) async {
    final res = await _client.rpc<dynamic>(
      'has_active_entitlement',
      params: {'ent': entitlement},
    );
    // La RPC retorna un boolean escalar.
    return (res as bool?) ?? false;
  }

  /// Lee una fila puntual de `user_entitlements` por su clave compuesta
  /// (PK = user_id + entitlement; NO hay columna `id`). Devuelve `null` si no
  /// existe (o si RLS la oculta).
  Future<UserEntitlement?> fetchEntitlement(
    String userId,
    String ent,
  ) async {
    final row = await _client
        .from('user_entitlements')
        .select()
        .eq('user_id', userId)
        .eq('entitlement', ent)
        .maybeSingle();
    if (row == null) return null;
    return UserEntitlement.fromJson(row);
  }
}

/// Provider del [EntitlementRepository].
final entitlementRepositoryProvider = Provider<EntitlementRepository>(
  (ref) => EntitlementRepository(supabase),
);
