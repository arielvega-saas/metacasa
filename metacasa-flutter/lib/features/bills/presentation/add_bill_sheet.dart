import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/supabase_init.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../../transactions/presentation/edit_transaction_sheet.dart'
    show TxChipRow, TxDateField;
import '../application/bills_controller.dart';

/// Opción de recurrencia para el vencimiento. `null` (Único) = sin
/// `recurrence_type`; el resto mapea al string que guarda la columna
/// `bills.recurrence_type`.
enum _Recurrence {
  none(null, 'Único'),
  weekly('weekly', 'Semanal'),
  monthly('monthly', 'Mensual'),
  yearly('yearly', 'Anual');

  const _Recurrence(this.wire, this.label);

  /// Valor que se guarda en `recurrence_type` (null para "Único").
  final String? wire;

  /// Etiqueta legible (es-AR).
  final String label;
}

/// Hoja "Nuevo vencimiento" — espejo de `AddBillView` (iOS), adaptada al schema
/// REAL de `bills` (sin `note`/`recurring`; con `recurrence_type` +
/// `reminder_days`).
///
/// Flujo (de arriba a abajo):
///   1. Título.
///   2. Monto hero (serif, coral) + selector de moneda.
///   3. Fecha de vencimiento.
///   4. Categoría opcional (chips del catálogo de gastos del hogar).
///   5. Recurrencia (Único / Semanal / Mensual / Anual).
///   6. Recordatorio (días antes: sin / 1 / 3 / 7).
///   7. Botón guardar (sticky abajo). Valida título + monto > 0; inserta vía el
///      controller (el repo inyecta `user_id`) y cierra con `true`.
class AddBillSheet extends ConsumerStatefulWidget {
  const AddBillSheet({super.key, required this.householdId});

  /// Hogar al que pertenece el vencimiento (se setea en `household_id`).
  final String householdId;

  /// Presenta la hoja modal con el look del design system. Devuelve `true` si se
  /// guardó (para que el caller refresque).
  static Future<bool?> show(BuildContext context, String householdId) {
    final c = context.colors;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AddBillSheet(householdId: householdId),
    );
  }

  @override
  ConsumerState<AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends ConsumerState<AddBillSheet> {
  // Monedas comunes para el selector (mismo set que la hoja de movimientos).
  static const List<String> _commonCurrencies = <String>[
    'USD',
    'EUR',
    'ARS',
    'BRL',
    'MXN',
    'CLP',
    'UYU',
    'COP',
    'PEN',
    'GBP',
  ];

  // Días de recordatorio ofrecidos (0 = sin recordatorio).
  static const List<int> _reminderOptions = <int>[0, 1, 3, 7];

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();

  DateTime _dueDate = DateTime.now();
  String? _category; // null = sin categoría
  late String _currency;
  _Recurrence _recurrence = _Recurrence.none;
  int _reminderDays = 3;

  List<CategoryItem> _categories = const <CategoryItem>[];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default de moneda: la base del hogar (cae a USD).
    _currency =
        ref.read(currentHouseholdProvider).valueOrNull?.defaultCurrency ??
            'USD';
    _amountCtrl.addListener(_onAmountChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  /// Carga las categorías de GASTO del hogar (defaults + custom) para los chips.
  Future<void> _loadCategories() async {
    final CategoriesBlob? blob =
        await ref.read(categoryRepositoryProvider).fetch(widget.householdId);
    if (!mounted) return;
    setState(() {
      final List<CategoryItem> custom =
          blob?.data.gastos ?? const <CategoryItem>[];
      // Mezcla defaults + custom, deduplicando por nombre (los custom pisan).
      final Map<String, CategoryItem> byName = <String, CategoryItem>{};
      for (final String name in CategoryCatalog.defaultGastos) {
        byName[name] = CategoryItem(
          name: name,
          emoji: CategoryCatalog.emojiFor(name),
        );
      }
      for (final CategoryItem ci in custom) {
        byName[ci.name] = ci;
      }
      _categories = byName.values.toList();
    });
  }

  /// Monto parseado (> 0) o null.
  Decimal? get _parsedAmount {
    final Decimal? d = Money.parse(_amountCtrl.text);
    if (d == null || d <= Decimal.zero) return null;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool canSave =
        _titleCtrl.text.trim().isNotEmpty && _parsedAmount != null;

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
                    Row(
                      children: [
                        Icon(LucideIcons.calendarClock,
                            size: 20, color: c.brandPrimary),
                        const SizedBox(width: Insets.md),
                        Text('Nuevo vencimiento',
                            style: AppText.h2(c.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: Insets.section),
                    // Título.
                    Text('TÍTULO', style: AppText.label(c.textMuted)),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: _titleCtrl,
                      style: AppText.body(c.textPrimary),
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration(
                        context,
                        hint: 'Alquiler, tarjeta, luz…',
                      ),
                    ),
                    const SizedBox(height: Insets.section),
                    _amountField(context),
                    const SizedBox(height: Insets.section),
                    // Fecha de vencimiento.
                    Text('VENCE EL', style: AppText.label(c.textMuted)),
                    const SizedBox(height: Insets.md),
                    TxDateField(
                      date: _dueDate,
                      onChanged: (DateTime d) => setState(() => _dueDate = d),
                    ),
                    const SizedBox(height: Insets.section),
                    _categorySection(context),
                    const SizedBox(height: Insets.section),
                    _recurrenceSection(context),
                    const SizedBox(height: Insets.section),
                    _reminderSection(context),
                    if (_error != null) ...[
                      const SizedBox(height: Insets.card),
                      Text(_error!, style: AppText.caption(c.brandDanger)),
                    ],
                  ],
                ),
              ),
            ),
            // Barra de guardado (sticky abajo) con divider superior.
            Container(
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
                label: _saving ? 'Guardando…' : 'Guardar vencimiento',
                icon: LucideIcons.check,
                onPressed: (canSave && !_saving) ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Amount ──────────────────────────────────────────────────────────────

  /// Campo de monto: label + selector de moneda, hero serif coral (los
  /// vencimientos son siempre gastos).
  Widget _amountField(BuildContext context) {
    final c = context.colors;
    final Decimal? amount = _parsedAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('MONTO', style: AppText.label(c.textMuted)),
            const Spacer(),
            _CurrencyMenu(
              value: _currency,
              options: _commonCurrencies,
              onSelected: (String code) => setState(() => _currency = code),
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
                c.brandDanger.withValues(alpha: 0.10),
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
                  amount == null ? c.textDim : c.brandDanger,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppText.serifHero(
                      amount == null ? c.textDim : c.brandDanger),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: AppText.serifHero(c.textDim),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Category ────────────────────────────────────────────────────────────

  Widget _categorySection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CATEGORÍA', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TxChipRow(
          children: <Widget>[
            // "Sin categoría" como primera opción (la categoría es opcional).
            MCChip(
              label: 'Sin categoría',
              selected: _category == null,
              onTap: () => setState(() => _category = null),
            ),
            ..._categories.map((CategoryItem ci) => MCChip(
                  emoji: ci.emoji ?? CategoryCatalog.emojiFor(ci.name),
                  label: ci.name,
                  selected: _category == ci.name,
                  onTap: () => setState(() => _category = ci.name),
                )),
          ],
        ),
      ],
    );
  }

  // ── Recurrence ──────────────────────────────────────────────────────────

  Widget _recurrenceSection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REPETICIÓN', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TxChipRow(
          children: _Recurrence.values
              .map((_Recurrence r) => MCChip(
                    label: r.label,
                    selected: _recurrence == r,
                    onTap: () => setState(() => _recurrence = r),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Reminder ──────────────────────────────────────────────────────────────

  Widget _reminderSection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECORDATORIO', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TxChipRow(
          children: _reminderOptions
              .map((int days) => MCChip(
                    label: _reminderLabel(days),
                    selected: _reminderDays == days,
                    onTap: () => setState(() => _reminderDays = days),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Valida e inserta el vencimiento. El repo inyecta `user_id`; acá completamos
  /// `household_id`, fecha, moneda, categoría, recurrencia y recordatorio.
  Future<void> _save() async {
    setState(() => _error = null);
    final String title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Poné un título para el vencimiento.');
      return;
    }
    final Decimal? amount = _parsedAmount;
    if (amount == null) {
      setState(() => _error = 'Ingresá un monto válido mayor a cero.');
      return;
    }
    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _error = 'No encontramos tu sesión. Reintentá.');
      return;
    }

    setState(() => _saving = true);
    // `id` es server-generated: el repo lo descarta en el payload de insert, así
    // que un placeholder vacío acá es seguro (mismo patrón que los inputs de iOS).
    final Bill bill = Bill(
      id: '',
      userId: userId,
      householdId: widget.householdId,
      title: title,
      amount: amount,
      currency: _currency,
      dueDate: _dueDate,
      category: _category ?? '',
      recurrenceType: _recurrence.wire,
      reminderDays: _reminderDays == 0 ? null : _reminderDays,
    );

    try {
      await ref.read(billsControllerProvider.notifier).addBill(bill);
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No pudimos guardar el vencimiento. Reintentá.';
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Etiqueta del chip de recordatorio.
  static String _reminderLabel(int days) {
    if (days == 0) return 'Sin recordatorio';
    return days == 1 ? '1 día antes' : '$days días antes';
  }

  /// Decoración de input consistente (surface inset + squircle).
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
}

/// Menú desplegable de moneda (chevron + código). Privado a la hoja.
class _CurrencyMenu extends StatelessWidget {
  const _CurrencyMenu({
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<String>(
      onSelected: (String code) {
        HapticFeedback.selectionClick();
        onSelected(code);
      },
      color: c.appSurface,
      itemBuilder: (_) => options
          .map((String code) => PopupMenuItem<String>(
                value: code,
                child: Row(
                  children: [
                    if (code == value)
                      Icon(LucideIcons.check, size: 16, color: c.brandPrimary)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: Insets.md),
                    Text(code, style: AppText.body(c.textPrimary)),
                  ],
                ),
              ))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppText.body(c.brandPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: Insets.xs),
          Icon(LucideIcons.chevronDown, size: 14, color: c.brandPrimary),
        ],
      ),
    );
  }
}
