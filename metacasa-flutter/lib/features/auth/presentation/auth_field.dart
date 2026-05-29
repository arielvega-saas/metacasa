import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';

/// Campo de texto estilizado Midnight Sage — espejo del `MCTextField` del iOS.
///
/// Label uppercase smallCaps (sage-muted) arriba, input sobre `appSurface` con
/// hairline `appBorder` y esquinas continuous (squircle, `Radii.input`).
/// Reutilizable por login, signup y el alta de hogar.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.enabled = true,
    this.onSubmitted,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.sm),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: false,
          style: AppText.body(c.textPrimary),
          cursorColor: c.brandPrimary,
          decoration: _decoration(c),
        ),
      ],
    );
  }
}

/// Campo de contraseña con ojito (mostrar/ocultar) — espejo del
/// `MCPasswordField` del iOS. Mismo look que [AuthTextField].
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.autofillHints,
    this.enabled = true,
    this.onSubmitted,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(), style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.sm),
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscured,
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          autocorrect: false,
          enableSuggestions: false,
          style: AppText.body(c.textPrimary),
          cursorColor: c.brandPrimary,
          decoration: _decoration(c).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 18,
                color: c.textMuted,
              ),
              tooltip: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
          ),
        ),
      ],
    );
  }
}

/// Decoración compartida por los campos de auth: fill `appSurface`, borde
/// hairline `appBorder` (sage glow), focus en `brandPrimary`. Esquinas
/// continuous vía `OutlineInputBorder` + `SmoothBorderRadius` (figma_squircle,
/// que es un `BorderRadius`) para matchear el `.continuous` del iOS.
InputDecoration _decoration(MidnightSageColors c) {
  final radius = Radii.smooth(Radii.input);
  final border = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: c.appBorder, width: 1),
  );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: c.appSurface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: Insets.screen,
      vertical: Insets.card,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: c.brandPrimary, width: 1.5),
    ),
    disabledBorder: border,
  );
}
