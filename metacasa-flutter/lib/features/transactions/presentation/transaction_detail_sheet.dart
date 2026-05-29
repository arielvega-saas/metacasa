import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../home/application/home_controller.dart';
import '../application/transactions_controller.dart';
import 'edit_transaction_sheet.dart';

/// Hoja de detalle de un movimiento (solo lectura) — espejo del `TransactionRow`
/// expandido + acciones de iOS. Muestra el monto hero, los metadatos (categoría,
/// subcategoría, cuenta, fecha, nota, conversión de moneda si aplica) y dos
/// acciones: editar (abre [EditTransactionSheet]) y eliminar (con confirmación).
class TransactionDetailSheet extends ConsumerWidget {
  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    required this.currency,
  });

  /// Movimiento a mostrar.
  final Transaction transaction;

  /// Moneda base del hogar (para los montos sin `currencyOriginal`).
  final String currency;

  /// Presenta la hoja modal con el look del design system.
  static Future<void> show(
    BuildContext context, {
    required Transaction transaction,
    required String currency,
  }) {
    final c = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TransactionDetailSheet(
        transaction: transaction,
        currency: currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final bool isGasto = transaction.type == TxType.gasto;
    final Color tint = isGasto ? c.brandDanger : c.brandSuccess;
    // El monto del movimiento se muestra en su moneda original si la tiene
    // (multi-moneda), si no en la base del hogar — igual que el row de iOS.
    final String txCurrency = transaction.currencyOriginal ?? currency;

    return SafeArea(
      child: SingleChildScrollView(
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
            // Header: emoji de categoría + título + chip de tipo.
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tint.withValues(alpha: 0.12),
                    border: Border.all(color: tint.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    CategoryCatalog.emojiFor(transaction.category),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: Insets.card),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: AppText.h2(c.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Insets.xxs),
                      Text(
                        isGasto ? 'Gasto' : 'Ingreso',
                        style: AppText.caption(tint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.section),
            // Monto hero en serif.
            AmountText(
              value: transaction.amount,
              currencyCode: txCurrency,
              kind: isGasto ? AmountKind.gasto : AmountKind.ingreso,
              fitToWidth: true,
              style: AppText.serifHero(c.textPrimary),
            ),
            // Conversión: si fue cargado en otra moneda, mostramos el valor en
            // base del hogar (lo que realmente quedó guardado).
            if (transaction.currencyOriginal != null &&
                transaction.currencyOriginal != currency) ...[
              const SizedBox(height: Insets.sm),
              Row(
                children: [
                  Icon(LucideIcons.repeat, size: 14, color: c.textMuted),
                  const SizedBox(width: Insets.sm),
                  Text('Equivale a ', style: AppText.caption(c.textMuted)),
                  AmountText(
                    value: transaction.amount,
                    currencyCode: currency,
                    kind: AmountKind.neutro,
                    style: AppText.caption(c.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Insets.section),
            // Metadatos.
            _DetailRow(
              icon: LucideIcons.tag,
              label: 'Categoría',
              value: transaction.category,
            ),
            if (transaction.subcategory != null &&
                transaction.subcategory!.isNotEmpty)
              _DetailRow(
                icon: LucideIcons.tag,
                label: 'Subcategoría',
                value: transaction.subcategory!,
              ),
            _DetailRow(
              icon: LucideIcons.wallet,
              label: 'Cuenta',
              value: _accountLabel,
            ),
            _DetailRow(
              icon: LucideIcons.calendar,
              label: 'Fecha',
              value: _formatDate(transaction.date),
            ),
            if (transaction.note != null && transaction.note!.isNotEmpty)
              _DetailRow(
                icon: LucideIcons.scrollText,
                label: 'Nota',
                value: transaction.note!,
              ),
            const SizedBox(height: Insets.section),
            // Acciones.
            Row(
              children: [
                Expanded(
                  child: MCSecondaryButton(
                    label: 'Editar',
                    icon: LucideIcons.pencil,
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await EditTransactionSheet.show(
                        context,
                        transaction: transaction,
                        currency: currency,
                      );
                    },
                  ),
                ),
                const SizedBox(width: Insets.xl),
                Expanded(
                  child: _DeleteButton(
                    onConfirm: () => _delete(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Título: la nota si existe, si no el nombre de la categoría (igual que iOS).
  String get _title {
    final String? note = transaction.note;
    if (note != null && note.isNotEmpty) return note;
    return transaction.category;
  }

  /// Etiqueta de cuenta: el nombre legado (`account`) si existe, si no "Hogar"
  /// (movimiento sin cuenta asignada).
  String get _accountLabel {
    final String? account = transaction.account;
    if (account != null && account.isNotEmpty) return account;
    return 'Hogar';
  }

  /// Borra el movimiento e invalida los controllers que lo muestran.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    await repo.delete(transaction.id);
    await HapticFeedback.mediumImpact();
    // Recarga lista + dashboard (el borrado mueve totales).
    ref.invalidate(transactionsControllerProvider);
    ref.invalidate(homeControllerProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  /// Fecha legible (rioplatense): "lunes 5 de mayo de 2026".
  static String _formatDate(DateTime d) {
    const List<String> days = <String>[
      '',
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
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
    return '${days[d.weekday]} ${d.day} de ${months[d.month]} de ${d.year}';
  }
}

/// Fila etiqueta + valor del detalle (ícono tenue + label muted + valor).
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.card),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c.textMuted),
          const SizedBox(width: Insets.lg),
          SizedBox(
            width: 96,
            child: Text(label, style: AppText.caption(c.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppText.body(c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de eliminar con confirmación en diálogo. Coral, full-width.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        HapticFeedback.selectionClick();
        final bool ok = await _confirm(context);
        if (ok) await onConfirm();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.brandDanger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: c.brandDanger.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.trash2, size: 18, color: c.brandDanger),
            const SizedBox(width: Insets.md),
            Text(
              'Eliminar',
              style: AppText.body(c.brandDanger)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo de confirmación de borrado.
  Future<bool> _confirm(BuildContext context) async {
    final c = context.colors;
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.appSurface,
        title: Text('Eliminar movimiento', style: AppText.h2(c.textPrimary)),
        content: Text(
          '¿Seguro que querés eliminar este movimiento? No se puede deshacer.',
          style: AppText.body(c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: AppText.body(c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Eliminar',
              style: AppText.body(c.brandDanger)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
