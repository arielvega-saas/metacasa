import 'dart:ui' show PlatformDispatcher;

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_state.dart';
import 'auth_field.dart';

/// Alta/ingreso a un hogar — espejo del `CreateJoinHouseholdView` del iOS.
///
/// Segmented "Crear" (nombre + moneda) / "Unirme" (pegar token de invitación).
/// Invoca las acciones del gate (`createHousehold` / `joinHousehold`), que
/// re-evalúan y transicionan a `ready` cuando salen bien.
class CreateJoinHouseholdScreen extends ConsumerStatefulWidget {
  const CreateJoinHouseholdScreen({super.key});

  @override
  ConsumerState<CreateJoinHouseholdScreen> createState() =>
      _CreateJoinHouseholdScreenState();
}

enum _Mode { create, join }

class _CreateJoinHouseholdScreenState
    extends ConsumerState<CreateJoinHouseholdScreen> {
  _Mode _mode = _Mode.create;

  final _name = TextEditingController(text: 'Mi Hogar');
  final _token = TextEditingController();
  late String _currency = _guessLocaleCurrency();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onChanged);
    _token.addListener(_onChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _token.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _setMode(_Mode mode) => setState(() {
        _mode = mode;
        _error = null;
      });

  Future<void> _submitCreate() async {
    final name = _name.text.trim();
    if (_loading || name.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(appGateProvider.notifier)
          .createHousehold(name: name, currency: _currency);
      // Éxito → el gate transiciona a `ready` y el router saca de esta pantalla.
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo crear el hogar. Probá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitJoin() async {
    final token = _token.text.trim();
    if (_loading || token.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(appGateProvider.notifier).joinHousehold(token);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo aceptar la invitación. Revisá el token e intentá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                  _header(c),
                  const SizedBox(height: Insets.xxl),
                  _modePicker(c),
                  const SizedBox(height: Insets.xxl),
                  if (_mode == _Mode.create) _createForm(c) else _joinForm(c),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(MidnightSageColors c) {
    return Column(
      children: [
        Text(
          'Tu hogar',
          style: AppText.serifDisplay(c.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.xl),
        Text(
          'Creá un hogar nuevo o unite a uno con un invite.',
          style: AppText.body(c.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _modePicker(MidnightSageColors c) {
    return SegmentedButton<_Mode>(
      segments: const [
        ButtonSegment(value: _Mode.create, label: Text('Crear')),
        ButtonSegment(value: _Mode.join, label: Text('Unirme')),
      ],
      selected: {_mode},
      showSelectedIcon: false,
      onSelectionChanged: _loading ? null : (s) => _setMode(s.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? c.brandPrimary.withValues(alpha: 0.16)
              : c.appSurface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? c.brandPrimary
              : c.textMuted;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: c.appBorder)),
        textStyle: WidgetStatePropertyAll(
          AppText.body(c.textPrimary).copyWith(fontWeight: FontWeight.w600),
        ),
        shape: WidgetStatePropertyAll(
          SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.pill)),
        ),
      ),
    );
  }

  Widget _createForm(MidnightSageColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          label: 'Nombre del hogar',
          controller: _name,
          textCapitalization: TextCapitalization.words,
          enabled: !_loading,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitCreate(),
        ),
        const SizedBox(height: Insets.section),
        _currencyField(c),
        if (_error != null) ...[
          const SizedBox(height: Insets.section),
          _MessageCard(message: _error!, color: c.brandDanger),
        ],
        const SizedBox(height: Insets.cardLg),
        MCPrimaryButton(
          label: _loading ? 'Creando…' : 'Crear hogar',
          onPressed:
              (_loading || _name.text.trim().isEmpty) ? null : _submitCreate,
        ),
        const SizedBox(height: Insets.xl),
        Text(
          'Vas a poder agregar otras monedas y cambiar esta después.',
          style: AppText.caption(c.textDim),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _joinForm(MidnightSageColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          label: 'Token de invitación',
          controller: _token,
          enabled: !_loading,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitJoin(),
        ),
        if (_error != null) ...[
          const SizedBox(height: Insets.section),
          _MessageCard(message: _error!, color: c.brandDanger),
        ],
        const SizedBox(height: Insets.cardLg),
        MCPrimaryButton(
          label: _loading ? 'Uniéndote…' : 'Unirme al hogar',
          onPressed:
              (_loading || _token.text.trim().isEmpty) ? null : _submitJoin,
        ),
        const SizedBox(height: Insets.xl),
        Text(
          'Pedile al admin del hogar que te genere un invite.',
          style: AppText.caption(c.textDim),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Selector de moneda. El catálogo completo todavía no está portado; ofrecemos
  /// las monedas core de los mercados objetivo (US/global + LatAm) en un menú,
  /// con la del locale preseleccionada. Cuando exista el catálogo del iOS, se
  /// reemplaza por el picker completo.
  Widget _currencyField(MidnightSageColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MONEDA PRINCIPAL', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.sm),
        Container(
          decoration: ShapeDecoration(
            color: c.appSurface,
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.input),
              side: BorderSide(color: c.appBorder, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currency,
              isExpanded: true,
              dropdownColor: c.appSurface,
              borderRadius: BorderRadius.circular(Radii.card),
              style: AppText.body(c.textPrimary),
              icon: Icon(Icons.expand_more, color: c.textMuted),
              items: _kCurrencies
                  .map((code) => DropdownMenuItem(
                        value: code,
                        child: Text(code, style: AppText.body(c.textPrimary)),
                      ))
                  .toList(),
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _currency = v ?? _currency),
            ),
          ),
        ),
      ],
    );
  }

  /// Adivina la moneda del locale del device (espejo de `localeCurrency()` del
  /// iOS). Sin catálogo completo: mapeamos por país a las core soportadas; si no
  /// cae en la lista, USD.
  static String _guessLocaleCurrency() {
    final country =
        PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
    final guess = _kCountryToCurrency[country];
    return (guess != null && _kCurrencies.contains(guess)) ? guess : 'USD';
  }
}

/// Monedas core ofrecidas en el alta (US/global + LatAm). Lista acotada a
/// propósito hasta portar el catálogo completo del iOS.
const List<String> _kCurrencies = [
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

/// Mapeo país → moneda para preseleccionar según el locale del device.
const Map<String, String> _kCountryToCurrency = {
  'US': 'USD',
  'AR': 'ARS',
  'BR': 'BRL',
  'MX': 'MXN',
  'CL': 'CLP',
  'CO': 'COP',
  'PE': 'PEN',
  'UY': 'UYU',
  'GB': 'GBP',
  'ES': 'EUR',
  'DE': 'EUR',
  'FR': 'EUR',
  'IT': 'EUR',
};

/// Card de mensaje inline (reutilizada del look de la pantalla de auth).
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
