import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/waterfall_controller.dart';

/// Hoja de configuración de la **estrategia waterfall** del hogar. Espejo de
/// `StrategySettingsSheet` / `PlanEditorView` (iOS).
///
/// Controles:
///   - Modo de distribución (Equitativa / Proporcional / Personalizada),
///     segmentado.
///   - Ahorro % e Inversión % con sliders 0–90.
///   - Tres toggles de inclusión (vencimientos / cuotas / deudas).
///
/// Cada cambio re-corre el `WaterfallCalculator` con la strategy LOCAL para
/// mostrar un preview en vivo del remanente. Al guardar persiste vía
/// `WaterfallController.saveStrategy` → `householdRepository.updateStrategy`.
class StrategySheet extends ConsumerStatefulWidget {
  const StrategySheet({super.key});

  /// Presenta la hoja modal (scroll-controlled, alto). El estado inicial sale
  /// de la strategy vigente del hogar (vía [waterfallControllerProvider]).
  static Future<void> show(BuildContext context) {
    final c = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const StrategySheet(),
    );
  }

  @override
  ConsumerState<StrategySheet> createState() => _StrategySheetState();
}

class _StrategySheetState extends ConsumerState<StrategySheet> {
  /// Strategy local (editable). Se inicializa de forma perezosa con la del hogar
  /// la primera vez que hay datos del controller.
  HouseholdStrategy? _local;
  bool _saving = false;

  /// Devuelve la strategy local, inicializándola desde [fallback] si todavía no
  /// se cargó (primer build con datos).
  HouseholdStrategy _strategy(HouseholdStrategy fallback) =>
      _local ??= fallback;

  /// Pct (0–90) clampeado de un slider, a `Decimal` exacto (entero).
  Decimal _pct(double v) => Decimal.fromInt(v.round().clamp(0, 90));

  Future<void> _save() async {
    final HouseholdStrategy? strategy = _local;
    if (strategy == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(waterfallControllerProvider.notifier)
          .saveStrategy(strategy);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final AsyncValue<WaterfallInputs> async =
        ref.watch(waterfallControllerProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: async.when(
          loading: () => const _SheetLoading(),
          error: (Object err, StackTrace _) => Padding(
            padding: const EdgeInsets.all(Insets.xxl),
            child: Text(
              'No pudimos cargar la estrategia.',
              style: AppText.body(c.textMuted),
            ),
          ),
          data: (WaterfallInputs inputs) => _StrategyForm(
            strategy: _strategy(inputs.strategy),
            // Preview del remanente con la strategy local (re-cálculo en vivo).
            previewRemainder: inputs
                .calculate(overrideStrategy: _strategy(inputs.strategy))
                .remainder,
            currency: inputs.currency,
            saving: _saving,
            onChanged: (HouseholdStrategy s) => setState(() => _local = s),
            onPct: _pct,
            onSave: _save,
          ),
        ),
      ),
    );
  }
}

/// Cuerpo del formulario (ya con datos). Stateless: el estado lo sostiene el
/// padre; cada cambio reconstruye con la nueva strategy local + preview.
class _StrategyForm extends StatelessWidget {
  const _StrategyForm({
    required this.strategy,
    required this.previewRemainder,
    required this.currency,
    required this.saving,
    required this.onChanged,
    required this.onPct,
    required this.onSave,
  });

  final HouseholdStrategy strategy;
  final Decimal previewRemainder;
  final String currency;
  final bool saving;
  final ValueChanged<HouseholdStrategy> onChanged;
  final Decimal Function(double) onPct;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        Insets.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sliders, size: 20, color: c.brandPrimary),
              const SizedBox(width: Insets.md),
              Text('Estrategia', style: AppText.h2(c.textPrimary)),
            ],
          ),
          const SizedBox(height: Insets.section),

          // ── Distribución ──
          Text('DISTRIBUCIÓN', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.md),
          _DistributionSegmented(
            value: strategy.distributionMode,
            onChanged: (DistributionMode m) =>
                onChanged(strategy.copyWith(distributionMode: m)),
          ),
          const SizedBox(height: Insets.sm),
          Text(_distributionHint(strategy.distributionMode),
              style: AppText.caption(c.textMuted)),
          const SizedBox(height: Insets.section),

          // ── Sliders ──
          Text('AHORRO E INVERSIÓN', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.md),
          _PctSlider(
            icon: LucideIcons.banknote,
            label: 'Ahorro',
            color: c.brandSuccess,
            pct: strategy.savingsPct,
            onChanged: (double v) =>
                onChanged(strategy.copyWith(savingsPct: onPct(v))),
          ),
          const SizedBox(height: Insets.card),
          _PctSlider(
            icon: LucideIcons.trendingUp,
            label: 'Inversión',
            color: c.brandSecondary,
            pct: strategy.investmentPct,
            onChanged: (double v) =>
                onChanged(strategy.copyWith(investmentPct: onPct(v))),
          ),
          const SizedBox(height: Insets.section),

          // ── Inclusiones ──
          Text('INCLUIR EN LA CASCADA', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.md),
          MCCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.card,
              vertical: Insets.xs,
            ),
            child: Column(
              children: [
                _InclusionToggle(
                  icon: LucideIcons.calendarClock,
                  label: 'Vencimientos',
                  value: strategy.includeBillsInWaterfall,
                  onChanged: (bool v) =>
                      onChanged(strategy.copyWith(includeBillsInWaterfall: v)),
                ),
                Divider(color: c.appBorder, height: 1),
                _InclusionToggle(
                  icon: LucideIcons.creditCard,
                  label: 'Cuotas',
                  value: strategy.includeInstallmentsInWaterfall,
                  onChanged: (bool v) => onChanged(
                      strategy.copyWith(includeInstallmentsInWaterfall: v)),
                ),
                Divider(color: c.appBorder, height: 1),
                _InclusionToggle(
                  icon: LucideIcons.arrowDownToLine,
                  label: 'Pagos de deuda',
                  value: strategy.includeDebtPaymentsInWaterfall,
                  onChanged: (bool v) => onChanged(
                      strategy.copyWith(includeDebtPaymentsInWaterfall: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.section),

          // ── Preview del remanente ──
          _RemainderPreview(remainder: previewRemainder, currency: currency),
          const SizedBox(height: Insets.section),

          // ── Guardar ──
          MCPrimaryButton(
            label: saving ? 'Guardando…' : 'Guardar estrategia',
            onPressed: saving ? null : onSave,
          ),
        ],
      ),
    );
  }

  /// Hint del modo de distribución. Espejo de `distributionHint` de iOS.
  String _distributionHint(DistributionMode mode) => switch (mode) {
        DistributionMode.equal =>
          'El remanente se reparte en partes iguales entre las cuentas personales.',
        DistributionMode.proportional =>
          'Cada cuenta recibe según el ingreso que aportó este mes.',
        DistributionMode.custom =>
          'Definís manualmente cuánto va a cada cuenta personal.',
      };
}

/// Segmentado del modo de distribución (equal / proportional / custom).
class _DistributionSegmented extends StatelessWidget {
  const _DistributionSegmented({required this.value, required this.onChanged});

  final DistributionMode value;
  final ValueChanged<DistributionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.pill)),
      ),
      child: Row(
        children: DistributionMode.values.map((DistributionMode mode) {
          final bool selected = mode == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(mode);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: Insets.lg),
                decoration: ShapeDecoration(
                  color: selected ? c.brandPrimary : Colors.transparent,
                  shape: SmoothRectangleBorder(
                    borderRadius: Radii.smooth(Radii.badge),
                  ),
                ),
                child: Text(
                  mode.label,
                  textAlign: TextAlign.center,
                  style: AppText.caption(
                    selected ? const Color(0xFF0E1312) : c.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Fila de slider de porcentaje (0–90): ícono + label + valor grande + slider.
/// Espejo del `pctRow` / `sliderRow` de iOS.
class _PctSlider extends StatelessWidget {
  const _PctSlider({
    required this.icon,
    required this.label,
    required this.color,
    required this.pct,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Decimal pct;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final double value = pct.toDouble().clamp(0, 90);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                label,
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${value.round()}%',
              style: AppText.h2(color),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: c.appSurfaceInset,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            max: 90,
            divisions: 90,
            onChanged: onChanged,
            onChangeEnd: (_) => HapticFeedback.selectionClick(),
          ),
        ),
      ],
    );
  }
}

/// Toggle de inclusión: ícono + label + Switch sage. Espejo de los `Toggle` de
/// la sección de inclusiones de iOS.
class _InclusionToggle extends StatelessWidget {
  const _InclusionToggle({
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
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.brandPrimary),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Text(label, style: AppText.body(c.textPrimary)),
          ),
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

/// Preview del remanente con la strategy local — feedback en vivo del impacto.
class _RemainderPreview extends StatelessWidget {
  const _RemainderPreview({required this.remainder, required this.currency});

  final Decimal remainder;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool positive = remainder >= Decimal.zero;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.cardLg),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [
            (positive ? c.brandSuccess : c.brandDanger).withValues(alpha: 0.15),
            c.appSurface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        shape: SmoothRectangleBorder(
          borderRadius: Radii.smooth(Radii.card),
          side: BorderSide(
            color: (positive ? c.brandSuccess : c.brandDanger)
                .withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REMANENTE ESTIMADO', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.sm),
          AmountText(
            value: remainder,
            currencyCode: currency,
            kind: AmountKind.balance,
            fitToWidth: true,
            style: AppText.serifAmount(c.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Loading del sheet: spinner centrado con alto fijo (evita que el sheet
/// colapse mientras carga los inputs).
class _SheetLoading extends StatelessWidget {
  const _SheetLoading();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 240,
      child: Center(
        child: CircularProgressIndicator(color: c.brandPrimary),
      ),
    );
  }
}
