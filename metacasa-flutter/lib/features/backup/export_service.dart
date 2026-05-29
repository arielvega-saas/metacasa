import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../config/supabase_init.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../data/repositories/recurring_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../models/models.dart';

/// Rango de fechas para filtrar un export. Port 1:1 de `ExportDateRange`
/// (`Core/Exports/TransactionExport.swift`).
///
/// El `custom(from:to:)` del iOS lo dejamos fuera del enum (la UI de esta wave
/// solo ofrece los presets); si hiciera falta, se pasa el rango ya resuelto.
enum ExportDateRange {
  currentMonth,
  lastMonth,
  last30,
  last90,
  ytd,
  allTime;

  /// Etiqueta legible (es-AR) para los chips de selección.
  String get label => switch (this) {
        ExportDateRange.currentMonth => 'Este mes',
        ExportDateRange.lastMonth => 'Mes pasado',
        ExportDateRange.last30 => 'Últimos 30 días',
        ExportDateRange.last90 => 'Últimos 90 días',
        ExportDateRange.ytd => 'Año en curso',
        ExportDateRange.allTime => 'Todo el historial',
      };

  /// Resuelve a un par (from, to). Espejo de `ExportDateRange.resolved(now:)`
  /// del iOS — misma aritmética de calendario.
  ///
  /// - [currentMonth]: 1° del mes 00:00 → fin de mes 23:59:59.
  /// - [lastMonth]: 1° del mes anterior → 1 segundo antes del 1° de este mes.
  /// - [last30]/[last90]: `now − N días` → now.
  /// - [ytd]: 1° de enero → now.
  /// - [allTime]: epoch (1970-01-01) → now (rango "gigante" como en iOS).
  ({DateTime from, DateTime to}) resolved([DateTime? now]) {
    final DateTime ref = now ?? DateTime.now();
    switch (this) {
      case ExportDateRange.currentMonth:
        final DateTime start = DateTime(ref.year, ref.month, 1);
        // 1° del mes siguiente − 1 segundo (= fin de mes 23:59:59).
        final DateTime nextMonth = DateTime(ref.year, ref.month + 1, 1);
        final DateTime end = nextMonth.subtract(const Duration(seconds: 1));
        return (from: start, to: end);
      case ExportDateRange.lastMonth:
        final DateTime thisStart = DateTime(ref.year, ref.month, 1);
        final DateTime start = DateTime(ref.year, ref.month - 1, 1);
        final DateTime end = thisStart.subtract(const Duration(seconds: 1));
        return (from: start, to: end);
      case ExportDateRange.last30:
        return (from: ref.subtract(const Duration(days: 30)), to: ref);
      case ExportDateRange.last90:
        return (from: ref.subtract(const Duration(days: 90)), to: ref);
      case ExportDateRange.ytd:
        return (from: DateTime(ref.year, 1, 1), to: ref);
      case ExportDateRange.allTime:
        return (from: DateTime.fromMillisecondsSinceEpoch(0), to: ref);
    }
  }
}

/// Servicio de exportación de los datos financieros del hogar.
///
/// Tres salidas, todas portadas 1:1 de `Core/Exports/` + `Core/BackupService`
/// del iOS:
///   • [transactionsCsv]  → CSV full-dataset (23 columnas, BOM, RFC-4180).
///   • [transactionsPdf]  → reporte PDF US-Letter (summary + breakdown + tabla).
///   • [jsonBackup]        → backup JSON del hogar completo.
///
/// El servicio NO toca el filesystem ni el share sheet: devuelve el contenido
/// (`String`/`Uint8List`) y deja que la UI (`BackupScreen`) escriba el temp file
/// y dispare `share_plus`. Así queda testeable y desacoplado de los plugins.
class ExportService {
  ExportService(this._ref);

  final Ref _ref;

  // ───────────────────────────── CSV ─────────────────────────────

  /// Columnas del CSV — 23, en este orden EXACTO (port de
  /// `TransactionCSVExporter.columns`). No reordenar: hay analistas que
  /// pivotean por posición.
  static const List<String> csvColumns = <String>[
    'id',
    'date',
    'year',
    'month',
    'day',
    'weekday',
    'type',
    'signed_amount',
    'amount',
    'currency',
    'amount_base',
    'currency_base',
    'fx_rate',
    'fx_source',
    'fx_status',
    'category',
    'subcategory',
    'note',
    'account',
    'account_id',
    'user_id',
    'household_id',
    'created_at',
  ];

  /// Exporta las transacciones del rango como CSV (string con BOM al inicio).
  ///
  /// Port de `TransactionCSVExporter.export`:
  /// - **UTF-8 BOM** (`﻿`) como primer carácter → Excel/Windows detecta el
  ///   encoding (sin BOM rompe tildes/eñes). El caller escribe el string como
  ///   UTF-8 y el BOM viaja como los 3 bytes `EF BB BF`.
  /// - **RFC 4180**: separador `,`; valores con `,`/`"`/CR/LF van entre `"..."`
  ///   con `""` como escape de comilla.
  /// - **Número universal**: `.` decimal, sin agrupamiento, 2 decimales fijos
  ///   (ignora el locale a propósito — máxima interoperabilidad).
  /// - **Componentes de fecha en UTC** (year/month/day/weekday) para matchear
  ///   el `date` (midnight UTC) de Postgres.
  /// - **CRLF** entre filas + CRLF final.
  Future<String> transactionsCsv({
    required String householdId,
    required ExportDateRange range,
  }) async {
    final ({DateTime from, DateTime to}) bounds = range.resolved();
    final List<Transaction> txs = await _fetchTransactions(
      householdId: householdId,
      from: bounds.from,
      to: bounds.to,
    );
    final String baseCurrency = await _householdCurrency(householdId);

    final StringBuffer buf = StringBuffer();
    buf.write(csvColumns.join(','));
    buf.write('\r\n');

    for (final Transaction tx in txs) {
      final String type = tx.type == TxType.gasto ? 'expense' : 'income';
      final Decimal signed = tx.type == TxType.gasto ? -tx.amount : tx.amount;
      final ({Decimal? amount, String currency}) base = _resolveBaseAmount(
        tx: tx,
        householdCurrency: baseCurrency,
      );

      // Componentes en UTC (igual que el Calendar UTC del iOS).
      final DateTime utc = tx.date.toUtc();

      final List<String> row = <String>[
        tx.id,
        _isoDate(tx.date),
        '${utc.year}',
        '${utc.month}',
        '${utc.day}',
        '${_weekday1Sun(utc)}',
        type,
        _formatAmount(signed),
        _formatAmount(tx.amount),
        tx.currencyOriginal ?? baseCurrency,
        base.amount == null ? '' : _formatAmount(base.amount!),
        base.currency,
        tx.fxRateToBase == null ? '' : _formatAmount(tx.fxRateToBase!),
        tx.fxSource ?? '',
        tx.fxStatus ?? '',
        tx.category,
        tx.subcategory ?? '',
        tx.note ?? '',
        tx.account ?? '',
        tx.accountId ?? '',
        tx.userId,
        tx.householdId,
        tx.createdAt == null ? '' : _isoDateTime(tx.createdAt!),
      ];
      buf.write(row.map(_escape).join(','));
      buf.write('\r\n');
    }

    // BOM al frente (Excel/Windows). El string resultante arranca con ﻿;
    // al escribirse como UTF-8 produce los bytes EF BB BF.
    return '﻿${buf.toString()}';
  }

  /// Resuelve el monto en la moneda BASE del hogar. Port de
  /// `TransactionCSVExporter.resolveBaseAmount`:
  /// 1. tx ya en base → devuelve el amount tal cual.
  /// 2. hay `fxRateToBase` → amount × rate.
  /// 3. otra moneda sin rate → null (pendiente de conciliación).
  ({Decimal? amount, String currency}) _resolveBaseAmount({
    required Transaction tx,
    required String householdCurrency,
  }) {
    final String txCurrency = tx.currencyOriginal ?? householdCurrency;
    if (txCurrency == householdCurrency) {
      return (amount: tx.amount, currency: householdCurrency);
    }
    final Decimal? rate = tx.fxRateToBase;
    if (rate != null) {
      return (amount: tx.amount * rate, currency: householdCurrency);
    }
    return (amount: null, currency: householdCurrency);
  }

  /// Número universal: `.` decimal, SIN separador de miles, 2 decimales fijos.
  /// Equivalente del `NumberFormatter` en_US_POSIX del iOS, pero implementado a
  /// mano sobre el `Decimal` para no depender de `intl`/locale (que podría meter
  /// agrupamiento o coma decimal según el device).
  static String _formatAmount(Decimal value) {
    // Redondeo bancario-agnóstico a 2 decimales (half-up, igual que el
    // NumberFormatter por defecto de iOS) y render con punto fijo.
    final Decimal rounded = value.round(scale: 2);
    final bool negative = rounded < Decimal.zero;
    final Decimal abs = negative ? -rounded : rounded;

    // Parte entera y fraccionaria a partir del shift ×100 (evita issues de
    // toString con notación científica en valores grandes).
    final BigInt scaled = (abs * Decimal.fromInt(100)).toBigInt();
    final BigInt intPart = scaled ~/ BigInt.from(100);
    final BigInt fracPart = scaled % BigInt.from(100);
    final String frac = fracPart.toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$intPart.$frac';
  }

  /// RFC 4180 escape: envuelve en `"..."` si hay `,`/`"`/CR/LF; duplica `"`.
  static String _escape(String s) {
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// ISO 8601 solo-fecha (YYYY-MM-DD) en UTC.
  static String _isoDate(DateTime d) {
    final DateTime u = d.toUtc();
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }

  /// ISO 8601 con hora + fracción + `Z` (UTC). Espejo del `isoDateTime` del iOS
  /// (`withInternetDateTime + withFractionalSeconds`).
  static String _isoDateTime(DateTime d) => d.toUtc().toIso8601String();

  /// weekday 1=Domingo … 7=Sábado (convención del `Calendar` gregoriano del
  /// iOS). `DateTime.weekday` es 1=Lunes…7=Domingo, así que remapeamos.
  static int _weekday1Sun(DateTime d) => d.weekday == DateTime.sunday
      ? 1
      : d.weekday + 1; // Lun(1)→2 … Sáb(6)→7, Dom(7)→1

  // ───────────────────────────── PDF ─────────────────────────────

  /// Filas por página del reporte (calibrado para Letter con este layout).
  /// Mismo valor que `TransactionPDFExporter.rowsPerPage` del iOS.
  static const int _rowsPerPage = 24;

  /// Exporta un reporte PDF US-Letter de las transacciones del rango.
  ///
  /// Port de `TransactionPDFExporter`:
  /// - **Página US-Letter** vertical.
  /// - **Header**: nombre de la app, nombre del hogar y descripción del rango.
  /// - **Summary tiles**: Ingresos / Gastos / Balance (solo 1ª página).
  /// - **Breakdown por categoría**: top 10 + "Otros", barra + monto + % (solo
  ///   1ª página).
  /// - **Tabla de transacciones**: Fecha / Categoría / Nota / Monto, paginada.
  /// - **Footer**: "Generado con …" + "Página N / total".
  ///
  /// Sumas en [Decimal] (no double) para no perder precisión, igual que el iOS.
  Future<Uint8List> transactionsPdf({
    required String householdId,
    required ExportDateRange range,
  }) async {
    final ({DateTime from, DateTime to}) bounds = range.resolved();
    final List<Transaction> txs = await _fetchTransactions(
      householdId: householdId,
      from: bounds.from,
      to: bounds.to,
    );
    final Household? household = await _fetchHousehold(householdId);
    final String householdName = household?.name ?? 'Hogar';
    final String currency = household?.defaultCurrency ?? 'USD';

    // Totales en Decimal.
    Decimal totalIngresos = Decimal.zero;
    Decimal totalGastos = Decimal.zero;
    for (final Transaction tx in txs) {
      if (tx.type == TxType.ingreso) {
        totalIngresos += tx.amount;
      } else {
        totalGastos += tx.amount;
      }
    }
    final Decimal balance = totalIngresos - totalGastos;

    final List<_CategoryBreakdownItem> breakdown = _computeBreakdown(txs);
    final List<List<Transaction>> pages = _chunked(txs, _rowsPerPage);
    final List<List<Transaction>> iterPages =
        pages.isEmpty ? <List<Transaction>>[<Transaction>[]] : pages;
    final int totalPages = iterPages.length;

    final pw.Document doc = pw.Document();
    final String rangeDesc =
        '${_humanDate(bounds.from)} – ${_humanDate(bounds.to)}';

    for (int idx = 0; idx < iterPages.length; idx++) {
      final List<Transaction> pageRows = iterPages[idx];
      final bool first = idx == 0;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                _pdfHeader(householdName, rangeDesc),
                pw.SizedBox(height: 20),
                if (first) ...<pw.Widget>[
                  _pdfSummary(
                    totalIngresos: totalIngresos,
                    totalGastos: totalGastos,
                    balance: balance,
                    currency: currency,
                  ),
                  pw.SizedBox(height: 20),
                  if (breakdown.isNotEmpty) ...<pw.Widget>[
                    _pdfBreakdown(breakdown, currency),
                    pw.SizedBox(height: 20),
                  ],
                ],
                _pdfTable(pageRows, currency),
                pw.Spacer(),
                _pdfFooter(pageNumber: idx + 1, totalPages: totalPages),
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }

  /// Agrupa GASTOS por categoría, ordena desc y devuelve top 10 + "Otros".
  /// Port de `TransactionPDFExporter.computeCategoryBreakdown`.
  List<_CategoryBreakdownItem> _computeBreakdown(List<Transaction> txs) {
    final List<Transaction> expenses =
        txs.where((Transaction t) => t.type == TxType.gasto).toList();
    if (expenses.isEmpty) return <_CategoryBreakdownItem>[];

    Decimal total = Decimal.zero;
    final Map<String, Decimal> grouped = <String, Decimal>{};
    for (final Transaction tx in expenses) {
      total += tx.amount;
      grouped[tx.category] = (grouped[tx.category] ?? Decimal.zero) + tx.amount;
    }
    if (total <= Decimal.zero) return <_CategoryBreakdownItem>[];

    final List<_CategoryBreakdownItem> sorted = grouped.entries
        .map((MapEntry<String, Decimal> e) => _CategoryBreakdownItem(
            category: e.key, amount: e.value, total: total))
        .toList()
      ..sort((_CategoryBreakdownItem a, _CategoryBreakdownItem b) =>
          b.amount.compareTo(a.amount));

    const int topLimit = 10;
    if (sorted.length <= topLimit) return sorted;

    final List<_CategoryBreakdownItem> top = sorted.take(topLimit).toList();
    final Iterable<_CategoryBreakdownItem> rest = sorted.skip(topLimit);
    final Decimal restTotal = rest.fold(
      Decimal.zero,
      (Decimal acc, _CategoryBreakdownItem i) => acc + i.amount,
    );
    return <_CategoryBreakdownItem>[
      ...top,
      _CategoryBreakdownItem(
          category: 'Otros / Other', amount: restTotal, total: total),
    ];
  }

  // Colores del PDF (clavados; el reporte va sobre fondo blanco, no usa el
  // tema Midnight Sage — un PDF para contador/Excel se lee mejor en claro,
  // igual que el iOS, que fuerza Color.white/Color.black).
  static const PdfColor _pdfGray = PdfColor.fromInt(0xFF808080);
  static const PdfColor _pdfGreen = PdfColor.fromInt(0xFF1B873F);
  static const PdfColor _pdfRed = PdfColor.fromInt(0xFFD23F31);
  static const PdfColor _pdfTileBg = PdfColor.fromInt(0xFFF5F5F5);
  static const PdfColor _pdfBarBg = PdfColor.fromInt(0xFFEBEBEB);

  pw.Widget _pdfHeader(String householdName, String rangeDesc) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text('Home Finance',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _pdfGray)),
        pw.SizedBox(height: 4),
        pw.Text(householdName,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(rangeDesc,
            style: const pw.TextStyle(fontSize: 11, color: _pdfGray)),
      ],
    );
  }

  pw.Widget _pdfSummary({
    required Decimal totalIngresos,
    required Decimal totalGastos,
    required Decimal balance,
    required String currency,
  }) {
    return pw.Row(
      children: <pw.Widget>[
        _pdfSummaryTile(
            'Ingresos / Income', totalIngresos, _pdfGreen, currency),
        pw.SizedBox(width: 12),
        _pdfSummaryTile('Gastos / Expenses', -totalGastos, _pdfRed, currency),
        pw.SizedBox(width: 12),
        _pdfSummaryTile('Balance', balance,
            balance >= Decimal.zero ? _pdfGreen : _pdfRed, currency),
      ],
    );
  }

  pw.Widget _pdfSummaryTile(
      String label, Decimal amount, PdfColor color, String currency) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _pdfTileBg,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(label.toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfGray)),
            pw.SizedBox(height: 4),
            pw.Text(
              _money(amount, currency),
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfBreakdown(List<_CategoryBreakdownItem> items, String currency) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF7F7F7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text('GASTOS POR CATEGORÍA / EXPENSES BY CATEGORY',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfGray)),
          pw.SizedBox(height: 6),
          for (final _CategoryBreakdownItem item in items)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                children: <pw.Widget>[
                  pw.SizedBox(
                    width: 160,
                    child: pw.Text(
                      '${CategoryCatalog.emojiFor(item.category)} ${item.category}',
                      style: const pw.TextStyle(fontSize: 10),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ),
                  // Barra de progreso: en `pdf` no existe `FractionallySizedBox`,
                  // así que la armamos con dos `Expanded` de pesos enteros (fill
                  // vs resto) derivados del % — render idéntico al GeometryReader
                  // del iOS, sin necesitar las constraints.
                  pw.Expanded(child: _bar(item.percent)),
                  pw.SizedBox(
                    width: 95,
                    child: pw.Text(
                      _money(-item.amount, currency),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _pdfRed),
                    ),
                  ),
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text(
                      _percent(item.percent),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9, color: _pdfGray),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Barra de progreso horizontal (bg gris + fill coral) cuya proporción se
  /// expresa con dos `Expanded` de pesos enteros (escala 0–1000 para precisión
  /// de ~0.1 %). `pdf` no tiene `FractionallySizedBox`; esto lo emula.
  pw.Widget _bar(double percent) {
    final int filled = (percent.clamp(0.0, 1.0) * 1000).round();
    final int empty = 1000 - filled;
    return pw.Container(
      height: 8,
      decoration: pw.BoxDecoration(
        color: _pdfBarBg,
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          if (filled > 0)
            pw.Expanded(
              flex: filled,
              child: pw.Container(
                height: 8,
                decoration: pw.BoxDecoration(
                  color: _pdfRed,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
            ),
          if (empty > 0) pw.Expanded(flex: empty, child: pw.SizedBox()),
        ],
      ),
    );
  }

  pw.Widget _pdfTable(List<Transaction> rows, String currency) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        // Header de columnas.
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: const pw.BoxDecoration(
            border:
                pw.Border(bottom: pw.BorderSide(color: _pdfGray, width: 0.5)),
          ),
          child: pw.Row(
            children: <pw.Widget>[
              pw.SizedBox(width: 65, child: _th('FECHA')),
              pw.SizedBox(width: 120, child: _th('CATEGORÍA')),
              pw.Expanded(child: _th('NOTA')),
              pw.SizedBox(
                  width: 90, child: _th('MONTO', align: pw.TextAlign.right)),
            ],
          ),
        ),
        for (int i = 0; i < rows.length; i++)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: i < rows.length - 1
                ? const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(
                            color: PdfColor.fromInt(0x26808080), width: 0.5)),
                  )
                : null,
            child: pw.Row(
              children: <pw.Widget>[
                pw.SizedBox(
                  width: 65,
                  child: pw.Text(_shortDate(rows[i].date),
                      style: const pw.TextStyle(fontSize: 10)),
                ),
                pw.SizedBox(
                  width: 120,
                  child: pw.Text(
                    '${CategoryCatalog.emojiFor(rows[i].category)} ${rows[i].category}',
                    style: const pw.TextStyle(fontSize: 10),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(rows[i].note ?? '',
                      style: const pw.TextStyle(fontSize: 10),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip),
                ),
                pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                    _txAmount(rows[i], currency),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 10,
                        color:
                            rows[i].type == TxType.gasto ? _pdfRed : _pdfGreen),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _th(String label, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Text(label,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfGray));

  pw.Widget _pdfFooter({required int pageNumber, required int totalPages}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Text('Generado con Home Finance',
            style: const pw.TextStyle(fontSize: 8, color: _pdfGray)),
        pw.Text('Página $pageNumber / $totalPages',
            style: const pw.TextStyle(fontSize: 8, color: _pdfGray)),
      ],
    );
  }

  /// Monto compacto (sin decimales) con símbolo de moneda — `Money.format`
  /// con estilo compact, locale es-AR (el reporte sale en es-AR como el resto
  /// de esta wave). Para gastos en el summary/breakdown ya pasamos el valor
  /// negativo desde el call-site.
  String _money(Decimal value, String currency) =>
      Money.format(value, currencyCode: currency, style: MoneyStyle.compact);

  /// Monto de una fila de la tabla: gasto en negativo, ingreso positivo.
  String _txAmount(Transaction tx, String currency) {
    final Decimal amt = tx.type == TxType.gasto ? -tx.amount : tx.amount;
    return Money.format(amt,
        currencyCode: tx.currencyOriginal ?? currency,
        style: MoneyStyle.compact);
  }

  /// "12 % " — porcentaje con 1 decimal como máximo, sin decimal si es entero.
  static String _percent(double v) {
    final double pct = v * 100;
    final String s = pct == pct.roundToDouble()
        ? pct.toStringAsFixed(0)
        : pct.toStringAsFixed(1);
    return '$s%';
  }

  /// "12 abr" — día + mes abreviado en es (UTC, para no shiftear el día).
  static String _shortDate(DateTime d) {
    final DateTime u = d.toUtc();
    return '${u.day} ${_monthAbbr(u.month)}';
  }

  /// "12 abr 2026" — para el header del reporte.
  static String _humanDate(DateTime d) {
    final DateTime u = d.toUtc();
    return '${u.day} ${_monthAbbr(u.month)} ${u.year}';
  }

  static String _monthAbbr(int m) => const <String>[
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ][(m - 1).clamp(0, 11)];

  static List<List<T>> _chunked<T>(List<T> list, int size) {
    if (size <= 0) return <List<T>>[list];
    final List<List<T>> out = <List<T>>[];
    for (int i = 0; i < list.length; i += size) {
      out.add(list.sublist(i, (i + size).clamp(0, list.length)));
    }
    return out;
  }

  // ───────────────────────────── JSON ─────────────────────────────

  /// Versión del schema del backup. Aumentar al cambiar el shape. Espejo de
  /// `BackupService.Payload.schemaVersion` del iOS.
  static const int backupSchemaVersion = 1;

  /// Construye el backup JSON del hogar completo y lo devuelve pretty-printed.
  ///
  /// Port de `BackupService.build` + `writeJSONFile`:
  /// - Lee TODAS las entidades del hogar (rango amplio: 10 años de tx, 2 años de
  ///   budget periods) vía los repos + queries directas (igual que iOS, que usa
  ///   `SupabaseRPC.select` para `budget_periods`/allocations/credit_cards).
  /// - Serializa con `version`, `exportedAt` (ISO 8601), `householdId` y un array
  ///   por entidad. Claves ordenadas + indentado (paridad con `sortedKeys +
  ///   prettyPrinted`).
  /// - Fechas como ISO 8601 (las dejamos tal cual las devuelve PostgREST en los
  ///   `toJson` de los modelos — son strings ISO/`date`).
  Future<String> jsonBackup(String householdId) async {
    final DateTime now = DateTime.now();
    final DateTime txFrom = DateTime(now.year - 10, now.month, now.day);
    final DateTime periodsFrom = DateTime(now.year - 2, now.month, now.day);

    final Household? household = await _fetchHousehold(householdId);
    final List<Account> accounts = await _ref
        .read(accountRepositoryProvider)
        .fetchAll(householdId, includingInactive: true);
    final CategoriesBlob? categories =
        await _ref.read(categoryRepositoryProvider).fetch(householdId);
    final List<Transaction> transactions =
        await _ref.read(transactionRepositoryProvider).fetchRange(
              householdId: householdId,
              from: txFrom,
              to: now,
              limit: 50000,
            );
    final List<RecurringTransaction> recurring = await _ref
        .read(recurringRepositoryProvider)
        .fetchAll(householdId: householdId, includeInactive: true);
    final List<Goal> goals = await _ref
        .read(goalRepositoryProvider)
        .fetchAll(householdId: householdId, includeCompleted: true);

    // Budget periods + allocations: query directa (el BudgetRepository solo
    // resuelve por mes; el iOS también lee la tabla cruda para el backup).
    final List<Map<String, dynamic>> periodsRaw = await _selectRaw(
      table: 'budget_periods',
      householdId: householdId,
      filter: (dynamic q) => q
          .gte('period_start', _dateOnly(periodsFrom))
          .order('period_start', ascending: false),
    );
    final List<Map<String, dynamic>> allocationsRaw = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> p in periodsRaw) {
      final Object? pid = p['id'];
      if (pid is String) {
        final List<dynamic> rows = await supabase
            .from('budget_allocations')
            .select()
            .eq('period_id', pid);
        allocationsRaw.addAll(rows.cast<Map<String, dynamic>>());
      }
    }

    // Goal contributions por meta.
    final List<Map<String, dynamic>> contributionsRaw =
        <Map<String, dynamic>>[];
    for (final Goal g in goals) {
      final List<dynamic> rows = await supabase
          .from('goal_contributions')
          .select()
          .eq('goal_id', g.id)
          .order('contributed_at', ascending: false);
      contributionsRaw.addAll(rows.cast<Map<String, dynamic>>());
    }

    // Credit cards de las cuentas type=creditCard.
    final List<Map<String, dynamic>> cardsRaw = <Map<String, dynamic>>[];
    for (final Account acc in accounts) {
      if (acc.type == AccountType.creditCard) {
        final Map<String, dynamic>? row = await supabase
            .from('credit_cards')
            .select()
            .eq('account_id', acc.id)
            .maybeSingle();
        if (row != null) cardsRaw.add(row);
      }
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'version': backupSchemaVersion,
      'exportedAt': now.toUtc().toIso8601String(),
      'householdId': householdId,
      'household': household?.toJson(),
      'accounts':
          accounts.map((Account a) => a.toJson()).toList(growable: false),
      'categoriesBlob': categories?.toJson(),
      'transactions': transactions
          .map((Transaction t) => t.toJson())
          .toList(growable: false),
      'recurring': recurring
          .map((RecurringTransaction r) => r.toJson())
          .toList(growable: false),
      'budgetPeriods': periodsRaw,
      'budgetAllocations': allocationsRaw,
      'goals': goals.map((Goal g) => g.toJson()).toList(growable: false),
      'goalContributions': contributionsRaw,
      'creditCards': cardsRaw,
    };

    // Pretty-printed + claves ordenadas (paridad con sortedKeys del iOS).
    const JsonEncoder encoder = JsonEncoder.withIndent('  ', _jsonSafe);
    return encoder.convert(_sortKeysDeep(payload));
  }

  /// Hace JSON-safe los valores que `jsonEncode` no sabe serializar de fábrica
  /// (p. ej. un `Decimal` que se colara). Convertimos a String — pero los
  /// `toJson()` de los modelos ya devuelven strings para `Decimal`, así que es
  /// defensivo.
  static Object? _jsonSafe(Object? value) => value.toString();

  /// Ordena recursivamente las claves de los mapas (alfabético) para producir
  /// una salida estable y diff-eable, igual que el `.sortedKeys` del iOS.
  static Object? _sortKeysDeep(Object? value) {
    if (value is Map) {
      final List<String> keys =
          value.keys.map((Object? k) => k.toString()).toList()..sort();
      return <String, Object?>{
        for (final String k in keys) k: _sortKeysDeep(value[k]),
      };
    }
    if (value is List) {
      return value.map(_sortKeysDeep).toList();
    }
    return value;
  }

  // ─────────────────────────── helpers ───────────────────────────

  /// Fetch de transacciones del rango con techo alto (un export no debe quedar
  /// capado por el `limit` default de 200 del repo). Espejo del `limit: 50_000`
  /// que usa el iOS.
  Future<List<Transaction>> _fetchTransactions({
    required String householdId,
    required DateTime from,
    required DateTime to,
  }) {
    return _ref.read(transactionRepositoryProvider).fetchRange(
          householdId: householdId,
          from: from,
          to: to,
          limit: 50000,
        );
  }

  Future<Household?> _fetchHousehold(String householdId) async {
    final List<Household> all =
        await _ref.read(householdRepositoryProvider).fetchMine();
    for (final Household h in all) {
      if (h.id == householdId) return h;
    }
    return all.isEmpty ? null : all.first;
  }

  Future<String> _householdCurrency(String householdId) async {
    final Household? h = await _fetchHousehold(householdId);
    return h?.defaultCurrency ?? 'USD';
  }

  /// `select * where household_id = ...` + filtro adicional, devuelto como
  /// lista de mapas crudos (para entidades sin modelo dedicado en el backup).
  Future<List<Map<String, dynamic>>> _selectRaw({
    required String table,
    required String householdId,
    required dynamic Function(dynamic query) filter,
  }) async {
    final dynamic base =
        supabase.from(table).select().eq('household_id', householdId);
    final List<dynamic> rows = await filter(base) as List<dynamic>;
    return rows.cast<Map<String, dynamic>>();
  }

  static String _dateOnly(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Fila del breakdown por categoría del PDF (privada). Espejo de
/// `CategoryBreakdownItem` del iOS.
class _CategoryBreakdownItem {
  _CategoryBreakdownItem({
    required this.category,
    required this.amount,
    required this.total,
  });

  final String category;
  final Decimal amount;
  final Decimal total;

  /// Proporción [0,1] del gasto total.
  double get percent {
    if (total <= Decimal.zero) return 0;
    return amount.toDouble() / total.toDouble();
  }
}

/// Provider del [ExportService].
final Provider<ExportService> exportServiceProvider =
    Provider<ExportService>((Ref ref) => ExportService(ref));
