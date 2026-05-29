import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/household_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Estado inmutable de la pantalla de Miembros: la lista de miembros del hogar
/// y las invitaciones **pendientes** (las aceptadas/revocadas/expiradas no se
/// muestran). Clase plana, sin freezed/codegen (por requerimiento).
///
/// Espejo conceptual del `HouseholdMembersViewModel` de iOS, que carga
/// `fetchMembers` + `listInvitations(onlyPending:)` en paralelo. Acá el repo
/// `fetchInvitations` trae TODAS las invitaciones (cualquier status), así que el
/// filtro a `pending` lo aplica el controller — equivalente al `onlyPending`
/// server-side del iOS.
class HouseholdMembersState {
  const HouseholdMembersState({
    required this.members,
    required this.pendingInvitations,
  });

  /// Estado vacío (sin hogar): ambas listas vacías.
  factory HouseholdMembersState.empty() => const HouseholdMembersState(
        members: <HouseholdMember>[],
        pendingInvitations: <HouseholdInvitation>[],
      );

  /// Miembros del hogar, ordenados por `joined_at` (el repo ya los trae así).
  final List<HouseholdMember> members;

  /// Invitaciones en estado `pending` (más recientes primero, como el repo).
  final List<HouseholdInvitation> pendingInvitations;
}

/// Controller de la pantalla de Miembros. `AsyncNotifier` que observa el hogar
/// activo y, ante un switch de hogar, recarga miembros + invitaciones.
///
/// Carga ambas colecciones en paralelo (espejo de los `async let` de iOS). Si
/// las invitaciones fallan (RLS / permisos), degradamos a lista vacía para no
/// tumbar la pantalla entera: un `member`/`viewer` puede ver la lista de
/// miembros aunque no tenga acceso a las invitaciones.
class HouseholdMembersController extends AsyncNotifier<HouseholdMembersState> {
  @override
  Future<HouseholdMembersState> build() async {
    final String? householdId =
        await ref.watch(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      return HouseholdMembersState.empty();
    }
    return _load(householdId);
  }

  Future<HouseholdMembersState> _load(String householdId) async {
    final HouseholdRepository repo = ref.read(householdRepositoryProvider);

    final Future<List<HouseholdMember>> membersF =
        repo.fetchMembers(householdId);
    // Las invitaciones son secundarias: si fallan, no rompemos la pantalla.
    final Future<List<HouseholdInvitation>> invitesF = repo
        .fetchInvitations(householdId)
        .catchError((_) => <HouseholdInvitation>[]);

    final List<HouseholdMember> members = await membersF;
    final List<HouseholdInvitation> invites = await invitesF;

    final List<HouseholdInvitation> pending = invites
        .where((HouseholdInvitation i) => i.status == InvitationStatus.pending)
        .toList();

    return HouseholdMembersState(members: members, pendingInvitations: pending);
  }

  /// Fuerza una recarga (pull-to-refresh / post-invitación / post-cambio).
  /// Mantiene visible el dato previo mientras recomputa.
  Future<void> refresh() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      state = AsyncData(HouseholdMembersState.empty());
      return;
    }
    state = const AsyncLoading<HouseholdMembersState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(householdId));
  }

  /// Quita un miembro del hogar y recarga. La UI ya garantiza que no se quite a
  /// sí mismo y que el caller tenga permiso (gating por rol en la pantalla).
  Future<void> removeMember(String userId) async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) return;
    await ref
        .read(householdRepositoryProvider)
        .removeMember(householdId, userId);
    await refresh();
  }

  /// Revoca una invitación pendiente (soft: `status = 'revoked'`) y recarga.
  Future<void> revokeInvitation(String invitationId) async {
    await ref.read(householdRepositoryProvider).revokeInvitation(invitationId);
    await refresh();
  }
}

/// Provider del controller de Miembros. `AsyncNotifierProvider` (no family): el
/// controller observa `currentHouseholdProvider` internamente, así que se
/// reconstruye solo cuando cambia el hogar activo.
final householdMembersControllerProvider =
    AsyncNotifierProvider<HouseholdMembersController, HouseholdMembersState>(
        HouseholdMembersController.new);
