import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/household_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/presentation/auth_field.dart';

/// Hoja "Invitar miembro" — espejo de `InviteMemberView` (iOS).
///
/// Dos estados:
///   1. **Input**: email + selector de rol (admin/member/viewer — NUNCA owner) →
///      `createInvitation`.
///   2. **Éxito**: muestra el `inviteToken` resultante en monoespaciado con un
///      botón "Copiar" (Clipboard + SnackBar, igual que los links legales de
///      auth — `share_plus` no está disponible) y un texto listo para compartir.
///
/// Devuelve `true` por el `Navigator` si llegó a crear una invitación (el caller
/// refresca la lista de miembros/invitaciones).
class InviteMemberSheet extends ConsumerStatefulWidget {
  const InviteMemberSheet({super.key, required this.householdId});

  /// Hogar al que se invita.
  final String householdId;

  /// Presenta la hoja como modal full-height. Resuelve a `true` si se creó una
  /// invitación.
  static Future<bool?> show(BuildContext context, String householdId) {
    final c = context.colors;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => InviteMemberSheet(householdId: householdId),
    );
  }

  @override
  ConsumerState<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<InviteMemberSheet> {
  final _email = TextEditingController();

  /// Roles invitables (sin `owner`, restringido también en la DB).
  static const List<MemberRole> _roles = <MemberRole>[
    MemberRole.admin,
    MemberRole.member,
    MemberRole.viewer,
  ];

  MemberRole _role = MemberRole.member;
  bool _loading = false;
  String? _error;

  /// Invitación creada (cuando no es null, pasamos al estado de éxito).
  HouseholdInvitation? _created;

  @override
  void initState() {
    super.initState();
    _email.addListener(_onChanged);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Validez mínima: el email contiene "@" (mismo criterio laxo que iOS).
  bool get _isValid => _email.text.contains('@');

  Future<void> _submit() async {
    if (_loading || !_isValid) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final HouseholdInvitation invite =
          await ref.read(householdRepositoryProvider).createInvitation(
                householdId: widget.householdId,
                email: _email.text.trim(),
                role: _role,
              );
      if (mounted) {
        setState(() => _created = invite);
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'No se pudo crear la invitación. Probá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Copia el token al portapapeles + feedback (SnackBar). `share_plus` no está
  /// disponible, así que compartir == copiar, igual que los links legales de auth.
  void _copy(String token) {
    Clipboard.setData(ClipboardData(text: token));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código de invitación copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Insets.cardLg,
            Insets.md,
            Insets.cardLg,
            Insets.xxl,
          ),
          child: _created == null ? _buildInput() : _buildSuccess(_created!),
        ),
      ),
    );
  }

  // ─────────────────────────────── Input ───────────────────────────────────

  Widget _buildInput() {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(LucideIcons.userPlus, size: 20, color: c.brandPrimary),
            const SizedBox(width: Insets.md),
            Text('Invitar miembro', style: AppText.h2(c.textPrimary)),
          ],
        ),
        const SizedBox(height: Insets.section),
        AuthTextField(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          enabled: !_loading,
        ),
        const SizedBox(height: Insets.sm),
        Text(
          'Le mandamos el código a esta persona para que se una al hogar.',
          style: AppText.caption(c.textMuted),
        ),
        const SizedBox(height: Insets.section),
        _RolePicker(
          value: _role,
          roles: _roles,
          enabled: !_loading,
          onChanged: (MemberRole r) => setState(() => _role = r),
        ),
        if (_error != null) ...[
          const SizedBox(height: Insets.section),
          _MessageCard(message: _error!, color: c.brandDanger),
        ],
        const SizedBox(height: Insets.cardLg),
        MCPrimaryButton(
          label: _loading ? 'Creando…' : 'Crear invitación',
          onPressed: (_loading || !_isValid) ? null : _submit,
        ),
      ],
    );
  }

  // ─────────────────────────────── Éxito ───────────────────────────────────

  Widget _buildSuccess(HouseholdInvitation invite) {
    final c = context.colors;
    final String expires = _formatDate(invite.expiresAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(LucideIcons.checkCircle2, size: 20, color: c.brandSuccess),
            const SizedBox(width: Insets.md),
            Expanded(
              child:
                  Text('Invitación creada', style: AppText.h2(c.textPrimary)),
            ),
          ],
        ),
        const SizedBox(height: Insets.section),

        Text(
          'Compartí este código con ${invite.email} para que se sume al hogar:',
          style: AppText.body(c.textMuted),
        ),
        const SizedBox(height: Insets.card),

        // Token en monoespaciado, seleccionable, sobre un tile sage tenue.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Insets.card),
          decoration: ShapeDecoration(
            color: c.brandPrimary.withValues(alpha: 0.10),
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.card),
            ),
          ),
          child: SelectableText(
            invite.inviteToken,
            style: AppText.body(c.textPrimary).copyWith(
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: Insets.card),

        Text(
          'Expira el $expires · rol: ${invite.role.label}',
          style: AppText.caption(c.textMuted),
        ),

        const SizedBox(height: Insets.cardLg),
        MCPrimaryButton(
          label: 'Copiar código',
          icon: LucideIcons.copy,
          onPressed: () => _copy(invite.inviteToken),
        ),
        const SizedBox(height: Insets.md),
        MCSecondaryButton(
          label: 'Listo',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  /// Fecha local corta `dd/mm/aaaa` (sin sumar `intl`; mismo criterio que el
  /// resto de las pantallas de feature porteadas).
  String _formatDate(DateTime d) {
    final DateTime local = d.toLocal();
    final String dd = local.day.toString().padLeft(2, '0');
    final String mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }
}

// ─────────────────────────────── Role picker ───────────────────────────────

/// Selector de rol con chips (admin/member/viewer). Debajo, un hint del rol
/// elegido (espejo del `roleHint` de iOS).
class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.value,
    required this.roles,
    required this.onChanged,
    required this.enabled,
  });

  final MemberRole value;
  final List<MemberRole> roles;
  final ValueChanged<MemberRole> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ROL', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        Wrap(
          spacing: Insets.md,
          runSpacing: Insets.md,
          children: roles.map((MemberRole r) {
            return MCChip(
              label: r.label,
              selected: r == value,
              onTap: enabled ? () => onChanged(r) : () {},
            );
          }).toList(),
        ),
        const SizedBox(height: Insets.md),
        Text(_roleHint(value), style: AppText.caption(c.textMuted)),
      ],
    );
  }

  /// Descripción del alcance de cada rol (espejo de los `role.hint.*` de iOS).
  static String _roleHint(MemberRole role) => switch (role) {
        MemberRole.owner => 'Control total del hogar.',
        MemberRole.admin =>
          'Puede gestionar miembros, cuentas y movimientos del hogar.',
        MemberRole.member => 'Puede agregar y editar movimientos del hogar.',
        MemberRole.viewer => 'Solo puede ver; no edita nada.',
      };
}

// ─────────────────────────────── Message card ──────────────────────────────

/// Card de mensaje inline (mismo look que el alta de cuenta/hogar y auth).
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.card),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: SmoothRectangleBorder(
          borderRadius: Radii.smooth(Radii.card),
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 1),
        ),
      ),
      child: Text(message, style: AppText.caption(color)),
    );
  }
}
