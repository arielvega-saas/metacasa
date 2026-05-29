import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/widgets.dart';
import 'ai_consent_provider.dart';

/// URL pública de la Política de Privacidad (misma que usa el iOS y la pantalla
/// de Ajustes). Requisito de App Store / Play review para apps con IA en la nube.
const String _kPrivacyUrl = 'https://metacasa.app/privacy';

/// Hoja de consentimiento explícito del Asistente IA — espejo del
/// `AssistantConsentSheet` (iOS). Se muestra la PRIMERA vez que el usuario abre
/// el chat, antes de cualquier request a Claude.
///
/// **Por qué existe** (idéntico al iOS): Apple Review 5.1.1 (Data Collection) y
/// Google Play exigen consentimiento explícito antes de enviar datos del usuario
/// a terceros; GDPR/CCPA/LFPDPPP/LGPD piden base legal para procesar datos
/// financieros. Las fintech (Mercado Pago, Revolut, Nubank) lo hacen así.
///
/// **No descartable**: el usuario tiene que decidir (igual que
/// `.interactiveDismissDisabled()` del iOS). Lo modelamos con
/// `isDismissible: false` + `enableDrag: false` + `PopScope(canPop: false)`.
///
/// [show] devuelve `true` si aceptó (y persiste `pref_ai_consent=true` vía el
/// [aiConsentProvider]), `false` si canceló.
class AssistantConsentSheet extends ConsumerWidget {
  const AssistantConsentSheet({super.key});

  /// Presenta la hoja de consentimiento. Devuelve `true` ⇒ aceptó (consent
  /// persistido), `false`/`null` ⇒ canceló.
  static Future<bool?> show(BuildContext context) {
    final c = context.colors;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.appBackground,
      isScrollControlled: true,
      isDismissible: false, // Review: el user debe decidir explícitamente.
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => const AssistantConsentSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    // PopScope(canPop:false): bloquea el back de Android — el sheet solo se
    // cierra con una de las dos acciones (espejo del interactiveDismissDisabled).
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.xxl - Insets.md, // 24
            Insets.xxl,
            Insets.xxl - Insets.md,
            Insets.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(c),
                      const SizedBox(height: Insets.hero),
                      _bullets(c),
                      const SizedBox(height: Insets.hero),
                      _legalNote(context, c),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.hero),
              _actions(context, ref, c),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────── Header ──────────────────────────────────

  Widget _header(MidnightSageColors c) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.brandPrimary.withValues(alpha: 0.18),
          ),
          alignment: Alignment.center,
          child: Icon(LucideIcons.sparkles, size: 26, color: c.brandPrimary),
        ),
        const SizedBox(width: Insets.card),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título serif (editorial), igual que el `.mcSerifTitle` del iOS.
              Text('MetaCasa IA', style: AppText.serifTitle(c.textPrimary)),
              const SizedBox(height: Insets.xs),
              Text(
                'Antes de empezar, tu consentimiento',
                style: AppText.caption(c.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────── Bullets ─────────────────────────────────

  Widget _bullets(MidnightSageColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(
          c,
          icon: LucideIcons.brain,
          title: 'IA en la nube',
          body:
              'El asistente usa inteligencia artificial de Anthropic (Claude), '
              'a través de un proxy seguro nuestro. Las claves nunca viven en '
              'tu teléfono.',
        ),
        const SizedBox(height: Insets.section),
        _row(
          c,
          icon: LucideIcons.cloud,
          title: 'Qué se envía',
          body:
              'Tus mensajes y un resumen de tus finanzas (montos, categorías, '
              'saldos, metas). Solo lo necesario para responderte.',
        ),
        const SizedBox(height: Insets.section),
        _row(
          c,
          icon: LucideIcons.shieldCheck,
          title: 'Qué NUNCA se envía',
          body: 'Nunca enviamos tus contraseñas, tokens ni números de tarjeta. '
              'Anthropic no entrena sus modelos con tus datos.',
        ),
      ],
    );
  }

  Widget _row(
    MidnightSageColors c, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.brandPrimary.withValues(alpha: 0.12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: c.brandPrimary),
        ),
        const SizedBox(width: Insets.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Insets.xs),
              Text(body, style: AppText.caption(c.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────── Legal note ──────────────────────────────

  Widget _legalNote(BuildContext context, MidnightSageColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.card),
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.pill)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Tus derechos', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.md),
          Text(
            'Podés revocar el consentimiento desde Ajustes en cualquier '
            'momento. Tu uso del asistente queda sujeto a nuestra política.',
            style: AppText.caption(c.textDim),
          ),
          const SizedBox(height: Insets.lg),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openPrivacy(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Leer la Política de Privacidad',
                  style: AppText.caption(c.brandPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: Insets.xs),
                Icon(LucideIcons.arrowUpRight, size: 14, color: c.brandPrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────── Actions ─────────────────────────────────

  Widget _actions(BuildContext context, WidgetRef ref, MidnightSageColors c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MCPrimaryButton(
          label: 'Aceptar y continuar',
          onPressed: () async {
            HapticFeedback.mediumImpact();
            // Persistir consent ANTES de cerrar (no hay race: accept() setea el
            // estado en memoria sincrónicamente y persiste fire-and-forget).
            await ref.read(aiConsentProvider.notifier).accept();
            if (context.mounted) Navigator.of(context).pop(true);
          },
        ),
        const SizedBox(height: Insets.lg),
        MCSecondaryButton(
          label: 'Cancelar',
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }

  Future<void> _openPrivacy(BuildContext context) async {
    final Uri uri = Uri.parse(_kPrivacyUrl);
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }
}
