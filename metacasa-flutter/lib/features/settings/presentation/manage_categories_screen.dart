import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../../auth/presentation/auth_field.dart';

/// Pantalla de gestión de categorías custom — espejo de `ManageCategoriesView`
/// de iOS. Segmenta gastos/ingresos; cada categoría tiene emoji + nombre +
/// subcategorías. Las ediciones se aplican sobre un `CategoriesData` local y se
/// persisten en cada cambio vía `categoryRepository.save` (upsert del blob).
///
/// Si el hogar todavía no tiene fila en `categories`, sembramos los defaults de
/// [CategoryCatalog] para que el usuario vea algo editable (igual que iOS).
class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState
    extends ConsumerState<ManageCategoriesScreen> {
  CategoriesData _data = const CategoriesData();
  TxType _selectedType = TxType.gasto;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _householdId =>
      ref.read(currentHouseholdProvider).valueOrNull?.id;

  List<CategoryItem> get _items =>
      _selectedType == TxType.gasto ? _data.gastos : _data.ingresos;

  Future<void> _load() async {
    final String? hid = _householdId;
    if (hid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final CategoriesBlob? blob =
          await ref.read(categoryRepositoryProvider).fetch(hid);
      final CategoriesData data = blob?.data ?? _seedDefaults();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No pudimos cargar las categorías.';
        });
      }
    }
  }

  /// Defaults sembrados (gastos + ingresos del catálogo, con su emoji).
  CategoriesData _seedDefaults() => CategoriesData(
        gastos: CategoryCatalog.defaultGastos
            .map((String name) =>
                CategoryItem(name: name, emoji: CategoryCatalog.emojiFor(name)))
            .toList(),
        ingresos: CategoryCatalog.defaultIngresos
            .map((String name) =>
                CategoryItem(name: name, emoji: CategoryCatalog.emojiFor(name)))
            .toList(),
      );

  /// Reescribe el blob local para el tipo activo y persiste.
  Future<void> _persist(List<CategoryItem> updatedItems) async {
    final String? hid = _householdId;
    if (hid == null) return;
    final CategoriesData next = _selectedType == TxType.gasto
        ? _data.copyWith(gastos: updatedItems)
        : _data.copyWith(ingresos: updatedItems);
    setState(() {
      _data = next;
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(categoryRepositoryProvider).save(
            CategoriesBlob(householdId: hid, data: next),
          );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar. Revisá tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addItem() async {
    HapticFeedback.mediumImpact();
    final CategoryItem? created = await _EditCategorySheet.show(
      context,
      item: null,
      existingNames: _items.map((CategoryItem e) => e.name).toSet(),
    );
    if (created != null) {
      await _persist(<CategoryItem>[..._items, created]);
    }
  }

  Future<void> _editItem(int index) async {
    final CategoryItem current = _items[index];
    final Set<String> others = _items
        .where((CategoryItem e) => e.name != current.name)
        .map((CategoryItem e) => e.name)
        .toSet();
    final _EditResult? result = await _EditCategorySheet.showWithDelete(
      context,
      item: current,
      existingNames: others,
    );
    if (result == null) return;
    final List<CategoryItem> next = List<CategoryItem>.from(_items);
    if (result.deleted) {
      next.removeAt(index);
    } else if (result.item != null) {
      next[index] = result.item!;
    }
    await _persist(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        title: Text('Categorías', style: AppText.h2(c.textPrimary)),
        actions: [
          if (_saving)
            Padding(
              padding: const EdgeInsets.only(right: Insets.screen),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.brandPrimary,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(LucideIcons.plus, color: c.brandPrimary),
              tooltip: 'Agregar categoría',
              onPressed: _householdId == null ? null : _addItem,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.screen,
                    Insets.md,
                    Insets.screen,
                    Insets.md,
                  ),
                  child: _TypeSegment(
                    selected: _selectedType,
                    onChanged: (TxType t) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedType = t);
                    },
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? EmptyState(
                          icon: LucideIcons.tag,
                          title: 'Sin categorías',
                          message:
                              'Agregá categorías para clasificar tus movimientos.',
                          actionLabel:
                              _householdId == null ? null : 'Agregar categoría',
                          onAction: _householdId == null ? null : _addItem,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            Insets.screen,
                            0,
                            Insets.screen,
                            Insets.xxl,
                          ),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: Insets.md),
                          itemBuilder: (BuildContext context, int i) {
                            return _CategoryRow(
                              item: _items[i],
                              onTap: () => _editItem(i),
                            );
                          },
                        ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.screen,
                      0,
                      Insets.screen,
                      Insets.section,
                    ),
                    child: Text(
                      _error!,
                      style: AppText.caption(c.brandDanger),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
    );
  }
}

// ─────────────────────────────── Type segment ──────────────────────────────

/// Segmented gastos/ingresos con los chips del design system.
class _TypeSegment extends StatelessWidget {
  const _TypeSegment({required this.selected, required this.onChanged});

  final TxType selected;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MCChip(
          label: 'Gastos',
          icon: LucideIcons.arrowUpRight,
          selected: selected == TxType.gasto,
          onTap: () => onChanged(TxType.gasto),
        ),
        const SizedBox(width: Insets.md),
        MCChip(
          label: 'Ingresos',
          icon: LucideIcons.arrowDownLeft,
          selected: selected == TxType.ingreso,
          onTap: () => onChanged(TxType.ingreso),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Fila categoría ────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item, required this.onTap});

  final CategoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final int subCount = item.subcategories?.length ?? 0;

    return MCCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.cardLg,
        vertical: Insets.card,
      ),
      onTap: onTap,
      child: Row(
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
            child:
                Text(item.emoji ?? '📌', style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppText.body(c.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subCount > 0) ...[
                  const SizedBox(height: Insets.xxs),
                  Text(
                    subCount == 1
                        ? '1 subcategoría'
                        : '$subCount subcategorías',
                    style: AppText.caption(c.textMuted),
                  ),
                ],
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: c.textDim),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Edit sheet ────────────────────────────────

/// Resultado del editor: o se guardó un item, o se borró la categoría.
class _EditResult {
  const _EditResult({this.item, this.deleted = false});
  final CategoryItem? item;
  final bool deleted;
}

/// Editor de categoría (nombre + emoji + subcategorías). Cuando [item] es null
/// es alta (sin opción de borrar); con item, edición (incluye "Eliminar").
class _EditCategorySheet extends StatefulWidget {
  const _EditCategorySheet({
    required this.item,
    required this.existingNames,
  });

  final CategoryItem? item;
  final Set<String> existingNames;

  /// Alta: devuelve el [CategoryItem] creado (o null si canceló).
  static Future<CategoryItem?> show(
    BuildContext context, {
    required CategoryItem? item,
    required Set<String> existingNames,
  }) async {
    final _EditResult? r = await showWithDelete(
      context,
      item: item,
      existingNames: existingNames,
    );
    return r?.item;
  }

  /// Edición: devuelve un [_EditResult] (item editado o flag de borrado).
  static Future<_EditResult?> showWithDelete(
    BuildContext context, {
    required CategoryItem? item,
    required Set<String> existingNames,
  }) {
    final c = context.colors;
    return showModalBottomSheet<_EditResult>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          _EditCategorySheet(item: item, existingNames: existingNames),
    );
  }

  @override
  State<_EditCategorySheet> createState() => _EditCategorySheetState();
}

class _EditCategorySheetState extends State<_EditCategorySheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _subCtrl = TextEditingController();
  late String _emoji;
  late List<String> _subcategories;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.item?.name ?? '';
    _emoji = widget.item?.emoji ?? '📌';
    _subcategories =
        List<String>.from(widget.item?.subcategories ?? <String>[]);
    _nameCtrl.addListener(() => setState(() {}));
    _subCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  String get _name => _nameCtrl.text.trim();

  bool get _isValid {
    if (_name.isEmpty) return false;
    // No permitir duplicar el nombre de otra categoría del mismo tipo.
    return !widget.existingNames.contains(_name);
  }

  void _addSub() {
    final String trimmed = _subCtrl.text.trim();
    if (trimmed.isEmpty || _subcategories.contains(trimmed)) return;
    setState(() {
      _subcategories.add(trimmed);
      _subCtrl.clear();
    });
  }

  void _save() {
    if (!_isValid) return;
    Navigator.of(context).pop(
      _EditResult(
        item: CategoryItem(
          name: _name,
          emoji: _emoji,
          subcategories: _subcategories.isEmpty ? null : _subcategories,
        ),
      ),
    );
  }

  void _delete() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(const _EditResult(deleted: true));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool nameTaken =
        _name.isNotEmpty && widget.existingNames.contains(_name);

    return SafeArea(
      child: Padding(
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
              Row(
                children: [
                  Text(_emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: Insets.md),
                  Text(_isEditing ? 'Editar categoría' : 'Nueva categoría',
                      style: AppText.h2(c.textPrimary)),
                ],
              ),
              const SizedBox(height: Insets.section),
              AuthTextField(
                label: 'Nombre',
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
              ),
              if (nameTaken) ...[
                const SizedBox(height: Insets.sm),
                Text('Ya existe una categoría con ese nombre.',
                    style: AppText.caption(c.brandDanger)),
              ],
              const SizedBox(height: Insets.section),
              Text('EMOJI', style: AppText.label(c.textMuted)),
              const SizedBox(height: Insets.md),
              _EmojiGrid(
                selected: _emoji,
                onSelected: (String e) {
                  HapticFeedback.selectionClick();
                  setState(() => _emoji = e);
                },
              ),
              const SizedBox(height: Insets.section),
              Text('SUBCATEGORÍAS', style: AppText.label(c.textMuted)),
              const SizedBox(height: Insets.md),
              if (_subcategories.isNotEmpty) ...[
                Wrap(
                  spacing: Insets.md,
                  runSpacing: Insets.md,
                  children: _subcategories
                      .map((String s) => _SubChip(
                            label: s,
                            onRemove: () =>
                                setState(() => _subcategories.remove(s)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: Insets.md),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AuthTextField(
                      label: 'Nueva subcategoría',
                      controller: _subCtrl,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addSub(),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  _AddSubButton(
                    enabled: _subCtrl.text.trim().isNotEmpty,
                    onTap: _addSub,
                  ),
                ],
              ),
              const SizedBox(height: Insets.cardLg),
              MCPrimaryButton(
                label: 'Guardar',
                onPressed: _isValid ? _save : null,
              ),
              if (_isEditing) ...[
                const SizedBox(height: Insets.md),
                TextButton(
                  onPressed: _delete,
                  child: Text('Eliminar categoría',
                      style: AppText.body(c.brandDanger)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid de emojis (paleta del catálogo) con el seleccionado resaltado.
class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: CategoryCatalog.emojiPalette.map((String e) {
        final bool isSel = e == selected;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelected(e),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: isSel
                  ? c.brandPrimary.withValues(alpha: 0.2)
                  : c.appSurfaceInset,
              shape: SmoothRectangleBorder(
                borderRadius: Radii.smooth(Radii.badge),
                side: BorderSide(
                  color: isSel ? c.brandPrimary : c.appBorder,
                  width: isSel ? 1.5 : 1,
                ),
              ),
            ),
            child: Text(e, style: const TextStyle(fontSize: 20)),
          ),
        );
      }).toList(),
    );
  }
}

/// Chip de subcategoría con botón de quitar.
class _SubChip extends StatelessWidget {
  const _SubChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.only(
        left: Insets.card,
        right: Insets.md,
        top: Insets.sm,
        bottom: Insets.sm,
      ),
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: StadiumBorder(side: BorderSide(color: c.appBorder, width: 1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.caption(c.textPrimary)),
          const SizedBox(width: Insets.sm),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Icon(LucideIcons.x, size: 14, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Botón cuadrado "+" para agregar subcategoría (mismo look que los steppers).
class _AddSubButton extends StatelessWidget {
  const _AddSubButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

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
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.brandPrimary.withValues(alpha: 0.12),
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.input),
              side: BorderSide(color: c.appBorder, width: 1),
            ),
          ),
          child: Icon(LucideIcons.plus, size: 20, color: c.brandPrimary),
        ),
      ),
    );
  }
}
