import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/supabase_init.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/household_members_controller.dart';
import 'invite_member_sheet.dart';

/// Pantalla "Miembros del hogar" — espejo de `HouseholdMembersView` (iOS).
///
/// Lista de miembros (nombre/rol, badge "Vos" para el propio usuario) +
/// invitaciones pendientes (email/rol/expiración, con "Revocar"). El botón
/// "Invitar" y las acciones de quitar/revocar están gated al rol del propio
/// usuario (owner/admin via `role.canInvite`).
///
/// Se llega acá vía push interno desde [HouseholdSettingsScreen]; no es una ruta
/// del router.
class HouseholdMembersScreen extends ConsumerWidget {
  const HouseholdMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<HouseholdMembersState> async =
        ref.watch(householdMembersControllerProvider);
    final String? myUserId = supabase.auth.currentUser?.id;

    // Rol del propio usuario (para gating de invitar/quitar/revocar). Defensivo:
    // si no estamos en la lista (aún cargando), tratamos como sin permisos.
    final MemberRole? myRole = async.valueOrNull?.members
        .where((HouseholdMember m) => m.userId == myUserId)
        .map((HouseholdMember m) => m.role)
        .firstOrNull;
    final bool canManage = myRole?.canInvite ?? false;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text('Miembros', style: AppText.h2(c.textPrimary)),
        actions: [
          if (canManage)
            IconButton(
              icon: Icon(LucideIcons.userPlus, color: c.brandPrimary),
              tooltip: 'Invitar miembro',
              onPressed: () => _openInvite(context, ref),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: () =>
            ref.read(householdMembersControllerProvider.notifier).refresh(),
        child: async.when(
          loading: () => const _MembersSkeleton(),
          error: (Object err, StackTrace _) => _ErrorState(
            onRetry: () =>
                ref.read(householdMembersControllerProvider.notifier).refresh(),
          ),
          data: (HouseholdMembersState state) => _MembersList(
            state: state,
            myUserId: myUserId,
            canManage: canManage,
            onInvite: canManage ? () => _openInvite(context, ref) : null,
          ),
        ),
      ),
    );
  }

  Future<void> _openInvite(BuildContext context, WidgetRef ref) async {
    final String? householdId = ref
        .read(householdMembersControllerProvider)
        .valueOrNull
        ?.members
        .map((HouseholdMember m) => m.householdId)
        .firstOrNull;
    if (householdId == null) return;
    HapticFeedback.mediumImpact();
    final bool? created = await InviteMemberSheet.show(context, householdId);
    if (created ?? false) {
      await ref.read(householdMembersControllerProvider.notifier).refresh();
    }
  }
}

// ─────────────────────────────── Lista ─────────────────────────────────────

class _MembersList extends ConsumerWidget {
  const _MembersList({
    required this.state,
    required this.myUserId,
    required this.canManage,
    required this.onInvite,
  });

  final HouseholdMembersState state;
  final String? myUserId;
  final bool canManage;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120, // espacio para el FAB del asistente del shell
      ),
      children: [
        MCSectionHeader(title: 'Miembros (${state.members.length})'),
        const SizedBox(height: Insets.card),
        ...state.members.map((HouseholdMember m) => Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: _MemberRow(
                member: m,
                isMe: m.userId == myUserId,
                canRemove: canManage && m.userId != myUserId,
                onRemove: () => _confirmRemove(context, ref, m),
              ),
            )),
        if (state.pendingInvitations.isNotEmpty) ...[
          const SizedBox(height: Insets.section),
          const MCSectionHeader(title: 'Invitaciones pendientes'),
          const SizedBox(height: Insets.card),
          ...state.pendingInvitations.map((HouseholdInvitation inv) => Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: _InvitationRow(
                  invitation: inv,
                  canRevoke: canManage,
                  onRevoke: () => _confirmRevoke(context, ref, inv),
                ),
              )),
        ],
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    HouseholdMember m,
  ) async {
    final bool ok = await _confirmDialog(
      context,
      title: '¿Quitar miembro?',
      message:
          '${m.displayName ?? 'Esta persona'} dejará de tener acceso al hogar.',
      confirmLabel: 'Quitar',
    );
    if (!ok) return;
    await ref
        .read(householdMembersControllerProvider.notifier)
        .removeMember(m.userId);
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    WidgetRef ref,
    HouseholdInvitation inv,
  ) async {
    final bool ok = await _confirmDialog(
      context,
      title: '¿Revocar invitación?',
      message: 'El código enviado a ${inv.email} dejará de funcionar.',
      confirmLabel: 'Revocar',
    );
    if (!ok) return;
    await ref
        .read(householdMembersControllerProvider.notifier)
        .revokeInvitation(inv.id);
  }
}

// ─────────────────────────────── Fila de miembro ───────────────────────────

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.canRemove,
    required this.onRemove,
  });

  final HouseholdMember member;
  final bool isMe;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.cardLg,
        vertical: Insets.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: c.brandPrimary.withValues(alpha: 0.12),
              shape: SmoothRectangleBorder(
                borderRadius: Radii.smooth(Radii.badge),
              ),
            ),
            child: Icon(LucideIcons.user, size: 20, color: c.brandPrimary),
          ),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName ?? 'Miembro',
                        style: AppText.body(c.textPrimary)
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: Insets.md),
                      const _MeBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: Insets.xxs),
                Text(member.role.label, style: AppText.caption(c.textMuted)),
              ],
            ),
          ),
          if (canRemove) ...[
            const SizedBox(width: Insets.md),
            _IconAction(
              icon: LucideIcons.userMinus,
              color: c.brandDanger,
              tooltip: 'Quitar del hogar',
              onTap: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge "Vos" para el miembro que es el propio usuario.
class _MeBadge extends StatelessWidget {
  const _MeBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: ShapeDecoration(
        color: c.brandPrimary.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
      ),
      child: Text(
        'Vos',
        style: AppText.caption(c.brandPrimary)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─────────────────────────────── Fila de invitación ────────────────────────

class _InvitationRow extends StatelessWidget {
  const _InvitationRow({
    required this.invitation,
    required this.canRevoke,
    required this.onRevoke,
  });

  final HouseholdInvitation invitation;
  final bool canRevoke;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.cardLg,
        vertical: Insets.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: c.brandWarning.withValues(alpha: 0.14),
              shape: SmoothRectangleBorder(
                borderRadius: Radii.smooth(Radii.badge),
              ),
            ),
            child: Icon(LucideIcons.mail, size: 20, color: c.brandWarning),
          ),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.email,
                  style: AppText.body(c.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  '${invitation.role.label} · expira ${_formatDate(invitation.expiresAt)}',
                  style: AppText.caption(c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (canRevoke) ...[
            const SizedBox(width: Insets.md),
            _IconAction(
              icon: LucideIcons.x,
              color: c.brandDanger,
              tooltip: 'Revocar invitación',
              onTap: onRevoke,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final DateTime local = d.toLocal();
    final String dd = local.day.toString().padLeft(2, '0');
    final String mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }
}

// ─────────────────────────────── Acción de ícono ───────────────────────────

/// Botón de ícono compacto (quitar / revocar) — tile con hairline, tap target
/// accesible de 40dp.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.appSurfaceInset,
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.badge),
              side: BorderSide(color: c.appBorder, width: 1),
            ),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Diálogo de confirmación ───────────────────

/// Diálogo de confirmación destructivo reutilizable. Devuelve `true` si el
/// usuario confirma. Look Midnight Sage (surface + hairline + acción coral).
Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final c = context.colors;
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: c.appSurface,
      shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
      title: Text(title, style: AppText.h2(c.textPrimary)),
      content: Text(message, style: AppText.body(c.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Cancelar', style: AppText.body(c.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmLabel,
            style: AppText.body(c.brandDanger)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ─────────────────────────────── Estados ───────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.cloudOff,
            title: 'No pudimos cargar los miembros',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

class _MembersSkeleton extends StatelessWidget {
  const _MembersSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120,
      ),
      children: const [
        _SkeletonBlock(height: 72),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 72),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 72),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      decoration: ShapeDecoration(
        color: c.appSurface,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
      ),
    );
  }
}
