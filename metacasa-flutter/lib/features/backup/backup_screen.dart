import 'dart:io';

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_providers.dart';
import 'export_service.dart';

/// Pantalla "Backup y exportar" (sub-pantalla de Ajustes). Espejo del
/// `BackupView` del iOS, reenfocado a **exportar** (esta wave es export-only;
/// el import queda como TODO documentado más abajo).
///
/// Flujo:
///   1. El usuario elige un rango (chips `MCChip`) — aplica a CSV y PDF.
///   2. Toca **Exportar CSV** / **Exportar PDF** / **Backup JSON**.
///   3. Se genera el contenido (puro Dart + Supabase), se escribe a un archivo
///      temporal (`path_provider`) y se abre el share sheet (`share_plus`).
///
/// El push de esta pantalla lo cablea el lead (fila "Backup y exportar" de
/// `settings_screen.dart` → `BackupScreen`). Acá no se toca el router.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  /// Rango seleccionado (aplica a CSV y PDF; el JSON siempre es el hogar
  /// completo, igual que el backup del iOS).
  ExportDateRange _range = ExportDateRange.currentMonth;

  /// Qué export está corriendo (para el spinner inline). null = ninguno.
  _ExportKind? _busy;

  /// Último error legible (se muestra en una card al pie).
  String? _error;

  bool get _anyBusy => _busy != null;

  @override
  Widget build(BuildContext context) {
    final MidnightSageColors c = context.colors;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        title: Text('Backup y exportar',
            style: AppText.serifInline(c.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.screen,
          Insets.md,
          Insets.screen,
          Insets.xxl,
        ),
        children: <Widget>[
          _intro(c),
          const SizedBox(height: Insets.section),
          _rangeSection(c),
          const SizedBox(height: Insets.section),
          _exportCard(
            c,
            kind: _ExportKind.csv,
            icon: LucideIcons.fileSpreadsheet,
            title: 'Exportar CSV',
            subtitle:
                'Planilla completa (23 columnas) lista para Excel, Sheets o tu contador.',
            cta: 'Exportar CSV',
          ),
          const SizedBox(height: Insets.section),
          _exportCard(
            c,
            kind: _ExportKind.pdf,
            icon: LucideIcons.fileText,
            title: 'Exportar PDF',
            subtitle:
                'Reporte con resumen, gastos por categoría y detalle de movimientos.',
            cta: 'Exportar PDF',
          ),
          const SizedBox(height: Insets.section),
          _exportCard(
            c,
            kind: _ExportKind.json,
            icon: LucideIcons.databaseBackup,
            title: 'Backup JSON',
            subtitle:
                'Copia de seguridad de todo el hogar: cuentas, movimientos, metas, presupuestos y más.',
            cta: 'Generar backup',
            // El JSON ignora el rango: respalda el historial completo.
            ignoresRange: true,
          ),
          const SizedBox(height: Insets.section),
          _importHint(c),
          if (_error != null) ...<Widget>[
            const SizedBox(height: Insets.section),
            _errorCard(c, _error!),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────── Secciones ───────────────────────────────

  Widget _intro(MidnightSageColors c) {
    return MCCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(LucideIcons.download, size: 20, color: c.brandPrimary),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Text(
              'Llevate tus datos cuando quieras. Generamos el archivo en tu '
              'dispositivo y lo compartís por el medio que prefieras.',
              style: AppText.caption(c.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeSection(MidnightSageColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.md),
          child: Text('RANGO (CSV Y PDF)', style: AppText.label(c.textMuted)),
        ),
        Wrap(
          spacing: Insets.md,
          runSpacing: Insets.md,
          children: <Widget>[
            for (final ExportDateRange r in ExportDateRange.values)
              MCChip(
                label: r.label,
                selected: _range == r,
                onTap: _anyBusy ? () {} : () => setState(() => _range = r),
              ),
          ],
        ),
      ],
    );
  }

  Widget _exportCard(
    MidnightSageColors c, {
    required _ExportKind kind,
    required IconData icon,
    required String title,
    required String subtitle,
    required String cta,
    bool ignoresRange = false,
  }) {
    final bool busy = _busy == kind;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: c.brandPrimary),
              const SizedBox(width: Insets.card),
              Expanded(child: Text(title, style: AppText.h2(c.textPrimary))),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(subtitle, style: AppText.caption(c.textMuted)),
          if (!ignoresRange) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text('Rango: ${_range.label}',
                style: AppText.caption(c.textDim)
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: Insets.cardLg),
          busy
              ? _BusyButton(label: 'Generando…')
              : MCPrimaryButton(
                  label: cta,
                  icon: LucideIcons.share2,
                  // Deshabilitado si OTRO export está corriendo.
                  onPressed: _anyBusy ? null : () => _run(kind),
                ),
        ],
      ),
    );
  }

  Widget _importHint(MidnightSageColors c) {
    // TODO(import): restaurar desde un backup JSON requiere `file_picker` (sin
    // dependencia en esta wave: export-only). Cuando se sume, replicar el
    // `restore(payload:)` de `Core/BackupService.swift` (dedup por fingerprint
    // fecha|tipo|monto|categoría|nota; agrega, no pisa).
    return Container(
      padding: const EdgeInsets.all(Insets.card),
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(LucideIcons.info, size: 16, color: c.textMuted),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              'Restaurar un backup llega pronto. Guardá tu archivo JSON en un '
              'lugar seguro mientras tanto.',
              style: AppText.caption(c.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(MidnightSageColors c, String msg) {
    return Container(
      padding: const EdgeInsets.all(Insets.card),
      decoration: ShapeDecoration(
        color: c.brandDanger.withValues(alpha: 0.12),
        shape: SmoothRectangleBorder(
          borderRadius: Radii.smooth(Radii.card),
          side:
              BorderSide(color: c.brandDanger.withValues(alpha: 0.4), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(LucideIcons.alertTriangle, size: 16, color: c.brandDanger),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(msg,
                style: AppText.caption(c.brandDanger)
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────── Acciones ────────────────────────────────

  /// Genera el export pedido y lo comparte. Resuelve el hogar activo, llama al
  /// [ExportService], escribe a un temp file y abre el share sheet. Todo el
  /// trabajo de plataforma (path_provider/share_plus) está guardado para no
  /// romper en `flutter test`.
  Future<void> _run(_ExportKind kind) async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (!mounted) return;
    if (householdId == null) {
      setState(() => _error = 'No hay un hogar seleccionado.');
      return;
    }

    setState(() {
      _busy = kind;
      _error = null;
    });
    HapticFeedback.selectionClick();

    try {
      final ExportService svc = ref.read(exportServiceProvider);
      final String householdSlug =
          (await ref.read(currentHouseholdProvider.future))?.name ?? 'hogar';

      switch (kind) {
        case _ExportKind.csv:
          final String csv = await svc.transactionsCsv(
            householdId: householdId,
            range: _range,
          );
          await _shareText(
            content: csv,
            fileName: _fileName(householdSlug, 'transactions', 'csv'),
            mimeType: 'text/csv',
          );
        case _ExportKind.pdf:
          final Uint8List pdf = await svc.transactionsPdf(
            householdId: householdId,
            range: _range,
          );
          await _shareBytes(
            bytes: pdf,
            fileName: _fileName(householdSlug, 'report', 'pdf'),
            mimeType: 'application/pdf',
          );
        case _ExportKind.json:
          final String json = await svc.jsonBackup(householdId);
          await _shareText(
            content: json,
            fileName: _backupFileName(),
            mimeType: 'application/json',
          );
      }
      if (mounted) HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo exportar: $e');
        HapticFeedback.heavyImpact();
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Escribe [content] (UTF-8) a un temp file y lo comparte.
  Future<void> _shareText({
    required String content,
    required String fileName,
    required String mimeType,
  }) async {
    final File file = await _writeTempFile(
      fileName: fileName,
      writer: (File f) => f.writeAsString(content, flush: true),
    );
    await _share(file, mimeType);
  }

  /// Escribe [bytes] a un temp file y lo comparte.
  Future<void> _shareBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final File file = await _writeTempFile(
      fileName: fileName,
      writer: (File f) => f.writeAsBytes(bytes, flush: true),
    );
    await _share(file, mimeType);
  }

  /// Resuelve el directorio temporal (path_provider) y escribe el archivo con
  /// el [writer] provisto. Devuelve el [File] escrito.
  Future<File> _writeTempFile({
    required String fileName,
    required Future<File> Function(File) writer,
  }) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/$fileName');
    return writer(file);
  }

  /// Abre el share sheet nativo con el archivo. En entornos sin binding de
  /// plataforma (tests/desktop) `share_plus` lanza; no propagamos para no
  /// ensuciar la UX con un "error" que no lo es.
  Future<void> _share(File file, String mimeType) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: mimeType)],
        ),
      );
    } on MissingPluginException {
      // Sin canal nativo (p. ej. test). El archivo quedó escrito; no-op.
    }
  }

  /// Nombre de archivo `<slug>-<kind>-<yyyy-MM-dd>.<ext>` (espejo del
  /// `makeFileName` del iOS, simplificado a la fecha de hoy).
  String _fileName(String householdName, String kind, String ext) {
    final String slug = _slug(householdName);
    final String stamp = _stampDate(DateTime.now());
    return '$slug-$kind-$stamp.$ext';
  }

  /// `home-finance_backup_<yyyyMMdd_HHmmss>.json` (espejo de
  /// `BackupService.writeJSONFile`).
  String _backupFileName() {
    final DateTime now = DateTime.now();
    final String stamp = '${_stampDate(now)}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return 'home-finance_backup_$stamp.json';
  }

  static String _stampDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Slugifica el nombre del hogar (lowercase, espacios → `-`, solo
  /// alfanuméricos + `-`).
  static String _slug(String name) {
    final String lower = name.toLowerCase().replaceAll(' ', '-');
    final String cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\-]'), '');
    final String collapsed = cleaned.replaceAll(RegExp(r'-+'), '-');
    final String trimmed = collapsed.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed.isEmpty ? 'hogar' : trimmed;
  }
}

/// Identifica qué export está corriendo (para el spinner y el deshabilitado).
enum _ExportKind { csv, pdf, json }

/// Botón "ocupado" con spinner — misma silueta del primario para que el layout
/// no salte. Idéntico al de `notification_settings_screen.dart`.
class _BusyButton extends StatelessWidget {
  const _BusyButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final MidnightSageColors c = context.colors;
    return Opacity(
      opacity: 0.7,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 54),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: c.brandPrimary,
          shape:
              SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.button)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0E1312)),
              ),
            ),
            const SizedBox(width: Insets.md),
            Text(
              label,
              style: AppText.body(const Color(0xFF0E1312))
                  .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
