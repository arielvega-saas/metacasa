import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/finance/balance_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../application/accounts_controller.dart';
import 'account_type_icon.dart';
import 'add_account_sheet.dart';
import 'credit_card_detail_screen.dart';

/// Pantalla de Cuentas — espejo de `AccountsView` (iOS), enriquecida con el
/// header de patrimonio neto del `AccountBalanceService`.
///
/// Estructura:
///   1. Header de net worth: assets, liabilities, patrimonio neto y un badge de
///      solvencia (según `debtToAssetRatio`).
///   2. Lista de cuentas ordenadas por `display_order`: ícono por tipo, nombre,
///      institución, balance vivo (privacy-aware) y badge de pertenencia.
///   3. "+ cuenta" en la AppBar y un CTA en el empty-state.
///
/// Tap en una cuenta `credit_card` → [CreditCardDetailScreen]; el resto abre un
/// detalle simple (hoja con el balance y los datos de la cuenta).
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<AccountsState> accountsAsync =
        ref.watch(accountsControllerProvider);
    final String currency =
        ref.watch(currentHouseholdProvider).valueOrNull?.defaultCurrency ??
            'USD';
    final bool privacy = ref.watch(privacyModeProvider);
    final String? householdId =
        ref.watch(currentHouseholdProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text('Cuentas', style: AppText.h2(c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, color: c.brandPrimary),
            tooltip: 'Agregar cuenta',
            onPressed: householdId == null
                ? null
                : () => _openAdd(context, ref, householdId),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: () =>
            ref.read(accountsControllerProvider.notifier).refresh(),
        child: accountsAsync.when(
          loading: () => const _AccountsSkeleton(),
          error: (Object err, StackTrace _) => _ErrorState(
            onRetry: () =>
                ref.read(accountsControllerProvider.notifier).refresh(),
          ),
          data: (AccountsState state) {
            if (state.isEmpty) {
              return _EmptyAccounts(
                onAdd: householdId == null
                    ? null
                    : () => _openAdd(context, ref, householdId),
              );
            }
            return _AccountsList(
              state: state,
              currency: currency,
              privacy: privacy,
            );
          },
        ),
      ),
    );
  }

  /// Abre la hoja de alta y, si guardó, refresca el controller.
  Future<void> _openAdd(
    BuildContext context,
    WidgetRef ref,
    String householdId,
  ) async {
    HapticFeedback.mediumImpact();
    final bool? saved = await AddAccountSheet.show(context, householdId);
    if (saved ?? false) {
      await ref.read(accountsControllerProvider.notifier).refresh();
    }
  }
}

// ─────────────────────────────── Lista ─────────────────────────────────────

/// Lista scrollable: header de net worth + filas de cuenta. ListView con
/// `AlwaysScrollableScrollPhysics` para que el pull-to-refresh siempre funcione.
class _AccountsList extends StatelessWidget {
  const _AccountsList({
    required this.state,
    required this.currency,
    required this.privacy,
  });

  final AccountsState state;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120, // espacio para el FAB del asistente del shell
      ),
      children: [
        _NetWorthHeader(
          netWorth: state.netWorth,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        ...state.balances.map((AccountBalance b) => Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: _AccountRow(
                balance: b,
                privacy: privacy,
              ),
            )),
      ],
    );
  }
}

// ─────────────────────────────── Net worth ─────────────────────────────────

/// Header de patrimonio neto: el monto grande (serif) + assets/liabilities + un
/// badge de solvencia. Espejo del net worth del `AccountBalanceService` de iOS.
class _NetWorthHeader extends StatelessWidget {
  const _NetWorthHeader({
    required this.netWorth,
    required this.currency,
    required this.privacy,
  });

  final NetWorthBreakdown netWorth;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool positive = netWorth.netWorth >= Decimal.zero;

    return MCCard(
      glow: positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('PATRIMONIO NETO', style: AppText.label(c.textMuted)),
              ),
              _SolvencyBadge(ratio: netWorth.debtToAssetRatio),
            ],
          ),
          const SizedBox(height: Insets.xl),
          AmountText(
            value: netWorth.netWorth,
            currencyCode: currency,
            kind: AmountKind.balance,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifHero(c.textPrimary),
          ),
          const SizedBox(height: Insets.section),
          Row(
            children: [
              Expanded(
                child: _NetWorthFigure(
                  icon: LucideIcons.arrowDownLeft,
                  label: 'Activos',
                  value: netWorth.assets,
                  color: c.brandSuccess,
                  currency: currency,
                  privacy: privacy,
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: c.appBorder,
                margin: const EdgeInsets.symmetric(horizontal: Insets.xl),
              ),
              Expanded(
                child: _NetWorthFigure(
                  icon: LucideIcons.arrowUpRight,
                  label: 'Pasivos',
                  value: netWorth.liabilities,
                  color: c.brandDanger,
                  currency: currency,
                  privacy: privacy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una cifra del header (Activos o Pasivos): ícono + etiqueta + monto neutro.
class _NetWorthFigure extends StatelessWidget {
  const _NetWorthFigure({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.currency,
    required this.privacy,
  });

  final IconData icon;
  final String label;
  final Decimal value;
  final Color color;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: Insets.sm),
            Text(label, style: AppText.caption(c.textMuted)),
          ],
        ),
        const SizedBox(height: Insets.xs),
        AmountText(
          value: value,
          currencyCode: currency,
          kind: AmountKind.neutro,
          obscured: privacy,
          style: AppText.serifAmount(c.textPrimary),
        ),
      ],
    );
  }
}

/// Badge de solvencia según `debtToAssetRatio` (deuda/activos). Espejo de los
/// umbrales de iOS: < 0.3 sano (sage), 0.3–0.6 atención (champagne), > 0.6
/// riesgo (coral).
class _SolvencyBadge extends StatelessWidget {
  const _SolvencyBadge({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (String label, Color color) = ratio < 0.3
        ? ('Saludable', c.brandSuccess)
        : ratio <= 0.6
            ? ('Atención', c.brandWarning)
            : ('Riesgo', c.brandDanger);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 3),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.shieldCheck, size: 12, color: color),
          const SizedBox(width: Insets.xs),
          Text(
            label,
            style: AppText.caption(color).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Fila de cuenta ────────────────────────────

/// Fila de cuenta: ícono por tipo, nombre + institución, balance vivo
/// (privacy-aware) y badge de pertenencia. Tap → detalle (TC o simple).
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.balance, required this.privacy});

  final AccountBalance balance;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Account a = balance.account;
    // Subtítulo: institución si la hay, si no el label del tipo (como iOS, que
    // muestra el tipo bajo el nombre).
    final String subtitle = (a.institution != null && a.institution!.isNotEmpty)
        ? a.institution!
        : a.type.label;

    return MCCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.cardLg,
        vertical: Insets.card,
      ),
      onTap: () => _openDetail(context),
      child: Row(
        children: [
          // Ícono del tipo en un tile sage tenue (igual recipe que iOS).
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: c.brandPrimary.withValues(alpha: 0.12),
              shape: SmoothRectangleBorder(
                borderRadius: Radii.smooth(Radii.badge),
              ),
            ),
            child:
                Icon(accountTypeIcon(a.type), size: 20, color: c.brandPrimary),
          ),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        a.name,
                        style: AppText.body(c.textPrimary)
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    _OwnershipBadge(ownership: a.ownership),
                  ],
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  subtitle,
                  style: AppText.caption(c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          // Balance vivo: `.balance` → positivo neutro, negativo coral con `-`.
          AmountText(
            value: balance.balance,
            currencyCode: a.currency,
            kind: AmountKind.balance,
            obscured: privacy,
            style: AppText.serifAmount(c.textPrimary),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    final Account a = balance.account;
    if (a.type == AccountType.creditCard) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CreditCardDetailScreen(account: a),
        ),
      );
    } else {
      _AccountDetailSheet.show(context, balance, privacy);
    }
  }
}

/// Badge chico de pertenencia (personal/compartida/externa) — ícono + texto.
class _OwnershipBadge extends StatelessWidget {
  const _OwnershipBadge({required this.ownership});

  final AccountOwnership ownership;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ownershipIcon(ownership), size: 10, color: c.textMuted),
          const SizedBox(width: Insets.xs),
          Text(ownership.label, style: AppText.caption(c.textMuted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Detalle simple ────────────────────────────

/// Detalle simple para cuentas no-tarjeta: una hoja con el balance vivo grande y
/// los datos de la cuenta (tipo, institución, saldo inicial, pertenencia).
/// Espejo del destino `Text(account.name)` de iOS, enriquecido.
class _AccountDetailSheet extends StatelessWidget {
  const _AccountDetailSheet({required this.balance, required this.privacy});

  final AccountBalance balance;
  final bool privacy;

  static Future<void> show(
    BuildContext context,
    AccountBalance balance,
    bool privacy,
  ) {
    final c = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AccountDetailSheet(balance: balance, privacy: privacy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Account a = balance.account;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.cardLg,
          Insets.md,
          Insets.cardLg,
          Insets.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: c.brandPrimary.withValues(alpha: 0.12),
                    shape: SmoothRectangleBorder(
                      borderRadius: Radii.smooth(Radii.badge),
                    ),
                  ),
                  child: Icon(accountTypeIcon(a.type),
                      size: 20, color: c.brandPrimary),
                ),
                const SizedBox(width: Insets.card),
                Expanded(
                  child: Text(
                    a.name,
                    style: AppText.h2(c.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.section),
            Text('SALDO ACTUAL', style: AppText.label(c.textMuted)),
            const SizedBox(height: Insets.sm),
            AmountText(
              value: balance.balance,
              currencyCode: a.currency,
              kind: AmountKind.balance,
              obscured: privacy,
              fitToWidth: true,
              style: AppText.serifDisplay(c.textPrimary),
            ),
            const SizedBox(height: Insets.section),
            _DetailRow(label: 'Tipo', value: a.type.label),
            if (a.institution != null && a.institution!.isNotEmpty)
              _DetailRow(label: 'Institución', value: a.institution!),
            _DetailRow(label: 'Moneda', value: a.currency),
            _DetailRow(label: 'Pertenencia', value: a.ownership.label),
            _DetailRow(
              label: 'Saldo inicial',
              valueWidget: AmountText(
                value: a.startingBalance,
                currencyCode: a.currency,
                kind: AmountKind.neutro,
                obscured: privacy,
                moneyStyle: MoneyStyle.auto,
                style: AppText.body(c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila "etiqueta … valor" del detalle simple. Acepta un valor de texto o un
/// widget arbitrario (para montos formateados).
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value, this.valueWidget});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.md),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.caption(c.textMuted))),
          const SizedBox(width: Insets.card),
          valueWidget ?? Text(value ?? '', style: AppText.body(c.textPrimary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Estados ───────────────────────────────────

/// Empty-state: sin cuentas todavía, con CTA de alta. Scrollable para el
/// pull-to-refresh.
class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.wallet,
            title: 'Todavía no tenés cuentas',
            message:
                'Agregá tus cuentas, efectivo y tarjetas para ver tu patrimonio.',
            actionLabel: onAdd == null ? null : 'Agregar cuenta',
            onAction: onAdd,
          ),
        ),
      ],
    );
  }
}

/// Estado de error: EmptyState con reintento. Scrollable para el pull-to-refresh.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.cloudOff,
            title: 'No pudimos cargar tus cuentas',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

/// Skeleton mientras carga: header + filas placeholder. Scrollable para el
/// pull-to-refresh.
class _AccountsSkeleton extends StatelessWidget {
  const _AccountsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120,
      ),
      children: const [
        _SkeletonBlock(height: 180), // header net worth
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 72),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 72),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 72),
      ],
    );
  }
}

/// Bloque rectangular de skeleton (superficie con esquinas squircle).
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      decoration: ShapeDecoration(
        color: c.appSurface,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
      ),
    );
  }
}
