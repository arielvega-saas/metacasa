import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio de hogares (tenants), miembros e invitaciones.
///
/// Espejo del `HouseholdService` de iOS, pero sin el hack de inyección manual
/// de JWT: `supabase_flutter` adjunta el `Authorization: Bearer <token>` de la
/// sesión activa en cada request, y `auth.uid()` se resuelve server-side para
/// RLS y para las RPC `SECURITY DEFINER`.
///
/// El scoping por hogar lo aplica RLS en la DB: las queries `select` traen solo
/// las filas a las que el usuario tiene acceso. No replicamos esa lógica acá.
class HouseholdRepository {
  HouseholdRepository(this._client);

  final SupabaseClient _client;

  // -------------------------------------------------------------------------
  // Hogares
  // -------------------------------------------------------------------------

  /// Hogares de los que el usuario es miembro.
  ///
  /// Confiamos en RLS: `select * from households` ya viene filtrado a los
  /// hogares donde `(select auth.uid())` es miembro (vía policy con join a
  /// `household_members`). No hace falta el join explícito que sí tendríamos
  /// que hacer sin RLS. Orden estable por `created_at` (igual que iOS).
  Future<List<Household>> fetchMine() async {
    final rows = await _client
        .from('households')
        .select()
        .order('created_at', ascending: true);
    return rows.map((e) => Household.fromJson(e)).toList();
  }

  /// Crea un hogar vía la RPC `create_household` (atómica + resuelve el creador
  /// server-side, e inserta al caller como `owner` en `household_members`).
  ///
  /// La RPC devuelve la fila `households` recién creada como objeto JSON.
  Future<Household> create({
    required String name,
    required String currency,
    required String timezone,
  }) async {
    final res = await _client.rpc<dynamic>(
      'create_household',
      params: {
        'p_name': name,
        'p_currency': currency,
        'p_timezone': timezone,
      },
    );
    return Household.fromJson(_asSingleRow(res, 'create_household'));
  }

  /// Acepta una invitación por su token. Agrega al caller como miembro del
  /// hogar correspondiente. Devuelve el `household_id` resultante.
  Future<String> acceptInvitation(String token) async {
    final res = await _client.rpc<dynamic>(
      'accept_household_invitation',
      params: {'invite_token': token},
    );
    // La RPC retorna un uuid escalar (no un objeto).
    return res as String;
  }

  /// Renombra un hogar. Devuelve la fila actualizada.
  Future<Household> rename(String id, String name) async {
    final rows = await _client
        .from('households')
        .update({'name': name})
        .eq('id', id)
        .select();
    return Household.fromJson(_firstRow(rows, 'rename household'));
  }

  /// Cambia la moneda base del hogar (se normaliza a mayúsculas, como iOS).
  /// Devuelve la fila actualizada.
  Future<Household> setCurrency(String id, String code) async {
    final rows = await _client
        .from('households')
        .update({'default_currency': code.toUpperCase()})
        .eq('id', id)
        .select();
    return Household.fromJson(_firstRow(rows, 'setCurrency'));
  }

  /// Patchea el JSONB `strategy` (config waterfall) del hogar.
  /// Devuelve la fila actualizada.
  Future<Household> updateStrategy(String id, HouseholdStrategy strategy) async {
    final rows = await _client
        .from('households')
        .update({'strategy': strategy.toJson()})
        .eq('id', id)
        .select();
    return Household.fromJson(_firstRow(rows, 'updateStrategy'));
  }

  /// Borra un hogar (cascade lo definen las FKs/policies en la DB).
  Future<void> delete(String id) async {
    await _client.from('households').delete().eq('id', id);
  }

  // -------------------------------------------------------------------------
  // Miembros
  //
  // OJO: `household_members` tiene PK compuesta (household_id, user_id) y NO
  // tiene columna `id`. El modelo Dart `HouseholdMember` tampoco la tiene, así
  // que `toJson()` no emite `id` y el decode no la espera. Todas las
  // mutaciones direccionan filas por la clave compuesta, nunca por `id`.
  // -------------------------------------------------------------------------

  /// Miembros de un hogar.
  Future<List<HouseholdMember>> fetchMembers(String householdId) async {
    final rows = await _client
        .from('household_members')
        .select()
        .eq('household_id', householdId)
        .order('joined_at', ascending: true);
    return rows.map((e) => HouseholdMember.fromJson(e)).toList();
  }

  /// Quita un miembro del hogar (por clave compuesta).
  Future<void> removeMember(String householdId, String userId) async {
    await _client
        .from('household_members')
        .delete()
        .eq('household_id', householdId)
        .eq('user_id', userId);
  }

  /// Cambia el rol de un miembro (por clave compuesta).
  Future<void> updateRole(
    String householdId,
    String userId,
    MemberRole role,
  ) async {
    await _client
        .from('household_members')
        .update({'role': role.toDbValue()})
        .eq('household_id', householdId)
        .eq('user_id', userId);
  }

  // -------------------------------------------------------------------------
  // Invitaciones
  // -------------------------------------------------------------------------

  /// Invitaciones de un hogar (más recientes primero, como iOS).
  Future<List<HouseholdInvitation>> fetchInvitations(String householdId) async {
    final rows = await _client
        .from('household_invitations')
        .select()
        .eq('household_id', householdId)
        .order('created_at', ascending: false);
    return rows.map((e) => HouseholdInvitation.fromJson(e)).toList();
  }

  /// Crea una invitación. El servidor completa `invite_token`, `expires_at`,
  /// `status` y `invited_by` (vía default/trigger + `auth.uid()`). Devolvemos
  /// la fila insertada completa, incluido el `invite_token` (para compartir).
  ///
  /// Nota: el rol de una invitación está restringido a admin/member/viewer en
  /// la DB (no `owner`). El caller debe pasar uno válido.
  Future<HouseholdInvitation> createInvitation({
    required String householdId,
    required String email,
    required MemberRole role,
  }) async {
    final rows = await _client
        .from('household_invitations')
        .insert({
          'household_id': householdId,
          'email': email,
          'role': role.toDbValue(),
        })
        .select();
    return HouseholdInvitation.fromJson(_firstRow(rows, 'createInvitation'));
  }

  /// Revoca una invitación (soft: `status = 'revoked'`).
  Future<void> revokeInvitation(String id) async {
    await _client
        .from('household_invitations')
        .update({'status': 'revoked'})
        .eq('id', id);
  }

  // -------------------------------------------------------------------------
  // Helpers de decode defensivo
  // -------------------------------------------------------------------------

  /// Normaliza el retorno de una RPC que devuelve un único registro compuesto.
  /// PostgREST suele devolverlo como `Map`, pero algunos paths lo envuelven en
  /// una `List` de un elemento; cubrimos ambos.
  Map<String, dynamic> _asSingleRow(dynamic res, String op) {
    if (res is Map<String, dynamic>) return res;
    if (res is List && res.isNotEmpty) {
      return res.first as Map<String, dynamic>;
    }
    throw StateError('RPC $op no devolvió una fila usable: $res');
  }

  /// Primera fila de un `select` que esperamos no-vacío (update/insert + select).
  Map<String, dynamic> _firstRow(List<dynamic> rows, String op) {
    if (rows.isEmpty) {
      throw StateError('$op no devolvió filas (RLS bloqueó o id inexistente).');
    }
    return rows.first as Map<String, dynamic>;
  }
}

/// Mapea [MemberRole] al string que espera la DB. No dependemos del `toJson`
/// generado del modelo contenedor para mutaciones puntuales de rol.
extension MemberRoleDb on MemberRole {
  String toDbValue() => switch (this) {
        MemberRole.owner => 'owner',
        MemberRole.admin => 'admin',
        MemberRole.member => 'member',
        MemberRole.viewer => 'viewer',
      };
}

/// Provider del [HouseholdRepository]. Singleton ligado al cliente Supabase
/// global ya inicializado en `initSupabase()`.
final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => HouseholdRepository(supabase),
);
