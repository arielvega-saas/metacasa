import 'package:decimal/decimal.dart';
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
import '../application/debt_format.dart';
import '../application/debts_controller.dart';

/// Hoja "Nueva deuda" / "Editar deuda" — espejo de `AddDebtView` (iOS),
/// adaptada al look de los formularios Flutter (bottom-sheet con sticky save bar).
///
/// Campos (de arriba a abajo), 1:1 con iOS:
///   1. Acreedor.
///   2. Monto original.
///   3. Saldo actual (default = original al crear).
///   4. Tasa anual %.
///   5. Pago mensual (opcional).
///   6. Fecha de inicio + toggle de vencimiento + fecha de vencimiento.
///   7. Categoría y nota (opcionales).
///
/// En guardar: **setea `created_by` con el usuario autenticado** (el repo no lo
/// inyecta) al crear; en edición preserva los campos inmutables (id, hogar,
/// moneda, original, inicio, estado, autor) y reconstruye la deuda para poder
/// **vaciar** opcionales (freezed `copyWith` no puede nullear un campo). Delega
/// en el controller (`insert` / `update`).
class AddDebtSheet extends ConsumerStatefulWidget {
  const AddDebtSheet({super.key, required this.householdId, this.editing});

  /// Hogar al que pertenece la deuda.
  final String householdId;

  /// Deuda a editar (null = alta).
  final Debt? editing;

  /// Presenta la hoja modal. Devuelve `true` si se guardó (el caller refresca).
  static Future<bool?> show(
    BuildContext context, {
    required String householdId,
    Debt? editing,
  }) {
    final c = context.colors;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AddDebtSheet(householdId: householdId, editing: editing),
    );
  }

  @override
  ConsumerState<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<AddDebtSheet> {
  final TextEditingController _creditorCtrl = TextEditingController();
  final TextEditingController _originalCtrl = TextEditingController();
  final TextEditingController _balanceCtrl = TextEditingController();
  final TextEditingController _rateCtrl = TextEditingController();
  final TextEditingController _monthlyCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  late DateTime _startDate;
  late DateTime _maturityDate;
  bool _hasMaturity = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    final Debt? e = widget.editing;
    if (e != null) {
      _creditorCtrl.text = e.creditor;
      _originalCtrl.text = _plain(e.originalAmount);
      _balanceCtrl.text = _plain(e.currentBalance);
      _rateCtrl.text = formatRate(e.annualRate);
      _monthlyCtrl.text =
          e.monthlyPayment != null ? _plain(e.monthlyPayment!) : '';
      _categoryCtrl.text = e.category ?? '';
      _noteCtrl.text = e.note ?? '';
      _startDate = e.startDate;
      _hasMaturity = e.maturityDate != null;
      _maturityDate = e.maturityDate ?? now;
    } else {
      _startDate = now;
      _maturityDate = DateTime(now.year + 1, now.month, now.day);
    }
    _creditorCtrl.addListener(_onChanged);
    _originalCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _creditorCtrl.removeListener(_onChanged);
    _originalCtrl.removeListener(_onChanged);
    _creditorCtrl.dispose();
    _originalCtrl.dispose();
    _balanceCtrl.dispose();
    _rateCtrl.dispose();
    _monthlyCtrl.dispose();
    _categoryCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Moneda base del hogar (cae a USD). En edición usamos la de la deuda.
  String get _currency =>
      widget.editing?.currency ??
      ref.read(currentHouseholdProvider).valueOrNull?.defaultCurrency ??
      'USD';

  /// Monto original parseado (> 0) o null.
  Decimal? get _parsedOriginal {
    final Decimal? d = Money.parse(_originalCtrl.text);
    if (d == null || d <= Decimal.zero) return null;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool canSave =
        _creditorCtrl.text.trim().isNotEmpty && _parsedOriginal != null;

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
                    _labeledField(
                      context,
                      label: 'ACREEDOR',
                      controller: _creditorCtrl,
                      hint: 'Ej. Banco, tarjeta, persona',
                      capitalize: true,
                    ),
                    const SizedBox(height: Insets.section),
                    _moneyField(
                      context,
                      label: 'MONTO ORIGINAL',
                      controller: _originalCtrl,
                    ),
                    const SizedBox(height: Insets.section),
                    _moneyField(
                      context,
                      label: 'SALDO ACTUAL',
                      controller: _balanceCtrl,
                      hint: 'Por defecto, el monto original',
                    ),
                    const SizedBox(height: Insets.section),
                    _rateField(context),
                    const SizedBox(height: Insets.section),
                    _moneyField(
                      context,
                      label: 'PAGO MENSUAL (OPCIONAL)',
                      controller: _monthlyCtrl,
                    ),
                    const SizedBox(height: Insets.section),
                    _dateField(
                      context,
                      label: 'FECHA DE INICIO',
                      date: _startDate,
                      onPick: (DateTime d) => setState(() => _startDate = d),
                    ),
                    const SizedBox(height: Insets.section),
                    _maturitySection(context),
                    const SizedBox(height: Insets.section),
                    _labeledField(
                      context,
                      label: 'CATEGORÍA (OPCIONAL)',
                      controller: _categoryCtrl,
                      hint: 'Ej. Préstamo personal',
                      capitalize: true,
                    ),
                    const SizedBox(height: Insets.section),
                    _labeledField(
                      context,
                      label: 'NOTA (OPCIONAL)',
                      controller: _noteCtrl,
                      hint: 'Detalle opcional',
                      capitalize: true,
                      maxLines: 3,
                    ),
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
        Icon(LucideIcons.arrowDownToLine, size: 20, color: c.brandPrimary),
        const SizedBox(width: Insets.md),
        Text(
          _isEditing ? 'Editar deuda' : 'Nueva deuda',
          style: AppText.h2(c.textPrimary),
        ),
      ],
    );
  }

  // ── Campos ────────────────────────────────────────────────────────────────

  /// Campo de texto con label uppercase.
  Widget _labeledField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hint,
    bool capitalize = false,
    int maxLines = 1,
  }) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TextField(
          controller: controller,
          style: AppText.body(c.textPrimary),
          textCapitalization: capitalize
              ? TextCapitalization.sentences
              : TextCapitalization.none,
          minLines: 1,
          maxLines: maxLines,
          decoration: _inputDecoration(context, hint: hint),
        ),
      ],
    );
  }

  /// Campo numérico de dinero (símbolo de moneda + input decimal).
  Widget _moneyField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppText.label(c.textMuted)),
            const Spacer(),
            Text(
              _currency,
              style: AppText.caption(c.textMuted)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppText.body(c.textPrimary),
          decoration: _inputDecoration(
            context,
            hint: hint ?? '0',
            prefix: Money.symbolFor(_currency),
          ),
        ),
      ],
    );
  }

  /// Campo de tasa anual (input decimal + sufijo %).
  Widget _rateField(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TASA ANUAL %', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TextField(
          controller: _rateCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppText.body(c.textPrimary),
          decoration: _inputDecoration(context, hint: '0', suffix: '%'),
        ),
      ],
    );
  }

  /// Tile de fecha que abre el `showDatePicker` Material.
  Widget _dateField(
    BuildContext context, {
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onPick,
  }) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            HapticFeedback.selectionClick();
            final DateTime now = DateTime.now();
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(now.year - 20),
              lastDate: DateTime(now.year + 30),
            );
            if (picked != null) onPick(picked);
          },
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
                Text(formatLongDate(date), style: AppText.body(c.textPrimary)),
                const Spacer(),
                Icon(LucideIcons.chevronRight, size: 16, color: c.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Sección de vencimiento: toggle + (si activo) el date picker.
  Widget _maturitySection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child:
                  Text('TIENE VENCIMIENTO', style: AppText.label(c.textMuted)),
            ),
            Switch(
              value: _hasMaturity,
              activeColor: c.brandPrimary,
              onChanged: (bool v) => setState(() => _hasMaturity = v),
            ),
          ],
        ),
        if (_hasMaturity) ...[
          const SizedBox(height: Insets.md),
          _dateField(
            context,
            label: 'FECHA DE VENCIMIENTO',
            date: _maturityDate,
            onPick: (DateTime d) => setState(() => _maturityDate = d),
          ),
        ],
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
        label: _saving
            ? 'Guardando…'
            : (_isEditing ? 'Guardar cambios' : 'Crear deuda'),
        icon: LucideIcons.check,
        onPressed: (canSave && !_saving) ? _save : null,
      ),
    );
  }

  /// Valida y guarda. Alta: setea `created_by`. Edición: reconstruye la deuda
  /// preservando los campos inmutables (para poder nullear opcionales).
  Future<void> _save() async {
    setState(() => _error = null);
    final Decimal? original = _parsedOriginal;
    if (original == null) {
      setState(() => _error = 'Ingresá un monto original válido mayor a cero.');
      return;
    }
    final String creditor = _creditorCtrl.text.trim();
    if (creditor.isEmpty) {
      setState(() => _error = 'Ingresá el acreedor.');
      return;
    }

    // Saldo actual: si está vacío, default al original (igual que iOS).
    final Decimal balance = Money.parse(_balanceCtrl.text) ?? original;
    final Decimal rate = Money.parse(_rateCtrl.text) ?? Decimal.zero;
    final Decimal? monthly = Money.parse(_monthlyCtrl.text);
    final String? category =
        _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim();
    final String? note =
        _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final DateTime? maturity = _hasMaturity ? _maturityDate : null;

    setState(() => _saving = true);
    try {
      final Debt? editing = widget.editing;
      if (editing != null) {
        // Reconstruimos para permitir vaciar opcionales (freezed copyWith no
        // puede nullear). Preservamos id/hogar/moneda/original/inicio/estado/
        // autor/created_at; updated_at lo regenera la DB.
        final Debt updated = Debt(
          id: editing.id,
          householdId: editing.householdId,
          creditor: creditor,
          originalAmount: editing.originalAmount,
          currentBalance: balance,
          annualRate: rate,
          monthlyPayment: monthly,
          currency: editing.currency,
          startDate: editing.startDate,
          maturityDate: maturity,
          category: category,
          note: note,
          status: editing.status,
          createdBy: editing.createdBy,
          createdAt: editing.createdAt,
        );
        await ref.read(debtsControllerProvider.notifier).updateDebt(updated);
      } else {
        final String? userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          setState(() {
            _saving = false;
            _error = 'No encontramos tu sesión. Reintentá.';
          });
          return;
        }
        // `id` vacío → el repo lo remueve del payload (la DB genera el real).
        final Debt debt = Debt(
          id: '',
          householdId: widget.householdId,
          creditor: creditor,
          originalAmount: original,
          currentBalance: balance,
          annualRate: rate,
          monthlyPayment: monthly,
          currency: _currency,
          startDate: _startDate,
          maturityDate: maturity,
          category: category,
          note: note,
          status: DebtStatus.active,
          createdBy: userId,
        );
        await ref.read(debtsControllerProvider.notifier).insert(debt);
      }
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No pudimos guardar la deuda. Reintentá.';
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Decoración de input consistente (surface inset + squircle, sin borde),
  /// con prefijo/sufijo opcional (símbolo de moneda / %).
  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    String? prefix,
    String? suffix,
  }) {
    final c = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.body(c.textDim),
      prefixText: prefix,
      prefixStyle: AppText.body(c.textMuted),
      suffixText: suffix,
      suffixStyle: AppText.body(c.textMuted),
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

  /// Representación plana de un `Decimal` para pre-cargar el input en edición
  /// (sin separadores de miles; el parser tolera ambas convenciones).
  static String _plain(Decimal d) => d.toString();
}
