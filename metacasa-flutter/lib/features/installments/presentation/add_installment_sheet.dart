import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/supabase_init.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../application/installments_controller.dart';

/// Hoja "Nuevo plan de cuotas" — espejo de `AddInstallmentPlanView` (iOS),
/// adaptada al look de los otros formularios Flutter (bottom-sheet con sticky
/// save bar).
///
/// Flujo (de arriba a abajo), 1:1 con iOS:
///   1. Nombre del plan.
///   2. Monto total (hero serif).
///   3. Cantidad de cuotas (stepper 1–120).
///   4. Mes de inicio (DatePicker; el modelo guarda año/mes).
///   5. Categoría y nota (opcionales).
///   6. Preview en vivo del valor por cuota (total ÷ N).
///   7. Botón guardar. Valida nombre + total > 0; **setea `created_by` con el
///      usuario autenticado** (el repo NO lo inyecta) y delega en el controller
///      (que crea el plan y siembra el ledger de pagos).
class AddInstallmentSheet extends ConsumerStatefulWidget {
  const AddInstallmentSheet({super.key, required this.householdId});

  /// Hogar al que se agrega el plan.
  final String householdId;

  /// Presenta la hoja modal con el look del design system. Devuelve `true` si se
  /// guardó (para que el caller refresque la lista).
  static Future<bool?> show(BuildContext context, String householdId) {
    final c = context.colors;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AddInstallmentSheet(householdId: householdId),
    );
  }

  @override
  ConsumerState<AddInstallmentSheet> createState() =>
      _AddInstallmentSheetState();
}

class _AddInstallmentSheetState extends ConsumerState<AddInstallmentSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _totalCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  int _installments = 12;
  late DateTime _startDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default: el mes actual (runtime, no const).
    final DateTime now = DateTime.now();
    _startDate = DateTime(now.year, now.month);
    _nameCtrl.addListener(_onChanged);
    _totalCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onChanged);
    _totalCtrl.removeListener(_onChanged);
    _nameCtrl.dispose();
    _totalCtrl.dispose();
    _categoryCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Moneda base del hogar (cae a USD).
  String get _currency =>
      ref.read(currentHouseholdProvider).valueOrNull?.defaultCurrency ?? 'USD';

  /// Monto total parseado (> 0) o null.
  Decimal? get _parsedTotal {
    final Decimal? d = Money.parse(_totalCtrl.text);
    if (d == null || d <= Decimal.zero) return null;
    return d;
  }

  /// Valor por cuota (total ÷ N) en `Decimal`, o null si no hay total válido.
  Decimal? get _perMonth {
    final Decimal? total = _parsedTotal;
    if (total == null || _installments <= 0) return null;
    return (total / Decimal.fromInt(_installments))
        .toDecimal(scaleOnInfinitePrecision: 10);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool canSave =
        _nameCtrl.text.trim().isNotEmpty && _parsedTotal != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.screen,
                  Insets.md,
                  Insets.screen,
                  Insets.card,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(context),
                    const SizedBox(height: Insets.section),
                    _nameField(context),
                    const SizedBox(height: Insets.section),
                    _totalField(context),
                    const SizedBox(height: Insets.section),
                    _installmentsStepper(context),
                    const SizedBox(height: Insets.section),
                    _startDateField(context),
                    const SizedBox(height: Insets.section),
                    _perMonthPreview(context),
                    const SizedBox(height: Insets.section),
                    _optionalFields(context),
                    if (_error != null) ...[
                      const SizedBox(height: Insets.card),
                      Text(_error!,
                          style: AppText.caption(context.colors.brandDanger)),
                    ],
                  ],
                ),
              ),
            ),
            _saveBar(context, canSave),
          ],
        ),
      ),
    );
  }

  // ── Encabezado ──────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(LucideIcons.creditCard, size: 20, color: c.brandPrimary),
        const SizedBox(width: Insets.md),
        Text('Nuevo plan', style: AppText.h2(c.textPrimary)),
      ],
    );
  }

  // ── Nombre ────────────────────────────────────────────────────────────────

  Widget _nameField(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NOMBRE', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TextField(
          controller: _nameCtrl,
          style: AppText.body(c.textPrimary),
          textCapitalization: TextCapitalization.sentences,
          decoration:
              _inputDecoration(context, hint: 'Ej. iPhone en 12 cuotas'),
        ),
      ],
    );
  }

  // ── Monto total ─────────────────────────────────────────────────────────────

  /// Card del monto total: label + código de moneda, símbolo + input numérico.
  Widget _totalField(BuildContext context) {
    final c = context.colors;
    final Decimal? total = _parsedTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('MONTO TOTAL', style: AppText.label(c.textMuted)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: 2),
              decoration: ShapeDecoration(
                color: c.appSurfaceInset,
                shape: const StadiumBorder(),
              ),
              child: Text(
                _currency,
                style: AppText.caption(c.textMuted)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.cardLg,
            vertical: Insets.section,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c.brandPrimary.withValues(alpha: 0.10),
                c.brandSecondary.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(Radii.hero),
          ),
          child: Row(
            children: [
              Text(
                Money.symbolFor(_currency),
                style: AppText.serifDisplay(
                  total == null ? c.textDim : c.brandPrimary,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: TextField(
                  controller: _totalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: AppText.serifDisplay(c.textPrimary),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: AppText.serifDisplay(c.textDim),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Cuotas ──────────────────────────────────────────────────────────────────

  /// Stepper de cantidad de cuotas (1–120). Espejo del `Stepper` de iOS.
  Widget _installmentsStepper(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CANTIDAD DE CUOTAS', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.screen,
            vertical: Insets.lg,
          ),
          decoration: BoxDecoration(
            color: c.appSurfaceInset,
            borderRadius: BorderRadius.circular(Radii.input),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$_installments ${_installments == 1 ? 'cuota' : 'cuotas'}',
                  style: AppText.body(c.textPrimary),
                ),
              ),
              _StepperButton(
                icon: LucideIcons.minus,
                onTap: _installments > 1
                    ? () => setState(() => _installments--)
                    : null,
              ),
              const SizedBox(width: Insets.md),
              _StepperButton(
                icon: LucideIcons.plus,
                onTap: _installments < 120
                    ? () => setState(() => _installments++)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Inicio ──────────────────────────────────────────────────────────────────

  /// Campo de mes de inicio: tile que abre el `showDatePicker` Material. El
  /// modelo solo usa año/mes, pero pedimos una fecha completa por simplicidad.
  Widget _startDateField(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MES DE INICIO', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _pickStartDate,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.screen,
              vertical: Insets.card,
            ),
            decoration: BoxDecoration(
              color: c.appSurfaceInset,
              borderRadius: BorderRadius.circular(Radii.input),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.calendar, size: 16, color: c.textMuted),
                const SizedBox(width: Insets.md),
                Text(_formatMonth(_startDate),
                    style: AppText.body(c.textPrimary)),
                const Spacer(),
                Icon(LucideIcons.chevronRight, size: 16, color: c.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickStartDate() async {
    HapticFeedback.selectionClick();
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => _startDate = DateTime(picked.year, picked.month));
    }
  }

  // ── Preview por cuota ─────────────────────────────────────────────────────────

  /// Preview en vivo del valor por cuota (total ÷ N). Se atenúa si no hay total.
  Widget _perMonthPreview(BuildContext context) {
    final c = context.colors;
    final Decimal? perMonth = _perMonth;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.cardLg,
        vertical: Insets.card,
      ),
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: SmoothRectangleBorder(
          borderRadius: Radii.smooth(Radii.input),
          side: BorderSide(color: c.appBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.calendarClock, size: 16, color: c.brandPrimary),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text('Cada mes', style: AppText.body(c.textMuted)),
          ),
          if (perMonth != null)
            AmountText(
              value: perMonth,
              currencyCode: _currency,
              kind: AmountKind.gasto,
              style: AppText.body(c.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            )
          else
            Text('—', style: AppText.body(c.textDim)),
        ],
      ),
    );
  }

  // ── Opcionales ────────────────────────────────────────────────────────────────

  Widget _optionalFields(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CATEGORÍA (OPCIONAL)', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TextField(
          controller: _categoryCtrl,
          style: AppText.body(c.textPrimary),
          textCapitalization: TextCapitalization.sentences,
          decoration: _inputDecoration(context, hint: 'Ej. Tecnología'),
        ),
        const SizedBox(height: Insets.section),
        Text('NOTA (OPCIONAL)', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TextField(
          controller: _noteCtrl,
          style: AppText.body(c.textPrimary),
          textCapitalization: TextCapitalization.sentences,
          minLines: 1,
          maxLines: 3,
          decoration: _inputDecoration(context, hint: 'Detalle opcional'),
        ),
      ],
    );
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  Widget _saveBar(BuildContext context, bool canSave) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.appSurface,
        border: Border(
          top: BorderSide(color: c.appBorder.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.xl,
        Insets.screen,
        Insets.xl,
      ),
      child: MCPrimaryButton(
        label: _saving ? 'Guardando…' : 'Crear plan',
        icon: LucideIcons.check,
        onPressed: (canSave && !_saving) ? _save : null,
      ),
    );
  }

  /// Valida y crea el plan. **Setea `created_by` con el usuario autenticado** (el
  /// repo no lo inyecta) y delega en el controller (que siembra el ledger).
  Future<void> _save() async {
    setState(() => _error = null);
    final Decimal? total = _parsedTotal;
    if (total == null) {
      setState(() => _error = 'Ingresá un monto total válido mayor a cero.');
      return;
    }
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ponele un nombre al plan.');
      return;
    }
    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _error = 'No encontramos tu sesión. Reintentá.');
      return;
    }

    setState(() => _saving = true);
    // `id` vacío → el repo lo remueve del payload (la DB genera el real).
    final InstallmentPlan plan = InstallmentPlan(
      id: '',
      householdId: widget.householdId,
      name: name,
      totalAmount: total,
      totalInstallments: _installments,
      currency: _currency,
      startYear: _startDate.year,
      startMonth: _startDate.month,
      category:
          _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      status: PlanStatus.active,
      createdBy: userId,
    );

    try {
      await ref.read(installmentsControllerProvider.notifier).createPlan(plan);
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No pudimos crear el plan. Reintentá.';
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Decoración de input consistente (surface inset + squircle, sin borde).
  InputDecoration _inputDecoration(BuildContext context,
      {required String hint}) {
    final c = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.body(c.textDim),
      filled: true,
      fillColor: c.appSurfaceInset,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.screen,
        vertical: Insets.card,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide.none,
      ),
    );
  }

  /// Mes legible (rioplatense): "mayo 2026".
  static String _formatMonth(DateTime d) {
    const List<String> months = <String>[
      '',
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${months[d.month]} ${d.year}';
  }
}

/// Botón circular − / + del stepper de cuotas. Privado a la hoja (mismo recipe
/// que el stepper del alta de meta).
class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.appSurface,
            shape: StadiumBorder(side: BorderSide(color: c.appBorder)),
          ),
          child: Icon(icon, size: 16, color: c.brandPrimary),
        ),
      ),
    );
  }
}
