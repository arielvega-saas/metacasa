import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_state.dart';
import 'auth_field.dart';

/// Pantalla de acceso — espejo del `AuthFlowView` + `LoginView`/`SignupView` del
/// iOS. Togglea Login/Signup con un header de marca (wordmark serif), campos
/// estilizados, CTA primario, toggle secundario, "¿Olvidaste tu contraseña?"
/// (con diálogo de confirmación) y card de error/aviso inline.
class AuthFlowScreen extends ConsumerStatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  ConsumerState<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

enum _Mode { login, signup }

class _AuthFlowScreenState extends ConsumerState<AuthFlowScreen> {
  _Mode _mode = _Mode.login;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    // Habilitar/deshabilitar el CTA en vivo según el contenido de los campos.
    _email.addListener(_onChanged);
    _password.addListener(_onChanged);
    _confirm.addListener(_onChanged);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _switchMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _success = null;
    });
  }

  bool get _isSignup => _mode == _Mode.signup;

  /// Validez del formulario (igual criterio que iOS): login pide ambos campos;
  /// signup pide email con "@", pass >= 8 y confirmación coincidente.
  bool get _canSubmit {
    final email = _email.text.trim();
    final pass = _password.text;
    if (_isSignup) {
      return email.contains('@') && pass.length >= 8 && pass == _confirm.text;
    }
    return email.isNotEmpty && pass.isNotEmpty;
  }

  Future<void> _submit() async {
    if (_loading || !_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    final gate = ref.read(appGateProvider.notifier);
    try {
      if (_isSignup) {
        final result = await gate.signUp(
          email: _email.text,
          password: _password.text,
        );
        if (!mounted) return;
        if (result == AuthSignUpResult.emailConfirmationPending) {
          // No hay sesión todavía: mostramos el aviso y NO transicionamos.
          setState(() {
            _success =
                'Te enviamos un email a ${_email.text.trim()}. Confirmalo para ingresar.';
          });
        }
        // Si quedó `signedIn`, el gate transiciona solo (el router saca de acá).
      } else {
        await gate.signIn(email: _email.text, password: _password.text);
        // Transición la maneja el gate.
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Algo salió mal. Revisá tu conexión y volvé a intentar.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _promptReset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Ingresá tu email arriba primero.');
      return;
    }
    final confirmed = await _showResetDialog(email);
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        setState(() {
          _error = null;
          _success = 'Te enviamos un email a $email. Revisá tu bandeja.';
        });
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos enviar el email. Probá de nuevo.');
      }
    }
  }

  /// Diálogo de confirmación de reset — equivalente del `confirmationDialog`
  /// del iOS ("Enviar instrucciones de recuperación al email ingresado?").
  Future<bool?> _showResetDialog(String email) {
    final c = context.colors;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.appSurface,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
        title: Text('Recuperar contraseña', style: AppText.h2(c.textPrimary)),
        content: Text(
          'Te enviamos instrucciones de recuperación a $email.',
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
              'Enviar',
              style: AppText.body(c.brandPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.appBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.cardLg,
              vertical: Insets.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  _Header(isSignup: _isSignup),
                  const SizedBox(height: Insets.xxl),
                  _form(c),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(MidnightSageColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          enabled: !_loading,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: Insets.section),
        AuthPasswordField(
          label: _isSignup ? 'Contraseña (mínimo 8)' : 'Contraseña',
          controller: _password,
          autofillHints: const [AutofillHints.password],
          enabled: !_loading,
          textInputAction:
              _isSignup ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) => _isSignup ? null : _submit(),
        ),
        if (_isSignup) ...[
          const SizedBox(height: Insets.section),
          AuthPasswordField(
            label: 'Confirmá contraseña',
            controller: _confirm,
            enabled: !_loading,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: Insets.section),
          _MessageCard(message: _error!, color: c.brandDanger),
        ],
        if (_success != null) ...[
          const SizedBox(height: Insets.section),
          _MessageCard(message: _success!, color: c.brandSuccess),
        ],
        const SizedBox(height: Insets.cardLg),
        MCPrimaryButton(
          label: _loading
              ? (_isSignup ? 'Creando…' : 'Ingresando…')
              : (_isSignup ? 'Crear cuenta' : 'Iniciar sesión'),
          onPressed: (_loading || !_canSubmit) ? null : _submit,
        ),
        const SizedBox(height: Insets.section),
        _secondaryRow(c),
        if (_isSignup) ...[
          const SizedBox(height: Insets.cardLg),
          const _LegalText(),
        ],
      ],
    );
  }

  Widget _secondaryRow(MidnightSageColors c) {
    if (_isSignup) {
      return Center(
        child: _LinkButton(
          label: 'Ya tengo cuenta · Ingresar',
          color: c.brandPrimary,
          bold: true,
          onTap: _loading ? null : () => _switchMode(_Mode.login),
        ),
      );
    }
    // `Wrap` (no `Row`): si los dos links no entran en una línea angosta,
    // bajan a la siguiente en vez de overflowear.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Insets.cardLg,
      children: [
        _LinkButton(
          label: '¿Olvidaste tu contraseña?',
          color: c.textMuted,
          onTap: _loading ? null : _promptReset,
        ),
        _LinkButton(
          label: 'Crear cuenta',
          color: c.brandPrimary,
          bold: true,
          onTap: _loading ? null : () => _switchMode(_Mode.signup),
        ),
      ],
    );
  }
}

/// Header: wordmark serif "Home Finance" + subtítulo. (El iOS muestra el logo
/// + "auth.login.title/subtitle"; acá usamos el wordmark serif que ya define el
/// design system, igual que el splash, hasta tener el asset del logo.)
class _Header extends StatelessWidget {
  const _Header({required this.isSignup});

  final bool isSignup;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 84,
          height: 84,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(height: Insets.section),
        Text(
          'Home Finance',
          style: AppText.serifDisplay(c.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.xl),
        Text(
          isSignup
              ? 'Creá tu cuenta para empezar a ordenar la plata del hogar.'
              : 'Ordená la plata del hogar, juntos y sin vueltas.',
          style: AppText.body(c.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Card de mensaje inline (error coral / aviso sage). Fondo tenue del color +
/// borde del mismo color, texto legible.
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
      child: Text(
        message,
        style: AppText.caption(color),
      ),
    );
  }
}

/// Link de texto tappable con tap target accesible (>= 44dp de alto).
class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = AppText.caption(color)
        .copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w500);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          child: Center(widthFactor: 1, child: Text(label, style: style)),
        ),
      ),
    );
  }
}

/// URLs legales — Apple/Play exigen que Términos y Privacidad sean accesibles
/// y clickeables desde el signup. Espejo del markdown del `SignupView` del iOS.
const String _kTermsUrl = 'https://metacasa-app-cf592.web.app/terms.html';
const String _kPrivacyUrl = 'https://metacasa-app-cf592.web.app/privacy.html';

/// Texto legal con links tappables a Términos y Privacidad.
///
/// No usamos `url_launcher` a propósito: no está entre las deps directas del
/// proyecto (solo viene transitivo vía supabase_flutter). En su lugar, tocar un
/// link **copia la URL** al portapapeles y muestra un SnackBar — accesible y
/// sin sumar una dependencia no aprobada. (Cuando se agregue `url_launcher`
/// como dep directa, reemplazar `_open` por `launchUrl`.)
///
/// Stateful para crear/disponer los `TapGestureRecognizer` (si no, leakean).
class _LegalText extends StatefulWidget {
  const _LegalText();

  @override
  State<_LegalText> createState() => _LegalTextState();
}

class _LegalTextState extends State<_LegalText> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()..onTap = () => _open(_kTermsUrl);
    _privacy = TapGestureRecognizer()..onTap = () => _open(_kPrivacyUrl);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  void _open(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copiado: $url')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = AppText.caption(c.textDim);
    final link =
        AppText.caption(c.brandPrimary).copyWith(fontWeight: FontWeight.w600);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Al registrarte aceptás nuestros '),
          TextSpan(text: 'Términos', style: link, recognizer: _terms),
          const TextSpan(text: ' y la '),
          TextSpan(
            text: 'Política de Privacidad',
            style: link,
            recognizer: _privacy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
