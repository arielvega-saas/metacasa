import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/credit_card_math.dart';

/// Provider de los detalles de TC de una cuenta. `autoDispose.family` por
/// `accountId`: se descarta al salir del detalle (no cacheamos detalles de
/// tarjetas que ya no se ven). Lee `AccountRepository.fetchCard`.
final creditCardDetailsProvider =
    FutureProvider.autoDispose.family<CreditCardDetails?, String>(
  (ref, accountId) => ref.read(accountRepositoryProvider).fetchCard(accountId),
);

/// Detalle de tarjeta de crédito — espejo 1:1 de `CreditCardDetailView` (iOS).
///
/// Tres cards apiladas:
///   1. LÍMITE — monto del cupo + red (Visa/Master/…).
///   2. VENCIMIENTO — día de cierre, día de vencimiento, días que faltan (rojo
///      si ≤ 5).
///   3. SALDO DEL RESUMEN — último resumen, pago mínimo y el interés proyectado
///      si pagás solo el mínimo.
///
/// La matemática vive en [CreditCardMath] (port de los static de
/// `CreditCardService`). Estados: loading (spinner), sin-detalles (mensaje),
/// error (texto coral).
class CreditCardDetailScreen extends ConsumerWidget {
  const CreditCardDetailScreen({super.key, required this.account});

  /// Cuenta (type=creditCard) cuyos detalles se muestran.
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<CreditCardDetails?> detailsAsync =
        ref.watch(creditCardDetailsProvider(account.id));

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text(
          account.name,
          style: AppText.h2(c.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xxl),
            child: Text(
              'No pudimos cargar los detalles de la tarjeta.',
              style: AppText.body(c.brandDanger),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (CreditCardDetails? details) {
          if (details == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Insets.xxl),
                child: Text(
                  'Esta cuenta no tiene detalles de tarjeta cargados.',
                  style: AppText.body(c.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.screen,
              Insets.section,
              Insets.screen,
              Insets.xxl,
            ),
            children: [
              _LimitCard(currency: account.currency, details: details),
              const SizedBox(height: Insets.section),
              _DueCard(details: details),
              const SizedBox(height: Insets.section),
              _InterestCard(currency: account.currency, details: details),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────── Límite ────────────────────────────────────

/// Card de LÍMITE: cupo total (neutro, sin signo) + red de la tarjeta.
class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.currency, required this.details});

  final String currency;
  final CreditCardDetails details;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final String network = details.network?.name.toUpperCase() ?? '—';

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LÍMITE', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.sm),
          AmountText(
            value: details.creditLimit,
            currencyCode: currency,
            kind: AmountKind.neutro,
            fitToWidth: true,
            style: AppText.serifDisplay(c.textPrimary),
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Icon(LucideIcons.creditCard, size: 14, color: c.textMuted),
              const SizedBox(width: Insets.sm),
              Text('Red: $network', style: AppText.caption(c.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Vencimiento ───────────────────────────────

/// Card de VENCIMIENTO: día de cierre, día de vencimiento y los días que faltan
/// para el próximo (rojo si ≤ 5, igual que iOS).
class _DueCard extends StatelessWidget {
  const _DueCard({required this.details});

  final CreditCardDetails details;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final int days = CreditCardMath.daysUntilDue(dueDay: details.dueDay);
    final Color daysColor = days <= 5 ? c.brandDanger : c.textPrimary;

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VENCIMIENTO', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.card),
          Row(
            children: [
              Expanded(
                child: _DueStat(
                  label: 'Cierre',
                  value: 'Día ${details.statementDay}',
                  color: c.textPrimary,
                ),
              ),
              Expanded(
                child: _DueStat(
                  label: 'Vence',
                  value: 'Día ${details.dueDay}',
                  color: c.textPrimary,
                ),
              ),
              Expanded(
                child: _DueStat(
                  label: 'En',
                  value: '${days}d',
                  color: daysColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una métrica de la card de vencimiento: etiqueta chica + valor grande.
class _DueStat extends StatelessWidget {
  const _DueStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption(c.textMuted)),
        const SizedBox(height: Insets.xxs),
        Text(value, style: AppText.h2(color)),
      ],
    );
  }
}

// ─────────────────────────────── Interés ───────────────────────────────────

/// Card de SALDO DEL RESUMEN: el último resumen (deuda → coral con `-`), el pago
/// mínimo y el interés proyectado si solo pagás el mínimo. Misma semántica de
/// color que iOS (`.gasto` para todo: es plata que sale / que debés).
class _InterestCard extends StatelessWidget {
  const _InterestCard({required this.currency, required this.details});

  final String currency;
  final CreditCardDetails details;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Decimal statement = details.lastStatementAmount ?? Decimal.zero;
    final Decimal minPayment = CreditCardMath.minimumPayment(
      statementAmount: statement,
      percent: details.minimumPaymentPct,
    );
    final Decimal interestIfMin = CreditCardMath.interestIfMinPayment(
      statementAmount: statement,
      minPct: details.minimumPaymentPct,
      monthlyRate: details.interestRateMonthly,
    );

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SALDO DEL RESUMEN', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.sm),
          AmountText(
            value: statement,
            currencyCode: currency,
            kind: AmountKind.gasto,
            fitToWidth: true,
            style: AppText.serifAmount(c.textPrimary),
          ),
          Divider(color: c.appBorder, height: Insets.section * 2),
          _InterestRow(
            label: 'Mínimo (${_formatPct(details.minimumPaymentPct)})',
            value: minPayment,
            currency: currency,
          ),
          const SizedBox(height: Insets.card),
          _InterestRow(
            label:
                'Interés si pagás solo el mínimo (${_formatPct(details.interestRateMonthly)}/mes)',
            value: interestIfMin,
            currency: currency,
          ),
          if (details.lastStatementDate != null) ...[
            const SizedBox(height: Insets.card),
            Text(
              'Último resumen: ${_formatDate(details.lastStatementDate!)}',
              style: AppText.caption(c.textDim),
            ),
          ],
        ],
      ),
    );
  }

  /// Porcentaje sin ceros sobrantes: `5`, `5.5`, `2.75` → con sufijo `%`.
  /// Espejo del `formatPct` de iOS (max 2 decimales).
  static String _formatPct(Decimal value) {
    final double v = value.toDouble();
    final String s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
    return '$s%';
  }

  /// Fecha abreviada local (`dd/MM/yyyy`) sin traer `intl` solo para esto.
  static String _formatDate(DateTime date) {
    final String dd = date.day.toString().padLeft(2, '0');
    final String mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }
}

/// Fila "etiqueta … monto" de la card de interés. El monto va como gasto
/// (coral, con `-`): es plata que vas a pagar.
class _InterestRow extends StatelessWidget {
  const _InterestRow({
    required this.label,
    required this.value,
    required this.currency,
  });

  final String label;
  final Decimal value;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppText.caption(c.textMuted))),
        const SizedBox(width: Insets.card),
        AmountText(
          value: value,
          currencyCode: currency,
          kind: AmountKind.gasto,
          moneyStyle: MoneyStyle.auto,
          style: AppText.body(c.textPrimary).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
