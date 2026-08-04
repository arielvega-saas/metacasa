import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/supabase_init.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/fx_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../../home/application/home_controller.dart';
import '../application/transactions_controller.dart';
import '../receipt/receipt_scan_flow.dart';
import 'edit_transaction_sheet.dart' show TxChipRow, TxDateField, TxTypeToggle;

/// Hoja "Nuevo movimiento" — espejo de `AddTransactionView` (iOS). El shell la
/// abre cuando se toca el tab central "Agregar".
///
/// Flujo (de arriba a abajo), 1:1 con iOS:
///   1. Toggle Gasto/Ingreso.
///   2. Monto hero (serif grande) + quick-amount chips (+1k/+5k/+10k/+50k +
///      Limpiar).
///   3. Expander "Usar otra moneda": moneda alternativa + tasa de cambio manual
///      → guarda el monto convertido a base + `currency_original`.
///   4. Grilla de categorías (del catálogo mergeado por tipo) + subcategorías.
///   5. Chips de cuenta (Hogar = sin cuenta, o una cuenta concreta).
///   6. Nota + fecha.
///   7. Botón guardar (sticky abajo). Valida monto > 0; inserta y refresca
///      lista + dashboard; haptic de éxito.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  /// Presenta la hoja modal con el look del design system.
  static Future<void> show(BuildContext context) {
    final c = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const AddTransactionSheet(),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  // Monedas comunes para el selector de moneda alternativa (1:1 con iOS).
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

  // Quick-amount chips (1:1 con iOS).
  static const List<int> _quickAmounts = <int>[1000, 5000, 10000, 50000];

  TxType _type = TxType.gasto;
  String? _category;
  String? _subcategory;
  String? _accountId; // null = Hogar (sin cuenta), como iOS (accountId nil)
  DateTime _date = DateTime.now();

  // Multi-moneda inline.
  bool _useAlternateCurrency = false;
  String _alternateCurrency = 'USD';
  final TextEditingController _fxCtrl = TextEditingController();
  Map<String, Decimal> _knownRates = <String, Decimal>{};

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  CategoriesData? _categoriesData;
  List<Account> _accounts = const <Account>[];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Re-render del preview/quick-amounts al tipear el monto.
    _amountCtrl.addListener(_onAmountChanged);
    _loadAux();
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _fxCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  /// Carga categorías + cuentas + tasas FX conocidas del hogar.
  Future<void> _loadAux() async {
    final String? householdId =
        ref.read(currentHouseholdIdProvider).valueOrNull;
    if (householdId == null) return;
    final CategoriesBlob? blob =
        await ref.read(categoryRepositoryProvider).fetch(householdId);
    final List<Account> accounts =
        await ref.read(accountRepositoryProvider).fetchAll(householdId);
    final Map<String, FXRate> rates =
        await ref.read(fxRepositoryProvider).getRates(householdId);
    if (!mounted) return;
    setState(() {
      _categoriesData = blob?.data;
      _accounts = accounts;
      _knownRates = rates.map<String, Decimal>(
        (String code, FXRate r) => MapEntry<String, Decimal>(code, r.rate),
      );
      // Default de categoría: la primera del catálogo del tipo actual.
      _category ??= _categories.isNotEmpty ? _categories.first.name : null;
    });
  }

  /// Categorías disponibles para el tipo actual (defaults + custom mergeados).
  List<CategoryItem> get _categories =>
      TransactionsController.mergedCategories(_categoriesData, _type);

  /// Subcategorías de la categoría seleccionada.
  List<String> get _subcategories {
    for (final CategoryItem ci in _categories) {
      if (ci.name == _category) return ci.subcategories ?? const <String>[];
    }
    return const <String>[];
  }

  /// Moneda base del hogar (cae a USD).
  String get _householdCurrency =>
      ref.read(currentHouseholdProvider).valueOrNull?.defaultCurrency ?? 'USD';

  /// Monto parseado (> 0) o null.
  Decimal? get _parsedAmount {
    final Decimal? d = Money.parse(_amountCtrl.text);
    if (d == null || d <= Decimal.zero) return null;
    return d;
  }

  /// Tasa efectiva: la tipeada (si > 0), si no la conocida, si no 1.
  Decimal get _effectiveFxRate {
    final Decimal? parsed = Money.parse(_fxCtrl.text);
    if (parsed != null && parsed > Decimal.zero) return parsed;
    if (_useAlternateCurrency && _knownRates.containsKey(_alternateCurrency)) {
      return _knownRates[_alternateCurrency]!;
    }
    return Decimal.one;
  }

  /// Monto convertido a la base del hogar (si el toggle está on y la moneda
  /// difiere). Espejo del `convertedAmount` de iOS.
  Decimal? get _convertedAmount {
    if (!_useAlternateCurrency || _alternateCurrency == _householdCurrency) {
      return null;
    }
    final Decimal? amt = _parsedAmount;
    if (amt == null) return null;
    return amt * _effectiveFxRate;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool canSave = _parsedAmount != null && _category != null;

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
                        Icon(LucideIcons.plusCircle,
                            size: 20, color: c.brandPrimary),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Text('Nuevo movimiento',
                              style: AppText.h2(c.textPrimary)),
                        ),
                        _scanReceiptPill(context),
                      ],
                    ),
                    const SizedBox(height: Insets.section),
                    TxTypeToggle(type: _type, onChanged: _onTypeChanged),
                    const SizedBox(height: Insets.section),
                    _amountField(context),
                    const SizedBox(height: Insets.card),
                    _currencyExpander(context),
                    const SizedBox(height: Insets.section),
                    _categorySection(context),
                    const SizedBox(height: Insets.section),
                    _accountSection(context),
                    const SizedBox(height: Insets.section),
                    Text('NOTA', style: AppText.label(c.textMuted)),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: _noteCtrl,
                      style: AppText.body(c.textPrimary),
                      decoration:
                          _inputDecoration(context, hint: 'Detalle (opcional)'),
                    ),
                    const SizedBox(height: Insets.section),
                    Text('FECHA', style: AppText.label(c.textMuted)),
                    const SizedBox(height: Insets.md),
                    TxDateField(
                      date: _date,
                      onChanged: (DateTime d) => setState(() => _date = d),
                    ),
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
                label: _saving
                    ? 'Guardando…'
                    : (_type == TxType.gasto
                        ? 'Guardar gasto'
                        : 'Guardar ingreso'),
                icon: LucideIcons.check,
                onPressed: (canSave && !_saving) ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Scan receipt ────────────────────────────────────────────────────────────

  /// Acción secundaria discreta "Escanear recibo" (pill sage outline) junto al
  /// título: dispara el flujo de visión (cámara/galería → revisión → alta).
  Widget _scanReceiptPill(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _saving ? null : () => ReceiptScanFlow.start(context, ref),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Insets.card, vertical: 6),
        decoration: ShapeDecoration(
          color: c.brandPrimary.withValues(alpha: 0.10),
          shape: StadiumBorder(
            side: BorderSide(color: c.brandPrimary.withValues(alpha: 0.30)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.scanLine, size: 14, color: c.brandPrimary),
            const SizedBox(width: Insets.sm),
            Text(
              'Escanear',
              style: AppText.caption(c.brandPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // ── Amount ────────────────────────────────────────────────────────────────

  /// Campo de monto: label con código de moneda, hero serif con tinte por tipo,
  /// quick-amount chips y preview en tiempo real.
  Widget _amountField(BuildContext context) {
    final c = context.colors;
    final String currency =
        _useAlternateCurrency ? _alternateCurrency : _householdCurrency;
    final Color tint = _type == TxType.gasto ? c.brandDanger : c.brandSuccess;
    final Decimal? amount = _parsedAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('MONTO', style: AppText.label(c.textMuted)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: 2),
              decoration: ShapeDecoration(
                color: c.appSurfaceInset,
                shape: const StadiumBorder(),
              ),
              child: Text(
                currency,
                style: AppText.caption(c.textMuted)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        // Card del monto: gradiente sutil sage→champagne, hero serif tintado.
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
                Money.symbolFor(currency),
                style: AppText.serifDisplay(
                  amount == null ? c.textDim : tint,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppText.serifHero(amount == null ? c.textDim : tint),
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
        const SizedBox(height: Insets.md),
        // Quick-amount chips + Limpiar.
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final int v in _quickAmounts) ...[
                _quickAmountChip(context, v),
                const SizedBox(width: Insets.md),
              ],
              _clearChip(context),
            ],
          ),
        ),
        // Preview en tiempo real.
        if (amount != null) ...[
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Icon(LucideIcons.check, size: 14, color: c.brandSuccess),
              const SizedBox(width: Insets.sm),
              Text(
                Money.format(amount,
                    currencyCode: currency,
                    style: MoneyStyle.auto,
                    locale: _locale(context)),
                style: AppText.caption(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Chip "+1k / +5k / …": suma el valor al monto actual.
  Widget _quickAmountChip(BuildContext context, int value) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        final Decimal current = Money.parse(_amountCtrl.text) ?? Decimal.zero;
        final Decimal next = current + Decimal.fromInt(value);
        _amountCtrl.text = next.toString().endsWith('.0')
            ? next.toBigInt().toString()
            : next.toString();
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        decoration: ShapeDecoration(
          color: c.appSurface,
          shape: StadiumBorder(side: BorderSide(color: c.appBorder)),
        ),
        child: Text(
          '+${_compact(value)}',
          style: AppText.caption(c.textPrimary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Chip "Limpiar": vacía el monto.
  Widget _clearChip(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _amountCtrl.clear();
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        decoration: ShapeDecoration(
          color: c.brandDanger.withValues(alpha: 0.10),
          shape: StadiumBorder(
            side: BorderSide(color: c.brandDanger.withValues(alpha: 0.30)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.x, size: 12, color: c.brandDanger),
            const SizedBox(width: Insets.xs),
            Text(
              'Limpiar',
              style: AppText.caption(c.brandDanger)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Currency expander ───────────────────────────────────────────────────────

  /// Expander "Usar otra moneda": toggle + (si on) selector de moneda + tasa de
  /// cambio manual + preview del convertido. Espejo del `currencyToggleField`.
  Widget _currencyExpander(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.repeat, size: 16, color: c.brandPrimary),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                'Usar otra moneda',
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: _useAlternateCurrency,
              activeColor: c.brandPrimary,
              onChanged: (bool v) {
                HapticFeedback.selectionClick();
                setState(() {
                  _useAlternateCurrency = v;
                  // Pre-cargamos la tasa conocida al activar, si existe.
                  if (v && _knownRates.containsKey(_alternateCurrency)) {
                    _fxCtrl.text = _knownRates[_alternateCurrency]!.toString();
                  }
                });
              },
            ),
          ],
        ),
        if (_useAlternateCurrency) ...[
          const SizedBox(height: Insets.md),
          Container(
            padding: const EdgeInsets.all(Insets.card),
            decoration: BoxDecoration(
              color: c.appSurfaceInset,
              borderRadius: BorderRadius.circular(Radii.input),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector de moneda.
                Row(
                  children: [
                    Text('Moneda',
                        style: AppText.caption(c.textMuted)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _CurrencyMenu(
                      value: _alternateCurrency,
                      options: _commonCurrencies,
                      onSelected: (String code) {
                        setState(() {
                          _alternateCurrency = code;
                          if (_knownRates.containsKey(code)) {
                            _fxCtrl.text = _knownRates[code]!.toString();
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                // Tasa de cambio manual.
                Row(
                  children: [
                    Text('Tasa',
                        style: AppText.caption(c.textMuted)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('1 $_alternateCurrency = ',
                        style: AppText.caption(c.textMuted)),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _fxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.right,
                        onChanged: (_) => setState(() {}),
                        style: AppText.body(c.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: '0',
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.xs),
                    Text(_householdCurrency,
                        style: AppText.caption(c.textMuted)),
                  ],
                ),
                // Preview del convertido.
                if (_convertedAmount != null) ...[
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Icon(LucideIcons.arrowDownLeft,
                          size: 14, color: c.brandSuccess),
                      const SizedBox(width: Insets.sm),
                      Text('Equivale a ', style: AppText.caption(c.textMuted)),
                      Text(
                        Money.format(_convertedAmount!,
                            currencyCode: _householdCurrency,
                            style: MoneyStyle.auto,
                            locale: _locale(context)),
                        style: AppText.caption(c.textPrimary)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ] else if (_parsedAmount != null) ...[
                  const SizedBox(height: Insets.md),
                  Text(
                    'Cargá la tasa para ver el equivalente en $_householdCurrency.',
                    style: AppText.caption(c.textDim),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Category ────────────────────────────────────────────────────────────────

  Widget _categorySection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CATEGORÍA', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TxChipRow(
          children: _categories
              .map((CategoryItem ci) => MCChip(
                    emoji: ci.emoji ?? CategoryCatalog.emojiFor(ci.name),
                    label: ci.name,
                    selected: _category == ci.name,
                    onTap: () => setState(() {
                      _category = ci.name;
                      _subcategory = null;
                    }),
                  ))
              .toList(),
        ),
        if (_subcategories.isNotEmpty) ...[
          const SizedBox(height: Insets.card),
          Text('SUBCATEGORÍA', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.md),
          TxChipRow(
            children: <Widget>[
              MCChip(
                label: 'Ninguna',
                selected: _subcategory == null,
                onTap: () => setState(() => _subcategory = null),
              ),
              ..._subcategories.map((String s) => MCChip(
                    label: s,
                    selected: _subcategory == s,
                    onTap: () => setState(() => _subcategory = s),
                  )),
            ],
          ),
        ],
      ],
    );
  }

  // ── Account ───────────────────────────────────────────────────────────────

  Widget _accountSection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CUENTA', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TxChipRow(
          children: <Widget>[
            // Hogar = sin cuenta (accountId nil), default igual que iOS.
            MCChip(
              emoji: '🏠',
              label: 'Hogar',
              selected: _accountId == null,
              onTap: () => setState(() => _accountId = null),
            ),
            ..._accounts.map((Account a) => MCChip(
                  label: a.name,
                  selected: _accountId == a.id,
                  onTap: () => setState(() => _accountId = a.id),
                )),
          ],
        ),
      ],
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onTypeChanged(TxType t) {
    setState(() {
      _type = t;
      // Si la categoría no existe para el nuevo tipo, caemos a la primera.
      final List<CategoryItem> cats = _categories;
      if (_category == null ||
          !cats.any((CategoryItem ci) => ci.name == _category)) {
        _category = cats.isNotEmpty ? cats.first.name : null;
      }
      _subcategory = null;
    });
  }

  /// Valida e inserta el movimiento. Manda `amount` convertido a base cuando se
  /// usa moneda alternativa (+ `currency_original`), 1:1 con el `submit` de iOS.
  Future<void> _save() async {
    setState(() => _error = null);
    final Decimal? amount = _parsedAmount;
    if (amount == null) {
      setState(() => _error = 'Ingresá un monto válido mayor a cero.');
      return;
    }
    final String? category = _category;
    if (category == null) {
      setState(() => _error = 'Elegí una categoría.');
      return;
    }
    final String? householdId =
        ref.read(currentHouseholdIdProvider).valueOrNull;
    final String? userId = supabase.auth.currentUser?.id;
    if (householdId == null || userId == null) {
      setState(() => _error = 'No encontramos tu hogar. Reintentá.');
      return;
    }

    setState(() => _saving = true);
    final String note = _noteCtrl.text.trim();
    final NewTransactionInput input = NewTransactionInput(
      householdId: householdId,
      userId: userId,
      accountId: _accountId,
      type: _type,
      // `amount` va SIEMPRE en la base del hogar. El monto tipeado y la tasa se
      // guardan aparte: sin ellos el original se perdía y la lista mostraba
      // "US$ 150.000" para un gasto de US$ 100 — el monto base con la etiqueta
      // de la moneda extranjera. Invariante: amount == amountOriginal * fxRateToBase.
      amount: _useAlternateCurrency ? (_convertedAmount ?? amount) : amount,
      amountOriginal: amount,
      currencyOriginal: _useAlternateCurrency ? _alternateCurrency : null,
      fxRateToBase: _useAlternateCurrency ? _effectiveFxRate : Decimal.one,
      category: category,
      subcategory: _subcategory,
      note: note.isEmpty ? null : note,
      date: _date,
    );

    try {
      await ref.read(transactionRepositoryProvider).insert(input);
      await HapticFeedback.mediumImpact();
      // Refresca lista + dashboard (mueve totales/saldos).
      ref.invalidate(transactionsControllerProvider);
      ref.invalidate(homeControllerProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No pudimos guardar el movimiento. Reintentá.';
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  /// Locale ICU del contexto (es_AR) para `Money.format`.
  String _locale(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag().replaceAll('-', '_');

  /// Etiqueta compacta de un valor entero para el chip (+1k / +50k).
  static String _compact(int value) {
    if (value >= 1000 && value % 1000 == 0) return '${value ~/ 1000}k';
    return '$value';
  }
}

/// Menú desplegable de moneda alternativa (chevron + código). Privado a la hoja.
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
