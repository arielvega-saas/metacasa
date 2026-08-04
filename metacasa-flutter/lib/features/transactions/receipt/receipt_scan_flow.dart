import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/supabase_init.dart';
import '../../../core/finance/tx_currency.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/fx_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../../home/application/home_controller.dart';
import '../application/transactions_controller.dart';
import 'vision_client.dart';

/// Orquesta el flujo "Escanear recibo": elegir imagen → comprimir → extraer con
/// visión → revisar → crear los gastos.
///
/// Port del `handleImages` del asistente de iOS
/// (`Features/Assistant/AssistantChatView.swift`), adaptado a un flujo dedicado
/// fuera del chat: toma UNA imagen (cámara o galería), la manda al modelo y
/// SIEMPRE muestra la hoja de revisión antes de insertar — tanto si detectó un
/// solo gasto (confirmación de una fila) como si detectó varios (lista). Esto
/// espeja el patrón iOS de "confirmar antes de crear".
abstract final class ReceiptScanFlow {
  const ReceiptScanFlow._();

  /// Punto de entrada único. [context] debe estar montado; [ref] es el del
  /// widget que dispara el flujo (la hoja de alta de movimiento).
  static Future<void> start(BuildContext context, WidgetRef ref) async {
    // 1. Elegir origen (cámara o galería) con una hoja on-brand.
    final ImageSource? source = await _pickSource(context);
    if (source == null || !context.mounted) return;

    // 2. Tomar/elegir la imagen ya comprimida por el plugin (1568px máx., q80).
    final ImagePicker picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        maxWidth: 1568,
        maxHeight: 1568,
        imageQuality: 80,
      );
    } catch (_) {
      if (context.mounted) {
        _toast(context,
            'No pudimos acceder a la cámara o la galería. Revisá los permisos.');
      }
      return;
    }
    if (file == null) return; // el usuario canceló el picker.

    final Uint8List bytes = await file.readAsBytes();
    if (!context.mounted) return;

    // 3. Extraer con visión mostrando un overlay de carga modal.
    final List<ParsedReceiptTx>? parsed =
        await _parseWithLoader(context, ref, bytes);
    if (parsed == null || !context.mounted) return;

    if (parsed.isEmpty) {
      _toast(context,
          'No encontramos ningún gasto en la imagen. Probá con una foto más nítida.');
      return;
    }

    // 4. Revisar + confirmar (siempre, incluso con un solo gasto).
    await ParsedTransactionsReviewSheet.show(context, ref, parsed);
  }

  /// Hoja de selección de origen (Cámara / Galería). Devuelve null si se cierra.
  static Future<ImageSource?> _pickSource(BuildContext context) {
    final c = context.colors;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final sc = sheetContext.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.screen,
              Insets.md,
              Insets.screen,
              Insets.cardLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.scanLine,
                        size: 20, color: sc.brandPrimary),
                    const SizedBox(width: Insets.md),
                    Text('Escanear recibo', style: AppText.h2(sc.textPrimary)),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  'Sacá una foto del ticket o elegí una captura de tu billetera. '
                  'Detectamos el gasto y lo cargás en un toque.',
                  style: AppText.caption(sc.textMuted),
                ),
                const SizedBox(height: Insets.section),
                _SourceTile(
                  icon: LucideIcons.camera,
                  label: 'Tomar una foto',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
                const SizedBox(height: Insets.md),
                _SourceTile(
                  icon: LucideIcons.image,
                  label: 'Elegir de la galería',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Llama a [ReceiptVisionClient.parseReceipts] mostrando un diálogo de carga
  /// no-cancelable. Cierra el diálogo en éxito o error. Devuelve la lista, o
  /// null si hubo error (ya se muestra el toast).
  static Future<List<ParsedReceiptTx>?> _parseWithLoader(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes,
  ) async {
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ScanLoadingDialog(),
    );

    try {
      final List<ParsedReceiptTx> parsed = await ref
          .read(receiptVisionClientProvider)
          .parseReceipts(<Uint8List>[bytes]);
      if (navigator.canPop()) navigator.pop(); // cierra el loader.
      return parsed;
    } on ReceiptVisionException catch (e) {
      if (navigator.canPop()) navigator.pop();
      if (context.mounted) _toast(context, e.friendlyMessage);
      return null;
    } catch (_) {
      if (navigator.canPop()) navigator.pop();
      if (context.mounted) {
        _toast(context, 'Algo salió mal al leer el recibo. Probá de nuevo.');
      }
      return null;
    }
  }

  static void _toast(BuildContext context, String message) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppText.caption(c.textPrimary)),
        backgroundColor: c.appSurfaceInset,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Tile de origen (cámara / galería) dentro de la hoja de selección.
class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(Insets.card),
        decoration: BoxDecoration(
          color: c.appSurfaceInset,
          borderRadius: BorderRadius.circular(Radii.input),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.brandPrimary),
            const SizedBox(width: Insets.card),
            Expanded(
              child: Text(
                label,
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textDim),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de carga mientras el modelo lee el recibo.
class _ScanLoadingDialog extends StatelessWidget {
  const _ScanLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      backgroundColor: c.appSurface,
      child: Padding(
        padding: const EdgeInsets.all(Insets.hero),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: c.brandPrimary,
              ),
            ),
            const SizedBox(height: Insets.cardLg),
            Text('Leyendo el recibo…', style: AppText.body(c.textPrimary)),
            const SizedBox(height: Insets.xs),
            Text(
              'Detectando montos y comercio',
              style: AppText.caption(c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado mutable editable de una fila de la hoja de revisión. Arranca con los
/// valores extraídos; el usuario puede cambiar categoría (chip) — los demás
/// campos se muestran y se insertan tal cual fueron leídos.
class _ReviewRow {
  _ReviewRow({
    required this.amount,
    required this.date,
    required this.merchant,
    required this.currency,
    required this.category,
  });

  factory _ReviewRow.fromParsed(ParsedReceiptTx tx) => _ReviewRow(
        amount: tx.amount,
        date: tx.date,
        merchant: tx.merchant,
        currency: tx.currency,
        category: tx.category,
      );

  final Decimal amount;
  final DateTime date;
  final String merchant;
  final String currency;
  String category;
}

/// Hoja de revisión de los gastos detectados. Muestra una fila por gasto
/// (comercio → nota, monto, fecha, moneda) con un chip de categoría editable, y
/// un CTA "Crear N transacciones" que inserta cada una como GASTO.
///
/// Espejo del preview de import del asistente de iOS, pero con confirmación
/// explícita antes de tocar la DB (incluso para un solo gasto).
class ParsedTransactionsReviewSheet extends ConsumerStatefulWidget {
  const ParsedTransactionsReviewSheet({super.key, required this.parsed});

  final List<ParsedReceiptTx> parsed;

  /// Presenta la hoja modal con el look del design system.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    List<ParsedReceiptTx> parsed,
  ) {
    final c = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ParsedTransactionsReviewSheet(parsed: parsed),
    );
  }

  @override
  ConsumerState<ParsedTransactionsReviewSheet> createState() =>
      _ParsedTransactionsReviewSheetState();
}

class _ParsedTransactionsReviewSheetState
    extends ConsumerState<ParsedTransactionsReviewSheet> {
  late final List<_ReviewRow> _rows =
      widget.parsed.map(_ReviewRow.fromParsed).toList();

  /// Catálogo de categorías de GASTO (defaults + custom del hogar) para los
  /// chips editables. Se carga async; mientras tanto caemos a los defaults.
  List<CategoryItem> _categories = CategoryCatalog.defaultGastos
      .map((String name) => CategoryItem(name: name))
      .toList();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  /// Trae las categorías de gasto del hogar (mergeadas con defaults).
  Future<void> _loadCategories() async {
    final String? householdId =
        ref.read(currentHouseholdIdProvider).valueOrNull;
    if (householdId == null) return;
    final CategoriesBlob? blob =
        await ref.read(categoryRepositoryProvider).fetch(householdId);
    if (!mounted) return;
    setState(() {
      _categories =
          TransactionsController.mergedCategories(blob?.data, TxType.gasto);
      // Aseguramos que las categorías sugeridas por el modelo (que pueden no
      // estar en el catálogo del hogar) queden disponibles como chip.
      for (final _ReviewRow row in _rows) {
        final bool known =
            _categories.any((CategoryItem ci) => ci.name == row.category);
        if (!known && row.category.isNotEmpty) {
          _categories = <CategoryItem>[
            ..._categories,
            CategoryItem(name: row.category),
          ];
        }
      }
    });
  }

  String _locale(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag().replaceAll('-', '_');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final int count = _rows.length;
    final String cta = _saving
        ? 'Creando…'
        : (count == 1 ? 'Crear transacción' : 'Crear $count transacciones');

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
                        Icon(LucideIcons.receipt,
                            size: 20, color: c.brandPrimary),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Text(
                            count == 1
                                ? 'Revisá el gasto'
                                : 'Revisá los $count gastos',
                            style: AppText.h2(c.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      'Detectamos esto del recibo. Ajustá la categoría si hace '
                      'falta y confirmá para cargarlos como gastos.',
                      style: AppText.caption(c.textMuted),
                    ),
                    const SizedBox(height: Insets.section),
                    for (int i = 0; i < _rows.length; i++) ...[
                      _rowCard(context, i),
                      const SizedBox(height: Insets.card),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: Insets.xs),
                      Text(_error!, style: AppText.caption(c.brandDanger)),
                    ],
                  ],
                ),
              ),
            ),
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
                label: cta,
                icon: LucideIcons.check,
                onPressed: _saving ? null : _createAll,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card de una fila: comercio (→ nota), monto + moneda, fecha, chips de
  /// categoría editables.
  Widget _rowCard(BuildContext context, int index) {
    final c = context.colors;
    final _ReviewRow row = _rows[index];
    final String merchantLabel =
        row.merchant.isEmpty ? 'Sin comercio' : row.merchant;

    return Container(
      padding: const EdgeInsets.all(Insets.card),
      decoration: BoxDecoration(
        color: c.appSurfaceInset,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comercio + monto.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchantLabel,
                      style: AppText.body(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Insets.xs),
                    Row(
                      children: [
                        Icon(LucideIcons.calendar, size: 12, color: c.textDim),
                        const SizedBox(width: Insets.xs),
                        Text(
                          _formatDate(row.date),
                          style: AppText.caption(c.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.format(
                      row.amount,
                      currencyCode: row.currency.isEmpty ? 'USD' : row.currency,
                      style: MoneyStyle.auto,
                      locale: _locale(context),
                    ),
                    style: AppText.body(c.brandDanger)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (row.currency.isNotEmpty) ...[
                    const SizedBox(height: Insets.xxs),
                    Text(row.currency, style: AppText.caption(c.textDim)),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.card),
          Text('CATEGORÍA', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.md,
            runSpacing: Insets.md,
            children: _categories
                .map((CategoryItem ci) => MCChip(
                      emoji: ci.emoji ?? CategoryCatalog.emojiFor(ci.name),
                      label: ci.name,
                      selected: row.category == ci.name,
                      onTap: () =>
                          setState(() => _rows[index].category = ci.name),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// Inserta todas las filas como GASTO (cada una vía
  /// `transactionRepository.insert`), luego invalida lista + dashboard. Espejo
  /// del `createMultipleTransactions` de iOS, con la nota = "Recibo: comercio".
  Future<void> _createAll() async {
    setState(() => _error = null);

    // Capturamos lo dependiente de context ANTES de los awaits (insert + haptic)
    // para no usar el BuildContext cruzando gaps async.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final MidnightSageColors colors = context.colors;

    final String? householdId =
        ref.read(currentHouseholdIdProvider).valueOrNull;
    final String? userId = supabase.auth.currentUser?.id;
    if (householdId == null || userId == null) {
      setState(() => _error = 'No encontramos tu hogar. Reintentá.');
      return;
    }
    final String baseCurrency =
        ref.read(currentHouseholdProvider).valueOrNull?.defaultCurrency ??
            'USD';

    setState(() => _saving = true);

    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    // Antes se guardaba el monto del ticket TAL CUAL, sólo etiquetado con su moneda. Pero
    // `amount` va siempre en la base del hogar: un recibo de USD 100 en un hogar en pesos
    // entraba como 100, y todos los totales quedaban divididos por la cotización. Sin
    // error y con un número plausible.
    final Map<String, FXRate> rates =
        await ref.read(fxRepositoryProvider).getRates(householdId);
    int inserted = 0;
    int sinCotizacion = 0;
    for (final _ReviewRow row in _rows) {
      final String currency =
          row.currency.isEmpty ? baseCurrency : row.currency;
      final NewTransactionInput input;
      try {
        input = NewTransactionInputConverting.converting(
          householdId: householdId,
          userId: userId,
          type: TxType.gasto,
          amountOriginal: row.amount,
          currency: currency,
          baseCurrency: baseCurrency,
          rates: rates,
          category: row.category.isEmpty ? 'Otros' : row.category,
          note: row.merchant.isEmpty ? null : 'Recibo: ${row.merchant}',
          date: row.date,
        );
      } on FxConversionException {
        // Sin cotización no se guarda mal: se cuenta y se avisa al final.
        sinCotizacion++;
        continue;
      }
      try {
        await repo.insert(input);
        inserted++;
      } catch (_) {
        // Seguimos con las demás; reportamos al final.
      }
    }

    // Refresca lista + dashboard (mueve totales/saldos), igual que el alta.
    ref.invalidate(transactionsControllerProvider);
    ref.invalidate(homeControllerProvider);

    if (!mounted) return;

    if (inserted == 0) {
      await HapticFeedback.heavyImpact();
      setState(() {
        _saving = false;
        // Distinguir el motivo importa: "reintentá" no sirve de nada si lo que falta
        // es la cotización, y el usuario reintentaría para siempre.
        _error = sinCotizacion > 0
            ? 'El recibo está en otra moneda y no hay cotización cargada. '
                'Agregala en Ajustes → Monedas y reintentá.'
            : 'No pudimos crear las transacciones. Reintentá.';
      });
      return;
    }

    await HapticFeedback.mediumImpact();
    navigator.pop();
    final int failed = _rows.length - inserted;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? (inserted == 1
                  ? 'Gasto cargado desde el recibo.'
                  : '$inserted gastos cargados desde el recibo.')
              : sinCotizacion > 0
                  ? 'Cargamos $inserted de ${_rows.length}. Faltan cotizaciones '
                      'para el resto (Ajustes → Monedas).'
                  : 'Cargamos $inserted de ${_rows.length}. Algunos fallaron, '
                      'reintentá esos a mano.',
          style: AppText.caption(colors.textPrimary),
        ),
        backgroundColor: colors.appSurfaceInset,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Fecha corta dd/MM/yyyy (sin dependencia extra de formato).
  static String _formatDate(DateTime d) {
    final String dd = d.day.toString().padLeft(2, '0');
    final String mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}
