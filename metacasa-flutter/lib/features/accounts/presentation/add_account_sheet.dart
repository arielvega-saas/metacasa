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
import '../../../data/repositories/account_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../../auth/presentation/auth_field.dart';
import 'account_type_icon.dart';

/// Hoja "Nueva cuenta" / "Nueva tarjeta" — espejo de `AddAccountView` (iOS).
///
/// Form con: nombre, tipo (checking/savings/cash/credit_card/investment/loan/
/// other), moneda, institución (opcional), saldo inicial (oculto + forzado a 0
/// cuando es tarjeta) y pertenencia (personal/compartida/externa). Cuando el
/// tipo es `credit_card` aparece la sección de tarjeta: límite, día de cierre,
/// día de vencimiento, interés mensual %, mínimo a pagar % y red.
///
/// En guardar: `insert(Account)` (con `created_by` = usuario actual) y, si es
/// tarjeta, `upsertCard(CreditCardDetails)`. Devuelve `true` por el `Navigator`
/// si guardó (el caller refresca la lista).
class AddAccountSheet extends ConsumerStatefulWidget {
  const AddAccountSheet({super.key, required this.householdId});

  /// Hogar al que se agrega la cuenta.
  final String householdId;

  /// Presenta la hoja como modal full-height. Resuelve a `true` si se guardó.
  static Future<bool?> show(BuildContext context, String householdId) {
    final c = context.colors;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AddAccountSheet(householdId: householdId),
    );
  }

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final _name = TextEditingController();
  final _institution = TextEditingController();
  final _initialBalance = TextEditingController();

  // Campos de tarjeta de crédito.
  final _creditLimit = TextEditingController();
  final _interestRate = TextEditingController();
  final _minPaymentPct = TextEditingController(text: '5');

  AccountType _type = AccountType.checking;
  AccountOwnership _ownership = AccountOwnership.personal;
  CardNetwork _network = CardNetwork.visa;
  int _statementDay = 1;
  int _dueDay = 15;
  late String _currency;

  bool _loading = false;
  String? _error;
  bool _currencyInitFromHousehold = false;

  bool get _isCreditCard => _type == AccountType.creditCard;

  @override
  void initState() {
    super.initState();
    // Default provisional; se reemplaza por la moneda del hogar en cuanto el
    // provider resuelve (ver build).
    _currency = 'USD';
    _name.addListener(_onChanged);
    _creditLimit.addListener(_onChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _initialBalance.dispose();
    _creditLimit.dispose();
    _interestRate.dispose();
    _minPaymentPct.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Validez del form: nombre no vacío y, si es tarjeta, límite > 0 (espejo del
  /// `isValid` de iOS).
  bool get _isValid {
    if (_name.text.trim().isEmpty) return false;
    if (_isCreditCard) {
      final Decimal? limit = Money.parse(_creditLimit.text);
      return limit != null && limit > Decimal.zero;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_loading || !_isValid) return;
    FocusScope.of(context).unfocus();

    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _error = 'Sesión no disponible.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final AccountRepository repo = ref.read(accountRepositoryProvider);
    try {
      // Saldo inicial: 0 forzado para tarjetas (la deuda se modela vía
      // transacciones/resumen), parse del campo para el resto. Igual que iOS.
      final Decimal starting = _isCreditCard
          ? Decimal.zero
          : (Money.parse(_initialBalance.text) ?? Decimal.zero);

      // `id` placeholder: el repo lo remueve del payload antes de insertar (la
      // DB genera el real). `created_by` = usuario actual (lo pide el modelo).
      final Account draft = Account(
        id: '',
        householdId: widget.householdId,
        name: _name.text.trim(),
        type: _type,
        currency: _currency.toUpperCase(),
        startingBalance: starting,
        institution:
            _institution.text.trim().isEmpty ? null : _institution.text.trim(),
        displayOrder: 0,
        isActive: true,
        ownership: _ownership,
        createdBy: userId,
      );

      final Account saved = await repo.insert(draft);

      if (_isCreditCard) {
        final CreditCardDetails card = CreditCardDetails(
          accountId: saved.id,
          creditLimit: Money.parse(_creditLimit.text) ?? Decimal.zero,
          statementDay: _statementDay,
          dueDay: _dueDay,
          interestRateMonthly: Money.parse(_interestRate.text) ?? Decimal.zero,
          minimumPaymentPct:
              Money.parse(_minPaymentPct.text) ?? Decimal.fromInt(5),
          network: _network,
        );
        await repo.upsertCard(card);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'No se pudo guardar la cuenta. Probá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Preseleccionar la moneda del hogar (una sola vez), igual que el `onAppear`
    // de iOS que copia `household.defaultCurrency` si seguía en el default.
    final String? householdCurrency =
        ref.watch(currentHouseholdProvider).valueOrNull?.defaultCurrency;
    if (!_currencyInitFromHousehold &&
        householdCurrency != null &&
        householdCurrency.isNotEmpty) {
      _currency = householdCurrency;
      _currencyInitFromHousehold = true;
    }

    return SafeArea(
      child: Padding(
        // Empuja el contenido por encima del teclado.
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
              // Encabezado: cambia entre cuenta/tarjeta según el tipo.
              Row(
                children: [
                  Icon(
                    _isCreditCard ? LucideIcons.creditCard : LucideIcons.wallet,
                    size: 20,
                    color: c.brandPrimary,
                  ),
                  const SizedBox(width: Insets.md),
                  Text(
                    _isCreditCard ? 'Nueva tarjeta' : 'Nueva cuenta',
                    style: AppText.h2(c.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: Insets.section),

              AuthTextField(
                label: 'Nombre',
                controller: _name,
                textCapitalization: TextCapitalization.words,
                enabled: !_loading,
              ),
              const SizedBox(height: Insets.section),

              _TypePicker(
                value: _type,
                enabled: !_loading,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: Insets.section),

              _CurrencyDropdown(
                value: _currency,
                enabled: !_loading,
                onChanged: (v) => setState(() => _currency = v),
              ),
              const SizedBox(height: Insets.section),

              AuthTextField(
                label: 'Institución (opcional)',
                controller: _institution,
                textCapitalization: TextCapitalization.words,
                enabled: !_loading,
              ),

              // Saldo inicial: solo para cuentas no-tarjeta (la tarjeta arranca
              // en 0 forzado).
              if (!_isCreditCard) ...[
                const SizedBox(height: Insets.section),
                AuthTextField(
                  label: 'Saldo inicial',
                  controller: _initialBalance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  enabled: !_loading,
                ),
              ],

              // Sección de tarjeta de crédito.
              if (_isCreditCard) ...[
                const SizedBox(height: Insets.section),
                _CardSection(
                  enabled: !_loading,
                  limitController: _creditLimit,
                  interestController: _interestRate,
                  minPctController: _minPaymentPct,
                  statementDay: _statementDay,
                  dueDay: _dueDay,
                  network: _network,
                  onStatementDay: (v) => setState(() => _statementDay = v),
                  onDueDay: (v) => setState(() => _dueDay = v),
                  onNetwork: (v) => setState(() => _network = v),
                ),
              ],

              const SizedBox(height: Insets.section),
              _OwnershipPicker(
                value: _ownership,
                enabled: !_loading,
                onChanged: (o) => setState(() => _ownership = o),
              ),

              if (_error != null) ...[
                const SizedBox(height: Insets.section),
                _MessageCard(message: _error!, color: c.brandDanger),
              ],

              const SizedBox(height: Insets.cardLg),
              MCPrimaryButton(
                label: _loading ? 'Guardando…' : 'Guardar',
                onPressed: (_loading || !_isValid) ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Type picker ───────────────────────────────

/// Selector de tipo de cuenta: chips horizontales (ícono + label) con el del
/// design system (`MCChip`). Mapea el ícono por tipo vía [accountTypeIcon].
class _TypePicker extends StatelessWidget {
  const _TypePicker({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final AccountType value;
  final ValueChanged<AccountType> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TIPO', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        Wrap(
          spacing: Insets.md,
          runSpacing: Insets.md,
          children: AccountType.values.map((AccountType t) {
            return MCChip(
              label: t.label,
              icon: accountTypeIcon(t),
              selected: t == value,
              onTap: enabled ? () => onChanged(t) : () {},
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Ownership ─────────────────────────────────

/// Selector de pertenencia (personal/compartida/externa) con chips.
class _OwnershipPicker extends StatelessWidget {
  const _OwnershipPicker({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final AccountOwnership value;
  final ValueChanged<AccountOwnership> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PERTENENCIA', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        Wrap(
          spacing: Insets.md,
          runSpacing: Insets.md,
          children: AccountOwnership.values.map((AccountOwnership o) {
            return MCChip(
              label: o.label,
              icon: ownershipIcon(o),
              selected: o == value,
              onTap: enabled ? () => onChanged(o) : () {},
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Card section ──────────────────────────────

/// Sección de campos de tarjeta de crédito: límite, días de cierre/vencimiento
/// (steppers 1–31), interés mensual %, mínimo %, y red.
class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.enabled,
    required this.limitController,
    required this.interestController,
    required this.minPctController,
    required this.statementDay,
    required this.dueDay,
    required this.network,
    required this.onStatementDay,
    required this.onDueDay,
    required this.onNetwork,
  });

  final bool enabled;
  final TextEditingController limitController;
  final TextEditingController interestController;
  final TextEditingController minPctController;
  final int statementDay;
  final int dueDay;
  final CardNetwork network;
  final ValueChanged<int> onStatementDay;
  final ValueChanged<int> onDueDay;
  final ValueChanged<CardNetwork> onNetwork;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Insets.cardLg),
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: SmoothRectangleBorder(
          borderRadius: Radii.smooth(Radii.card),
          side: BorderSide(color: c.appBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('TARJETA DE CRÉDITO', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.card),
          AuthTextField(
            label: 'Límite de crédito',
            controller: limitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: enabled,
          ),
          const SizedBox(height: Insets.card),
          _DayStepper(
            label: 'Día de cierre',
            value: statementDay,
            enabled: enabled,
            onChanged: onStatementDay,
          ),
          const SizedBox(height: Insets.md),
          _DayStepper(
            label: 'Día de vencimiento',
            value: dueDay,
            enabled: enabled,
            onChanged: onDueDay,
          ),
          const SizedBox(height: Insets.card),
          AuthTextField(
            label: 'Interés mensual % (ej: 5.5)',
            controller: interestController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: enabled,
          ),
          const SizedBox(height: Insets.card),
          AuthTextField(
            label: 'Mínimo a pagar % (ej: 5)',
            controller: minPctController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: enabled,
          ),
          const SizedBox(height: Insets.card),
          _NetworkDropdown(
            value: network,
            enabled: enabled,
            onChanged: onNetwork,
          ),
        ],
      ),
    );
  }
}

/// Stepper de día (1–31) con `−` / `+`. Reemplaza el `Stepper` de iOS.
class _DayStepper extends StatelessWidget {
  const _DayStepper({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text('$label: $value', style: AppText.body(c.textPrimary)),
        ),
        _StepButton(
          icon: LucideIcons.minus,
          enabled: enabled && value > 1,
          onTap: () => onChanged(value - 1),
        ),
        const SizedBox(width: Insets.md),
        _StepButton(
          icon: LucideIcons.plus,
          enabled: enabled && value < 31,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.appSurface,
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.badge),
              side: BorderSide(color: c.appBorder, width: 1),
            ),
          ),
          child: Icon(icon, size: 16, color: c.textPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Dropdowns ─────────────────────────────────

/// Dropdown de moneda (mismo look del alta de hogar). Catálogo core US/global +
/// LatAm; siempre incluye la moneda activa por si viene una fuera de la lista.
class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  static const List<String> _currencies = <String>[
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Garantizamos que el valor activo esté entre las opciones (evita el assert
    // de DropdownButton si el hogar usa una moneda fuera del catálogo core).
    final List<String> options = _currencies.contains(value)
        ? _currencies
        : <String>[value, ..._currencies];

    return _LabeledDropdown<String>(
      label: 'MONEDA',
      value: value,
      enabled: enabled,
      items: options
          .map((code) => DropdownMenuItem<String>(
                value: code,
                child: Text(code, style: AppText.body(c.textPrimary)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Dropdown de red de tarjeta (Visa/Master/Amex/Discover/Otra).
class _NetworkDropdown extends StatelessWidget {
  const _NetworkDropdown({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final CardNetwork value;
  final ValueChanged<CardNetwork> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _LabeledDropdown<CardNetwork>(
      label: 'RED',
      value: value,
      enabled: enabled,
      items: CardNetwork.values
          .map((n) => DropdownMenuItem<CardNetwork>(
                value: n,
                child: Text(
                  n.name.toUpperCase(),
                  style: AppText.body(c.textPrimary),
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Dropdown genérico con label uppercase + el contenedor squircle del design
/// system (mismo look que el selector de moneda del alta de hogar).
class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(c.textMuted)),
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
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: c.appSurface,
              borderRadius: BorderRadius.circular(Radii.card),
              style: AppText.body(c.textPrimary),
              icon: Icon(LucideIcons.chevronDown, color: c.textMuted),
              items: items,
              onChanged: enabled ? (v) => onChanged(v as T) : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Card de mensaje inline (mismo look que la pantalla de auth/alta de hogar).
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
