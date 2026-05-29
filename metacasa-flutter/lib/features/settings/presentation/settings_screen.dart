import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/supabase_init.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../state/app_providers.dart';
import '../../../state/app_state.dart';
import 'appearance_settings.dart';
import 'delete_account_screen.dart';
import 'fx_rates_screen.dart';
import 'language_settings.dart';
import 'manage_categories_screen.dart';

/// Versión visible de la app. No tenemos `package_info_plus` entre las deps, así
/// que la clavamos acá (espejo de `Config.appVersion` de iOS, que la lee del
/// bundle). TODO: cuando se sume `package_info_plus`, leerla del paquete.
const String _kAppVersion = '1.0.0';

/// URLs públicas de marca (mismas que la PWA / iOS).
const String _kPrivacyUrl = 'https://metacasa.app/privacy';
const String _kTermsUrl = 'https://metacasa.app/terms';
const String _kSiteUrl = 'https://metacasa.app';

/// Pantalla de Ajustes — espejo de `SettingsView` de iOS, reorganizada en los
/// 4 grupos pedidos por el equipo Flutter:
///   • General  — Apariencia · Idioma · Privacidad (toggle + biometría)
///   • Finanzas — Categorías · Monedas y cambio (FX)
///   • Cuenta   — Cerrar sesión · Eliminar cuenta
///   • Acerca de — versión · Política de privacidad / Términos · sitio
///
/// Cada grupo es una card squircle insetGrouped con filas (icon teñido + label
/// + trailing), al mismo recipe que `more_screen.dart`.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final bool privacy = ref.watch(privacyModeProvider);
    final String? email =
        supabaseReady ? supabase.auth.currentUser?.email : null;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        title: Text('Ajustes', style: AppText.serifInline(c.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.screen,
          Insets.md,
          Insets.screen,
          Insets.xxl,
        ),
        children: [
          // ── General ──────────────────────────────────────────────────
          _SectionCard(
            title: 'General',
            rows: [
              _SettingsRow(
                icon: LucideIcons.moonStar,
                label: 'Apariencia',
                onTap: () => _push(context, const AppearanceSettingsScreen()),
              ),
              _SettingsRow(
                icon: LucideIcons.globe,
                label: 'Idioma',
                onTap: () => _push(context, const LanguageSettingsScreen()),
              ),
              _SettingsRow.toggle(
                icon: privacy ? LucideIcons.eyeOff : LucideIcons.eye,
                label: 'Modo privacidad',
                value: privacy,
                onChanged: (bool v) {
                  HapticFeedback.selectionClick();
                  ref.read(privacyModeProvider.notifier).state = v;
                },
              ),
              const _BiometricsRow(),
            ],
          ),
          const SizedBox(height: Insets.section),

          // ── Finanzas ─────────────────────────────────────────────────
          _SectionCard(
            title: 'Finanzas',
            rows: [
              _SettingsRow(
                icon: LucideIcons.tag,
                label: 'Categorías',
                onTap: () => _push(context, const ManageCategoriesScreen()),
              ),
              _SettingsRow(
                icon: LucideIcons.dollarSign,
                label: 'Monedas y cambio',
                onTap: () => _push(context, const FxRatesScreen()),
              ),
              // Diferidos (Fase 7): export/backup. Fila inerte con badge.
              const _SettingsRow(
                icon: LucideIcons.download,
                label: 'Backup y exportar',
                trailingLabel: 'Próximamente',
                enabled: false,
              ),
            ],
          ),
          const SizedBox(height: Insets.section),

          // ── Cuenta ───────────────────────────────────────────────────
          _SectionCard(
            title: 'Cuenta',
            rows: [
              // Diferido (Fase 7): preferencias de notificaciones.
              const _SettingsRow(
                icon: LucideIcons.bell,
                label: 'Notificaciones',
                trailingLabel: 'Próximamente',
                enabled: false,
              ),
              // Diferido (Fase 6): consentimiento de privacidad del Asistente IA.
              const _SettingsRow(
                icon: LucideIcons.sparkles,
                label: 'Privacidad del Asistente IA',
                trailingLabel: 'Próximamente',
                enabled: false,
              ),
              _SettingsRow(
                icon: LucideIcons.logOut,
                label: 'Cerrar sesión',
                destructive: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
              _SettingsRow(
                icon: LucideIcons.trash2,
                label: 'Eliminar cuenta',
                destructive: true,
                onTap: () => _push(context, const DeleteAccountScreen()),
              ),
            ],
          ),
          const SizedBox(height: Insets.section),

          // ── Acerca de ────────────────────────────────────────────────
          _SectionCard(
            title: 'Acerca de',
            rows: [
              _SettingsRow(
                icon: LucideIcons.shield,
                label: 'Política de privacidad',
                external: true,
                onTap: () => _openUrl(context, _kPrivacyUrl),
              ),
              _SettingsRow(
                icon: LucideIcons.fileText,
                label: 'Términos de uso',
                external: true,
                onTap: () => _openUrl(context, _kTermsUrl),
              ),
              _SettingsRow(
                icon: LucideIcons.externalLink,
                label: 'metacasa.app',
                external: true,
                onTap: () => _openUrl(context, _kSiteUrl),
              ),
            ],
          ),

          // ── Footer (email + versión) ─────────────────────────────────
          const SizedBox(height: Insets.xxl),
          if (email != null && email.isNotEmpty)
            Center(
              child: Text(email, style: AppText.caption(c.textDim)),
            ),
          const SizedBox(height: Insets.md),
          Center(
            child: Text('Home Finance v$_kAppVersion',
                style: AppText.caption(c.textDim)),
          ),
        ],
      ),
    );
  }

  /// Push interno (no toca el router; usa el Navigator de la rama "Más").
  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  /// Confirmación de cierre de sesión → `appGate.signOut()` (el gate re-evalúa y
  /// vuelve al login). Espejo del `confirmationDialog` de iOS.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final c = context.colors;
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      builder: (BuildContext sheetCtx) => _SignOutConfirmSheet(),
    );
    if (confirmed ?? false) {
      await ref.read(appGateProvider.notifier).signOut();
    }
  }

  /// Abre una URL externa en el navegador. Si falla, muestra un SnackBar.
  Future<void> _openUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }
}

// ─────────────────────────────── Confirm sheet ─────────────────────────────

/// Hoja de confirmación de cierre de sesión.
class _SignOutConfirmSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.cardLg,
          Insets.md,
          Insets.cardLg,
          Insets.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Cerrar sesión?', style: AppText.h2(c.textPrimary)),
            const SizedBox(height: Insets.sm),
            Text(
              'Vas a tener que volver a iniciar sesión para acceder a tus datos.',
              style: AppText.body(c.textMuted),
            ),
            const SizedBox(height: Insets.section),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(true),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: c.brandDanger,
                  shape: SmoothRectangleBorder(
                    borderRadius: Radii.smooth(Radii.button),
                  ),
                ),
                child: Text(
                  'Cerrar sesión',
                  style: AppText.body(const Color(0xFF0E1312))
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar', style: AppText.body(c.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Section card ──────────────────────────────

/// Card squircle insetGrouped con título uppercase + filas (mismo recipe que
/// `more_screen.dart`).
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.md),
          child: Text(title.toUpperCase(), style: AppText.label(c.textMuted)),
        ),
        ClipPath(
          clipper: ShapeBorderClipper(
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.card),
            ),
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: c.appSurface,
              shape: SmoothRectangleBorder(
                borderRadius: Radii.smooth(Radii.card),
                side: BorderSide(color: c.appBorder, width: 1),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i != rows.length - 1)
                    Divider(
                      color: c.appBorder,
                      height: 1,
                      thickness: 1,
                      indent: Insets.cardLg + 20 + Insets.card,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Settings row ──────────────────────────────

/// Fila de ajustes. Tres modos:
///   • Navegación/acción (default): icon + label + chevron (o link externo).
///   • Toggle (`_SettingsRow.toggle`): icon + label + Switch.
///   • Inerte (`enabled: false`): atenuada, con un badge trailing opcional
///     (para los diferidos "Próximamente").
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
    this.external = false,
    this.trailingLabel,
    this.enabled = true,
  })  : value = null,
        onChanged = null;

  const _SettingsRow.toggle({
    required this.icon,
    required this.label,
    required bool this.value,
    required ValueChanged<bool> this.onChanged,
  })  : onTap = null,
        destructive = false,
        external = false,
        trailingLabel = null,
        enabled = true;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  /// Si true, muestra el ícono de enlace externo en vez del chevron.
  final bool external;

  /// Texto trailing opcional (ej. badge "Próximamente" para diferidos).
  final String? trailingLabel;

  /// Si false, la fila se ve atenuada y no responde al tap.
  final bool enabled;

  /// Estado del toggle (solo en el constructor `.toggle`).
  final bool? value;
  final ValueChanged<bool>? onChanged;

  bool get _isToggle => value != null && onChanged != null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color accent = destructive ? c.brandDanger : c.brandPrimary;
    final Color textColor = destructive ? c.brandDanger : c.textPrimary;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.cardLg,
        vertical: Insets.card,
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Text(label, style: AppText.body(textColor)),
          ),
          if (trailingLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: 3),
              decoration: ShapeDecoration(
                color: c.appSurfaceInset,
                shape: const StadiumBorder(),
              ),
              child: Text(trailingLabel!, style: AppText.caption(c.textMuted)),
            ),
          ] else if (_isToggle) ...[
            Switch(
              value: value!,
              onChanged: onChanged,
              activeColor: const Color(0xFF0E1312),
              activeTrackColor: c.brandPrimary,
              inactiveThumbColor: c.textMuted,
              inactiveTrackColor: c.appSurfaceInset,
            ),
          ] else if (external) ...[
            Icon(LucideIcons.arrowUpRight, size: 16, color: c.textDim),
          ] else ...[
            Icon(LucideIcons.chevronRight, size: 18, color: c.textDim),
          ],
        ],
      ),
    );

    if (_isToggle) return content;
    if (!enabled) return Opacity(opacity: 0.5, child: content);

    return InkWell(onTap: onTap, child: content);
  }
}

// ─────────────────────────────── Biometrics row ────────────────────────────

/// Fila de estado de biometría (display-only) — espejo de `BiometricsStatusRow`
/// de iOS. Consulta `BiometricService.isAvailable()` y muestra el estado.
class _BiometricsRow extends ConsumerWidget {
  const _BiometricsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<bool> available = ref.watch(_biometricsAvailableProvider);
    final String status = available.maybeWhen(
      data: (bool ok) => ok ? 'Disponible' : 'No disponible',
      orElse: () => '…',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.cardLg,
        vertical: Insets.card,
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            alignment: Alignment.center,
            child:
                Icon(LucideIcons.fingerprint, size: 20, color: c.brandPrimary),
          ),
          const SizedBox(width: Insets.card),
          Expanded(
            child:
                Text('Bloqueo biométrico', style: AppText.body(c.textPrimary)),
          ),
          Text(status, style: AppText.caption(c.textMuted)),
        ],
      ),
    );
  }
}

/// Provider one-shot del estado de disponibilidad de biometría del device.
final _biometricsAvailableProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(biometricServiceProvider).isAvailable(),
);
