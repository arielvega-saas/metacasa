import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/supabase_init.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/household_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../../../state/app_state.dart';
import '../../auth/presentation/auth_field.dart';
import 'household_members_screen.dart';
import 'invite_member_sheet.dart';

/// Pantalla "Editar hogar" — espejo de `HouseholdSettingsView` (iOS).
///
/// Entry-point de `/more/household` (lo cablea el lead en el router). Permite:
///   - editar el nombre (→ `rename`),
///   - cambiar la moneda base (→ `setCurrency`),
///   - navegar a Miembros e Invitar (push interno / sheet),
///   - eliminar el hogar **solo si `household.createdBy == currentUser.id`**
///     (diálogo de confirmación → `delete` → refresh del gate → pop).
///
/// Mientras carga el hogar muestra un skeleton; los cambios refrescan
/// `currentHouseholdProvider` (invalidate) para que el resto de la app vea el
/// dato nuevo, y el gate raíz se re-evalúa tras borrar.
class HouseholdSettingsScreen extends ConsumerWidget {
  const HouseholdSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<Household?> async = ref.watch(currentHouseholdProvider);

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text('Hogar', style: AppText.h2(c.textPrimary)),
      ),
      body: async.when(
        loading: () => const _SettingsSkeleton(),
        error: (Object err, StackTrace _) => _ErrorState(
          onRetry: () => ref.invalidate(currentHouseholdProvider),
        ),
        data: (Household? household) {
          if (household == null) {
            return const _ErrorState.noHousehold();
          }
          return _SettingsBody(household: household);
        },
      ),
    );
  }
}

/// Cuerpo editable. Stateful por los `TextEditingController` del nombre y el
/// estado local de moneda / loading / error.
class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody({required this.household});

  final Household household;

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late final TextEditingController _name;
  late String _currency;

  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.household.name)
      ..addListener(_onChanged);
    _currency = widget.household.defaultCurrency;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Soy el dueño del hogar (único que puede borrarlo). Comparación directa
  /// `createdBy == currentUser.id`, igual que el `currentRole == .owner` de iOS.
  bool get _isOwner =>
      widget.household.createdBy == supabase.auth.currentUser?.id;

  /// Hay cambios sin guardar (nombre o moneda distintos del hogar actual).
  bool get _hasChanges {
    final String trimmed = _name.text.trim();
    return (trimmed.isNotEmpty && trimmed != widget.household.name) ||
        _currency != widget.household.defaultCurrency;
  }

  bool get _busy => _saving || _deleting;

  Future<void> _save() async {
    if (_busy || !_hasChanges) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    final HouseholdRepository repo = ref.read(householdRepositoryProvider);
    final String id = widget.household.id;
    try {
      final String trimmed = _name.text.trim();
      if (trimmed.isNotEmpty && trimmed != widget.household.name) {
        await repo.rename(id, trimmed);
      }
      if (_currency != widget.household.defaultCurrency) {
        await repo.setCurrency(id, _currency);
      }
      // Refrescamos el hogar activo para que toda la app (header, montos) tome
      // el dato nuevo. El gate no cambia (seguimos en `ready`).
      ref.invalidate(currentHouseholdProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron guardar los cambios.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final c = context.colors;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: c.appSurface,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
        title: Text('¿Eliminar hogar?', style: AppText.h2(c.textPrimary)),
        content: Text(
          'Se eliminan el hogar, sus miembros, categorías, cuentas, '
          'movimientos, presupuestos y metas. Es irreversible.',
          style: AppText.body(c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: AppText.body(c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Eliminar todo',
              style: AppText.body(c.brandDanger)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _delete();
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(householdRepositoryProvider).delete(widget.household.id);
      // El hogar ya no existe: re-evaluamos el gate (→ noHousehold si era el
      // único) e invalidamos el provider del hogar activo.
      ref.invalidate(currentHouseholdProvider);
      await ref.read(appGateProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = 'No se pudo eliminar el hogar. Probá de nuevo.';
        });
      }
    }
  }

  Future<void> _openMembers() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HouseholdMembersScreen(),
      ),
    );
  }

  Future<void> _openInvite() async {
    HapticFeedback.mediumImpact();
    await InviteMemberSheet.show(context, widget.household.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120, // espacio para el FAB del asistente del shell
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Datos del hogar ──
          Text('DATOS DEL HOGAR', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.card),
          MCCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: 'Nombre',
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  enabled: !_busy,
                ),
                const SizedBox(height: Insets.section),
                _CurrencyDropdown(
                  value: _currency,
                  enabled: !_busy,
                  onChanged: (String v) => setState(() => _currency = v),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: Insets.section),
            _MessageCard(message: _error!, color: c.brandDanger),
          ],

          const SizedBox(height: Insets.cardLg),
          MCPrimaryButton(
            label: _saving ? 'Guardando…' : 'Guardar cambios',
            onPressed: (_busy || !_hasChanges) ? null : _save,
          ),

          const SizedBox(height: Insets.xxl),

          // ── Gestión ──
          Text('GESTIÓN', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.card),
          _NavRow(
            icon: LucideIcons.users,
            label: 'Miembros',
            onTap: _busy ? null : _openMembers,
          ),
          const SizedBox(height: Insets.md),
          _NavRow(
            icon: LucideIcons.userPlus,
            label: 'Invitar',
            onTap: _busy ? null : _openInvite,
          ),

          // ── Zona peligrosa (solo dueño) ──
          if (_isOwner) ...[
            const SizedBox(height: Insets.xxl),
            Text('ZONA PELIGROSA', style: AppText.label(c.brandDanger)),
            const SizedBox(height: Insets.card),
            _DangerRow(
              label: _deleting ? 'Eliminando…' : 'Eliminar hogar',
              onTap: _busy ? null : _confirmDelete,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── Filas de navegación ───────────────────────

/// Fila navegable (Miembros / Invitar): card con ícono sage + label + chevron.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: MCCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.cardLg,
          vertical: Insets.card,
        ),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.brandPrimary),
            const SizedBox(width: Insets.card),
            Expanded(
              child: Text(label, style: AppText.body(c.textPrimary)),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textDim),
          ],
        ),
      ),
    );
  }
}

/// Fila destructiva (eliminar hogar): ícono + label en coral, sin chevron.
class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: MCCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.cardLg,
          vertical: Insets.card,
        ),
        onTap: onTap,
        child: Row(
          children: [
            Icon(LucideIcons.trash2, size: 20, color: c.brandDanger),
            const SizedBox(width: Insets.card),
            Expanded(
              child: Text(
                label,
                style: AppText.body(c.brandDanger)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Currency dropdown ─────────────────────────

/// Dropdown de moneda base — mismo catálogo/recipe que el alta de cuenta. El
/// valor activo siempre figura entre las opciones (evita el assert de
/// `DropdownButton` si el hogar usa una moneda fuera del catálogo core).
class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  static const List<String> _currencies = <String>[
    'USD',
    'EUR',
    'ARS',
    'BRL',
    'MXN',
    'CLP',
    'COP',
    'PEN',
    'UYU',
    'GBP',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final List<String> options = _currencies.contains(value)
        ? _currencies
        : <String>[value, ..._currencies];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MONEDA BASE', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.sm),
        Container(
          decoration: ShapeDecoration(
            color: c.appSurfaceInset,
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.input),
              side: BorderSide(color: c.appBorder, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: c.appSurface,
              borderRadius: BorderRadius.circular(Radii.card),
              style: AppText.body(c.textPrimary),
              icon: Icon(LucideIcons.chevronDown, color: c.textMuted),
              items: options
                  .map((String code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(code, style: AppText.body(c.textPrimary)),
                      ))
                  .toList(),
              onChanged: enabled ? (String? v) => onChanged(v ?? value) : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Message card ──────────────────────────────

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

// ─────────────────────────────── Estados ───────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry})
      : _noHousehold = false,
        super();

  const _ErrorState.noHousehold()
      : onRetry = null,
        _noHousehold = true;

  final VoidCallback? onRetry;
  final bool _noHousehold;

  @override
  Widget build(BuildContext context) {
    if (_noHousehold) {
      return const EmptyState(
        icon: LucideIcons.home,
        title: 'No hay un hogar activo',
        message: 'Creá o unite a un hogar para gestionarlo.',
      );
    }
    return EmptyState(
      icon: LucideIcons.cloudOff,
      title: 'No pudimos cargar el hogar',
      message: 'Revisá tu conexión y volvé a intentar.',
      actionLabel: 'Reintentar',
      onAction: onRetry,
    );
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120,
      ),
      children: [
        Container(
          height: 200,
          decoration: ShapeDecoration(
            color: c.appSurface,
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.card),
            ),
          ),
        ),
        const SizedBox(height: Insets.section),
        Container(
          height: 56,
          decoration: ShapeDecoration(
            color: c.appSurface,
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.card),
            ),
          ),
        ),
      ],
    );
  }
}
