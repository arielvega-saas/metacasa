import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/edge/account_deletion_client.dart';
import '../../../state/app_state.dart';

/// Pantalla de eliminación de cuenta — requerida por App Store Review 5.1.1(v)
/// y por Google Play. Espejo de `DeleteAccountView` de iOS. Flujo de dos pasos:
///   1. Explicación con consecuencias (lista de lo que se pierde).
///   2. Confirmación tipeando la palabra "ELIMINAR" (anti borrado accidental).
///
/// En éxito: `accountDeletionClient.deleteAccount()` (Edge Function con
/// service_role) → `appGate.signOut()` para limpiar el estado local; el gate
/// re-evalúa y la app vuelve sola al login.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

enum _Step { explain, confirm }

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const String _requiredWord = 'ELIMINAR';

  final TextEditingController _confirmCtrl = TextEditingController();
  _Step _step = _Step.explain;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _matches => _confirmCtrl.text.trim() == _requiredWord;

  Future<void> _performDelete() async {
    if (_deleting || !_matches) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(accountDeletionClientProvider).deleteAccount();
      HapticFeedback.heavyImpact();
      // Limpia la sesión local; el gate re-evalúa → vuelve al login. El router
      // saca esta pantalla del stack al cambiar el subtree raíz.
      await ref.read(appGateProvider.notifier).signOut();
    } on AccountDeletionException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo eliminar la cuenta. Revisá tu conexión e intentá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        title: Text('Eliminar cuenta', style: AppText.h2(c.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Insets.cardLg,
            Insets.cardLg,
            Insets.cardLg,
            Insets.xxl,
          ),
          child: Column(
            children: [
              _IconHeader(),
              const SizedBox(height: Insets.xxl),
              if (_step == _Step.explain)
                _ExplainContent(
                  onContinue: () {
                    HapticFeedback.heavyImpact();
                    setState(() => _step = _Step.confirm);
                  },
                )
              else
                _ConfirmContent(
                  controller: _confirmCtrl,
                  requiredWord: _requiredWord,
                  matches: _matches,
                  deleting: _deleting,
                  onDelete: _performDelete,
                  onBack: _deleting
                      ? null
                      : () {
                          _confirmCtrl.clear();
                          setState(() => _step = _Step.explain);
                        },
                ),
              if (_error != null) ...[
                const SizedBox(height: Insets.section),
                _MessageCard(message: _error!, color: c.brandDanger),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: c.brandDanger.withValues(alpha: 0.18),
        shape: const CircleBorder(),
      ),
      child: Icon(LucideIcons.alertTriangle, size: 34, color: c.brandDanger),
    );
  }
}

class _ExplainContent extends StatelessWidget {
  const _ExplainContent({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Esta acción es permanente',
          style: AppText.serifTitle(c.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.section),
        Text(
          'Si eliminás tu cuenta, vas a perder el acceso a:',
          style: AppText.body(c.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.section),
        Container(
          padding: const EdgeInsets.all(Insets.cardLg),
          decoration: ShapeDecoration(
            color: c.appSurface,
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.card),
              side: BorderSide(color: c.appBorder, width: 1),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bullet('Tu perfil y datos de inicio de sesión.'),
              SizedBox(height: Insets.card),
              _Bullet(
                'Tu membresía en todos los hogares compartidos. Si sos el único '
                'miembro de un hogar, sus datos quedan inaccesibles.',
              ),
              SizedBox(height: Insets.card),
              _Bullet('El historial del Asistente IA guardado en tu cuenta.'),
              SizedBox(height: Insets.card),
              _Bullet(
                'Cualquier suscripción activa (gestionala desde la tienda de '
                'apps de tu dispositivo).',
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.section),
        Text(
          'No vamos a poder recuperar tu cuenta una vez que confirmes.',
          style: AppText.caption(c.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.xxl),
        _DangerButton(
          label: 'Continuar',
          icon: LucideIcons.arrowRightCircle,
          enabled: true,
          onPressed: onContinue,
        ),
      ],
    );
  }
}

class _ConfirmContent extends StatelessWidget {
  const _ConfirmContent({
    required this.controller,
    required this.requiredWord,
    required this.matches,
    required this.deleting,
    required this.onDelete,
    required this.onBack,
  });

  final TextEditingController controller;
  final String requiredWord;
  final bool matches;
  final bool deleting;
  final VoidCallback onDelete;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirmación final',
          style: AppText.serifTitle(c.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.section),
        Text.rich(
          TextSpan(
            style: AppText.body(c.textMuted),
            children: [
              const TextSpan(
                  text: 'Para confirmar la eliminación, escribí la palabra '),
              TextSpan(
                text: requiredWord,
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: ' abajo:'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.section),
        Container(
          decoration: ShapeDecoration(
            color: c.appSurface,
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.input),
              side: BorderSide(
                color: matches ? c.brandDanger : c.appBorder,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
          child: TextField(
            controller: controller,
            enabled: !deleting,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            style: AppText.body(c.textPrimary).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: requiredWord,
              hintStyle: AppText.body(c.textDim),
            ),
          ),
        ),
        const SizedBox(height: Insets.xxl),
        _DangerButton(
          label: deleting ? 'Eliminando…' : 'Eliminar cuenta permanentemente',
          icon: LucideIcons.trash2,
          loading: deleting,
          enabled: matches && !deleting,
          onPressed: onDelete,
        ),
        const SizedBox(height: Insets.md),
        TextButton(
          onPressed: onBack,
          child: Text('Volver', style: AppText.body(c.textMuted)),
        ),
      ],
    );
  }
}

/// Botón destructivo full-width (fill coral). No reusa `MCPrimaryButton` porque
/// ese va en sage; acá la semántica es peligro.
class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Insets.cardLg),
          decoration: ShapeDecoration(
            color: c.brandDanger,
            shape:
                SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.button)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0E1312),
                  ),
                )
              else
                Icon(icon, size: 18, color: const Color(0xFF0E1312)),
              const SizedBox(width: Insets.md),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(const Color(0xFF0E1312))
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            LucideIcons.xCircle,
            size: 16,
            color: c.brandDanger.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(child: Text(text, style: AppText.body(c.textPrimary))),
      ],
    );
  }
}

/// Card de mensaje inline (mismo look que `add_account_sheet`).
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
