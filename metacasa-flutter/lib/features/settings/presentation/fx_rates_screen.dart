import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/fx_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../../auth/presentation/auth_field.dart';

/// Pantalla de tasas de cambio manuales — espejo de `FXRatesView` de iOS.
///
/// Las tasas viven en `households.fx_rates` (JSONB): "cuántas unidades de la
/// moneda BASE equivalen a 1 unidad de la moneda listada". UX:
///   - Lista ordenada por código (moneda → tasa → última actualización).
///   - "+" en la AppBar abre una hoja para agregar/editar (picker + input).
///   - Swipe / botón para borrar.
///   - Privacy-aware: respeta `privacyModeProvider` para ocultar los números.
class FxRatesScreen extends ConsumerStatefulWidget {
  const FxRatesScreen({super.key});

  @override
  ConsumerState<FxRatesScreen> createState() => _FxRatesScreenState();
}

class _FxRatesScreenState extends ConsumerState<FxRatesScreen> {
  Map<String, FXRate> _rates = <String, FXRate>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _householdId =>
      ref.read(currentHouseholdProvider).valueOrNull?.id;

  String get _baseCurrency =>
      ref.read(currentHouseholdProvider).valueOrNull?.defaultCurrency ?? 'USD';

  Future<void> _load() async {
    final String? hid = _householdId;
    if (hid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final Map<String, FXRate> rates =
          await ref.read(fxRepositoryProvider).getRates(hid);
      if (mounted) {
        setState(() {
          _rates = rates;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No pudimos cargar las tasas. Revisá tu conexión.';
        });
      }
    }
  }

  Future<void> _setRate(String code, Decimal rate) async {
    final String? hid = _householdId;
    if (hid == null) return;
    try {
      await ref.read(fxRepositoryProvider).setManualRate(hid, code, rate);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar la tasa.');
      }
    }
  }

  Future<void> _removeRate(String code) async {
    final String? hid = _householdId;
    if (hid == null) return;
    HapticFeedback.mediumImpact();
    try {
      await ref.read(fxRepositoryProvider).removeRate(hid, code);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo borrar la tasa.');
      }
    }
  }

  Future<void> _openAdd() async {
    HapticFeedback.mediumImpact();
    final ({String code, Decimal rate})? result = await _AddFxRateSheet.show(
      context,
      baseCurrency: _baseCurrency,
      existingCodes: _rates.keys.toSet(),
    );
    if (result != null) {
      await _setRate(result.code, result.rate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool privacy = ref.watch(privacyModeProvider);
    final String base = _baseCurrency;
    final List<MapEntry<String, FXRate>> sorted = _rates.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        title: Text('Monedas y cambio', style: AppText.h2(c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, color: c.brandPrimary),
            tooltip: 'Agregar tasa',
            onPressed: _householdId == null ? null : _openAdd,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: _load,
        child: _loading && _rates.isEmpty
            ? const _RatesSkeleton()
            : sorted.isEmpty
                ? _EmptyRates(
                    base: base, onAdd: _householdId == null ? null : _openAdd)
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      Insets.screen,
                      Insets.md,
                      Insets.screen,
                      Insets.xxl,
                    ),
                    children: [
                      _BaseHeader(base: base),
                      const SizedBox(height: Insets.md),
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
                              for (var i = 0; i < sorted.length; i++) ...[
                                _RateRow(
                                  code: sorted[i].key,
                                  rate: sorted[i].value,
                                  base: base,
                                  privacy: privacy,
                                  onEdit: () => _setRatePrompt(sorted[i].key),
                                  onDelete: () => _removeRate(sorted[i].key),
                                ),
                                if (i != sorted.length - 1)
                                  Divider(
                                    color: c.appBorder,
                                    height: 1,
                                    thickness: 1,
                                    indent: Insets.cardLg,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Insets.section),
                        _MessageCard(message: _error!, color: c.brandDanger),
                      ],
                      const SizedBox(height: Insets.section),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: Insets.xs),
                        child: Text(
                          'Estas tasas se usan para convertir movimientos en otras '
                          'monedas a tu moneda base ($base).',
                          style: AppText.caption(c.textMuted),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  /// Reabre la hoja preseleccionando el código a editar (mismo flujo que el
  /// alta; el upsert reescribe la entrada existente).
  Future<void> _setRatePrompt(String code) async {
    final ({String code, Decimal rate})? result = await _AddFxRateSheet.show(
      context,
      baseCurrency: _baseCurrency,
      existingCodes: _rates.keys.toSet(),
      initialCode: code,
    );
    if (result != null) {
      await _setRate(result.code, result.rate);
    }
  }
}

// ─────────────────────────────── Header base ───────────────────────────────

class _BaseHeader extends StatelessWidget {
  const _BaseHeader({required this.base});

  final String base;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
      child: Row(
        children: [
          Expanded(
            child: Text('TASAS MANUALES', style: AppText.label(c.textMuted)),
          ),
          Text('Base: $base',
              style: AppText.caption(c.brandPrimary)
                  .copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Fila de tasa ──────────────────────────────

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.code,
    required this.rate,
    required this.base,
    required this.privacy,
    required this.onEdit,
    required this.onDelete,
  });

  final String code;
  final FXRate rate;
  final String base;
  final bool privacy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final DateTime? updated = DateTime.tryParse(rate.updatedAt);
    final String updatedLabel =
        updated == null ? '' : DateFormat('d MMM').format(updated.toLocal());

    return Dismissible(
      key: ValueKey<String>('fx_$code'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: c.brandDanger.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: Insets.cardLg),
        child: Icon(LucideIcons.trash2, color: c.brandDanger, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.cardLg,
            vertical: Insets.card,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  code,
                  style: AppText.body(c.textPrimary)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1 $code =', style: AppText.caption(c.textMuted)),
                    const SizedBox(height: Insets.xxs),
                    AmountText(
                      value: rate.rate,
                      currencyCode: base,
                      kind: AmountKind.neutro,
                      obscured: privacy,
                      moneyStyle: MoneyStyle.auto,
                      style: AppText.body(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (updatedLabel.isNotEmpty)
                Text(updatedLabel, style: AppText.caption(c.textDim)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Add/edit sheet ────────────────────────────

/// Hoja para agregar o editar una tasa: picker de moneda (catálogo popular,
/// menos la base) + input del rate. Devuelve `(code, rate)` por el Navigator.
class _AddFxRateSheet extends StatefulWidget {
  const _AddFxRateSheet({
    required this.baseCurrency,
    required this.existingCodes,
    this.initialCode,
  });

  final String baseCurrency;
  final Set<String> existingCodes;
  final String? initialCode;

  static const List<String> _popular = <String>[
    'USD',
    'EUR',
    'GBP',
    'BRL',
    'ARS',
    'MXN',
    'CLP',
    'COP',
    'PEN',
    'UYU',
    'JPY',
    'CAD',
  ];

  static Future<({String code, Decimal rate})?> show(
    BuildContext context, {
    required String baseCurrency,
    required Set<String> existingCodes,
    String? initialCode,
  }) {
    final c = context.colors;
    return showModalBottomSheet<({String code, Decimal rate})>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AddFxRateSheet(
        baseCurrency: baseCurrency,
        existingCodes: existingCodes,
        initialCode: initialCode,
      ),
    );
  }

  @override
  State<_AddFxRateSheet> createState() => _AddFxRateSheetState();
}

class _AddFxRateSheetState extends State<_AddFxRateSheet> {
  final TextEditingController _rateCtrl = TextEditingController();
  late String _code;

  List<String> get _options {
    // Catálogo popular sin la base; garantizamos que el código inicial (edición)
    // esté presente aunque no sea "popular".
    final List<String> base = _AddFxRateSheet._popular
        .where((String code) => code != widget.baseCurrency)
        .toList();
    final String? initial = widget.initialCode;
    if (initial != null && !base.contains(initial)) {
      return <String>[initial, ...base];
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    final List<String> opts = _options;
    _code = widget.initialCode ?? (opts.isNotEmpty ? opts.first : 'USD');
    _rateCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  Decimal? get _parsed => Money.parse(_rateCtrl.text);
  bool get _isValid => (_parsed ?? Decimal.zero) > Decimal.zero;

  void _submit() {
    final Decimal? r = _parsed;
    if (r == null || r <= Decimal.zero) return;
    Navigator.of(context).pop((code: _code, rate: r));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool willReplace = widget.existingCodes.contains(_code);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.dollarSign, size: 20, color: c.brandPrimary),
                  const SizedBox(width: Insets.md),
                  Text(
                      widget.initialCode == null ? 'Nueva tasa' : 'Editar tasa',
                      style: AppText.h2(c.textPrimary)),
                ],
              ),
              const SizedBox(height: Insets.section),
              Text('MONEDA', style: AppText.label(c.textMuted)),
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
                    value: _code,
                    isExpanded: true,
                    dropdownColor: c.appSurface,
                    borderRadius: BorderRadius.circular(Radii.card),
                    style: AppText.body(c.textPrimary),
                    icon: Icon(LucideIcons.chevronDown, color: c.textMuted),
                    items: _options
                        .map((String code) => DropdownMenuItem<String>(
                              value: code,
                              child: Text(code,
                                  style: AppText.body(c.textPrimary)),
                            ))
                        .toList(),
                    onChanged: (String? v) {
                      if (v != null) setState(() => _code = v);
                    },
                  ),
                ),
              ),
              if (willReplace) ...[
                const SizedBox(height: Insets.sm),
                Text('Ya existe una tasa para $_code; se va a reemplazar.',
                    style: AppText.caption(c.brandWarning)),
              ],
              const SizedBox(height: Insets.section),
              AuthTextField(
                label: '1 $_code = ? ${widget.baseCurrency}',
                controller: _rateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Ingresá cuántos ${widget.baseCurrency} equivale 1 $_code.',
                style: AppText.caption(c.textMuted),
              ),
              const SizedBox(height: Insets.cardLg),
              MCPrimaryButton(
                label: 'Guardar',
                onPressed: _isValid ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Estados ───────────────────────────────────

class _EmptyRates extends StatelessWidget {
  const _EmptyRates({required this.base, required this.onAdd});

  final String base;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.dollarSign,
            title: 'Sin tasas manuales',
            message:
                'Agregá una tasa para convertir movimientos en otras monedas a $base.',
            actionLabel: onAdd == null ? null : 'Agregar tasa',
            onAction: onAdd,
          ),
        ),
      ],
    );
  }
}

class _RatesSkeleton extends StatelessWidget {
  const _RatesSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        Insets.xxl,
      ),
      children: [
        Container(
          height: 220,
          decoration: ShapeDecoration(
            color: c.appSurface,
            shape:
                SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
          ),
        ),
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
