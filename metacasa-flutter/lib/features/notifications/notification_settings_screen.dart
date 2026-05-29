import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';
import '../../shared/widgets/widgets.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';

/// Configuración de notificaciones locales — espejo de `NotificationSettingsView`
/// del iOS, en Midnight Sage.
///
/// Estructura:
///   • Permiso del sistema — estado actual + CTA "Permitir" (notDetermined) o
///     instrucción para destrabar en Ajustes (denied).
///   • Qué notificar — los 5 toggles master (bills/metas/recurrentes/envelope/
///     anomalías). Solo visibles si el permiso está concedido.
///   • Cuándo (vencimientos) — días antes + hora (steppers), si `bills` ON.
///   • Cuándo (metas) — día del mes (stepper), si `goals` ON.
///
/// El push lo arma el lead (router `/more/settings/notifications` o
/// `Navigator.push` desde la fila "Notificaciones" de Ajustes). Acá no se toca
/// el router.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationAuthStatus _auth = NotificationAuthStatus.notDetermined;
  bool _requesting = false;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  /// Inicializa el servicio (idempotente) y refresca el estado de autorización.
  Future<void> _refreshStatus() async {
    final NotificationService svc = ref.read(notificationServiceProvider);
    await svc.init();
    final NotificationAuthStatus status = await svc.authorizationState();
    if (!mounted) return;
    setState(() {
      _auth = status;
      _loadingStatus = false;
    });
  }

  /// Pide permiso (POST_NOTIFICATIONS + exact-alarm) y, si quedó concedido,
  /// re-sincroniza los recordatorios de los bills pendientes.
  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    HapticFeedback.selectionClick();
    final NotificationService svc = ref.read(notificationServiceProvider);
    await svc.requestPermission();
    final NotificationAuthStatus status = await svc.authorizationState();
    if (!mounted) return;
    setState(() {
      _auth = status;
      _requesting = false;
    });
    // Si recién ahora autorizó, el resync de los bills pendientes lo dispara el
    // `bills_controller.dart` (al reconstruirse / en su próxima carga). No
    // importamos el controller acá para no acoplar features.
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final NotificationPreferences prefs =
        ref.watch(notificationPreferencesProvider);
    final NotificationPreferencesNotifier prefsCtrl =
        ref.read(notificationPreferencesProvider.notifier);
    final bool granted = _auth == NotificationAuthStatus.authorized;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        title:
            Text('Notificaciones', style: AppText.serifInline(c.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.screen,
          Insets.md,
          Insets.screen,
          Insets.xxl,
        ),
        children: [
          _PermissionCard(
            status: _auth,
            loading: _loadingStatus,
            requesting: _requesting,
            onRequest: _requestPermission,
            onOpenSettings: _showOpenSettingsHint,
          ),
          if (granted) ...[
            const SizedBox(height: Insets.section),
            _SectionCard(
              title: 'Qué notificar',
              footer:
                  'Las alertas de presupuesto se disparan al pasar 80 %, 100 % y 120 % del límite por categoría. Las de movimientos atípicos detectan cargos duplicados y montos inusuales.',
              rows: [
                _ToggleRow(
                  icon: LucideIcons.calendarClock,
                  label: 'Vencimientos',
                  value: prefs.bills,
                  onChanged: prefsCtrl.setBills,
                ),
                _ToggleRow(
                  icon: LucideIcons.target,
                  label: 'Metas',
                  value: prefs.goals,
                  onChanged: prefsCtrl.setGoals,
                ),
                _ToggleRow(
                  icon: LucideIcons.repeat,
                  label: 'Movimientos recurrentes',
                  value: prefs.recurring,
                  onChanged: prefsCtrl.setRecurring,
                ),
                _ToggleRow(
                  icon: LucideIcons.pieChart,
                  label: 'Presupuesto excedido',
                  value: prefs.envelopeOverspend,
                  onChanged: prefsCtrl.setEnvelopeOverspend,
                ),
                _ToggleRow(
                  icon: LucideIcons.shieldAlert,
                  label: 'Movimientos atípicos',
                  value: prefs.anomalies,
                  onChanged: prefsCtrl.setAnomalies,
                ),
              ],
            ),
            if (prefs.bills) ...[
              const SizedBox(height: Insets.section),
              _SectionCard(
                title: 'Vencimientos · cuándo',
                footer:
                    'Te avisamos ${_daysHint(prefs.billsDaysBefore)} a las ${_hh(prefs.billsHour)}, el día del vencimiento a las 18:00 y al día siguiente si sigue impago.',
                rows: [
                  _StepperRow(
                    icon: LucideIcons.calendarDays,
                    label: 'Días antes',
                    value: _daysHint(prefs.billsDaysBefore),
                    onDecrement: prefs.billsDaysBefore > 1
                        ? () => prefsCtrl
                            .setBillsDaysBefore(prefs.billsDaysBefore - 1)
                        : null,
                    onIncrement: prefs.billsDaysBefore < 7
                        ? () => prefsCtrl
                            .setBillsDaysBefore(prefs.billsDaysBefore + 1)
                        : null,
                  ),
                  _StepperRow(
                    icon: LucideIcons.clock,
                    label: 'Hora del aviso',
                    value: _hh(prefs.billsHour),
                    onDecrement: prefs.billsHour > 0
                        ? () => prefsCtrl.setBillsHour(prefs.billsHour - 1)
                        : null,
                    onIncrement: prefs.billsHour < 23
                        ? () => prefsCtrl.setBillsHour(prefs.billsHour + 1)
                        : null,
                  ),
                ],
              ),
            ],
            if (prefs.goals) ...[
              const SizedBox(height: Insets.section),
              _SectionCard(
                title: 'Metas · cuándo',
                footer:
                    'Recordatorio mensual el día ${prefs.goalsMonthlyDay} de cada mes a las 10:00.',
                rows: [
                  _StepperRow(
                    icon: LucideIcons.calendarCheck,
                    label: 'Día del mes',
                    value: 'Día ${prefs.goalsMonthlyDay}',
                    onDecrement: prefs.goalsMonthlyDay > 1
                        ? () => prefsCtrl
                            .setGoalsMonthlyDay(prefs.goalsMonthlyDay - 1)
                        : null,
                    onIncrement: prefs.goalsMonthlyDay < 28
                        ? () => prefsCtrl
                            .setGoalsMonthlyDay(prefs.goalsMonthlyDay + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// En Android no hay un esquema URL universal para abrir la pantalla de
  /// notificaciones del app (a diferencia del `app-settings:` de iOS). En vez de
  /// `url_launcher` (que no resuelve ese deep-link), reintentamos el prompt del
  /// sistema y, si sigue denegado, instruimos al usuario.
  Future<void> _showOpenSettingsHint() async {
    HapticFeedback.selectionClick();
    // Reintento del prompt: si el usuario solo lo había pospuesto, esto alcanza.
    await _requestPermission();
    if (!mounted) return;
    if (_auth != NotificationAuthStatus.authorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Activá las notificaciones desde Ajustes del sistema → Apps → Home Finance → Notificaciones.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  /// "1 día antes" / "N días antes".
  static String _daysHint(int days) =>
      days == 1 ? '1 día antes' : '$days días antes';

  /// "HH:00".
  static String _hh(int hour) => '${hour.toString().padLeft(2, '0')}:00';
}

// ─────────────────────────────── Permission card ───────────────────────────

/// Card de estado del permiso del sistema + CTA contextual.
class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.status,
    required this.loading,
    required this.requesting,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final NotificationAuthStatus status;
  final bool loading;
  final bool requesting;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (IconData icon, String label, Color color) = switch (status) {
      NotificationAuthStatus.authorized => (
          LucideIcons.bellRing,
          'Activadas',
          c.brandSuccess,
        ),
      NotificationAuthStatus.denied => (
          LucideIcons.bellOff,
          'Desactivadas',
          c.brandDanger,
        ),
      NotificationAuthStatus.notDetermined => (
          LucideIcons.bell,
          loading ? '…' : 'Sin configurar',
          c.brandWarning,
        ),
    };

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: Insets.card),
              Expanded(
                child: Text('Permiso del sistema',
                    style: AppText.body(c.textPrimary)),
              ),
              Text(
                label,
                style: AppText.caption(color)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            _hint(status),
            style: AppText.caption(c.textMuted),
          ),
          if (!loading && status == NotificationAuthStatus.notDetermined) ...[
            const SizedBox(height: Insets.cardLg),
            requesting
                ? _BusyButton(label: 'Pidiendo permiso…')
                : MCPrimaryButton(
                    label: 'Permitir',
                    icon: LucideIcons.bellRing,
                    onPressed: onRequest,
                  ),
          ] else if (status == NotificationAuthStatus.denied) ...[
            const SizedBox(height: Insets.cardLg),
            requesting
                ? _BusyButton(label: 'Reintentando…')
                : MCSecondaryButton(
                    label: 'Abrir Ajustes',
                    icon: LucideIcons.settings,
                    onPressed: onOpenSettings,
                  ),
          ],
        ],
      ),
    );
  }

  static String _hint(NotificationAuthStatus status) => switch (status) {
        NotificationAuthStatus.authorized =>
          'Vas a recibir recordatorios de tus vencimientos en este dispositivo.',
        NotificationAuthStatus.denied =>
          'Las notificaciones están desactivadas. Activalas para recibir recordatorios de vencimientos.',
        NotificationAuthStatus.notDetermined =>
          'Permití las notificaciones para que te avisemos de tus vencimientos a tiempo.',
      };
}

/// Botón "ocupado" (no interactivo) con spinner — espejo del estado `isRequesting`
/// del iOS. Mantiene la silueta del primario para que el layout no salte.
class _BusyButton extends StatelessWidget {
  const _BusyButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: 0.7,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 54),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: c.brandPrimary,
          shape:
              SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.button)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0E1312)),
              ),
            ),
            const SizedBox(width: Insets.md),
            Text(
              label,
              style: AppText.body(const Color(0xFF0E1312))
                  .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Section card ──────────────────────────────

/// Card squircle insetGrouped con título uppercase + filas + footer opcional.
/// Mismo recipe que `settings_screen.dart`.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows, this.footer});

  final String title;
  final List<Widget> rows;
  final String? footer;

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
            shape:
                SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
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
        if (footer != null) ...[
          const SizedBox(height: Insets.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
            child: Text(footer!, style: AppText.caption(c.textDim)),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────── Rows ──────────────────────────────────────

/// Fila con Switch (icon teñido + label + Switch). Estilo idéntico al de
/// `settings_screen.dart`.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
            child: Icon(icon, size: 20, color: c.brandPrimary),
          ),
          const SizedBox(width: Insets.card),
          Expanded(child: Text(label, style: AppText.body(c.textPrimary))),
          Switch(
            value: value,
            onChanged: (bool v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeColor: const Color(0xFF0E1312),
            activeTrackColor: c.brandPrimary,
            inactiveThumbColor: c.textMuted,
            inactiveTrackColor: c.appSurfaceInset,
          ),
        ],
      ),
    );
  }
}

/// Fila con stepper −/valor/+ (icon + label + control). Botones se atenúan en el
/// borde del rango (callback null = disabled).
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.cardLg,
        vertical: Insets.md,
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: c.brandPrimary),
          ),
          const SizedBox(width: Insets.card),
          Expanded(child: Text(label, style: AppText.body(c.textPrimary))),
          _StepButton(icon: LucideIcons.minus, onTap: onDecrement),
          Container(
            constraints: const BoxConstraints(minWidth: 92),
            alignment: Alignment.center,
            child: Text(
              value,
              style: AppText.body(c.brandPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          _StepButton(icon: LucideIcons.plus, onTap: onIncrement),
        ],
      ),
    );
  }
}

/// Botón circular −/+ del stepper. `onTap == null` ⇒ atenuado (límite del rango).
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.appSurfaceInset,
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.pill),
              side: BorderSide(color: c.appBorder, width: 1),
            ),
          ),
          child: Icon(icon, size: 16, color: c.textPrimary),
        ),
      ),
    );
  }
}
