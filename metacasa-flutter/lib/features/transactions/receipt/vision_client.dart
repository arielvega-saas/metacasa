import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_init.dart';

/// Una transacción (gasto) extraída de UNA imagen de recibo/ticket/listado de
/// wallet por el modelo de visión. Clase plana (sin freezed/codegen) — el
/// review sheet la copia a un estado mutable antes de insertar.
///
/// Espejo del `ParsedReceipt` de iOS (`Core/Multimodal/ReceiptParser.swift`),
/// pero con campos NO opcionales: ya saneados con fallbacks en
/// [ReceiptVisionClient._decode] (monto siempre > 0, fecha = hoy si falta,
/// comercio/categoría/moneda con defaults). El usuario los revisa y edita en
/// la hoja antes de confirmar, así que arrancan con valores usables.
class ParsedReceiptTx {
  ParsedReceiptTx({
    required this.amount,
    required this.date,
    required this.merchant,
    required this.currency,
    required this.category,
  });

  /// Monto del gasto, SIEMPRE positivo (valor absoluto). El modelo lo devuelve
  /// como número decimal según las reglas de lectura LatAm/en del prompt.
  final Decimal amount;

  /// Fecha del gasto. Si la imagen no la traía, cae a `DateTime.now()` en el
  /// decode (igual que iOS, que usa `receipt.date ?? Date()` al insertar).
  final DateTime date;

  /// Nombre limpio del comercio o destinatario (sin "Transferencia a", CUIT,
  /// IDs de operación). Puede quedar vacío si el modelo no lo identificó.
  final String merchant;

  /// Código ISO 4217 de la moneda detectada (ej. `ARS`, `USD`, `BRL`).
  final String currency;

  /// Categoría sugerida (una del catálogo del prompt). Cae a `Otros`.
  final String category;
}

/// Cliente de extracción de transacciones desde imágenes vía visión de Claude
/// Haiku 4.5 a través de la Edge Function `ai-proxy`.
///
/// Port 1:1 de `AnthropicProvider.parseImageReceipts(jpegDatas:accessToken:)`
/// de iOS (`Core/AI/Providers/AnthropicProvider.swift`). Las imágenes van
/// DIRECTO al modelo como bloques `image` base64 — no hay OCR intermedio. Una
/// sola request procesa N imágenes y devuelve TODOS los gastos detectados.
///
/// **Privacidad**: la API key de Anthropic nunca llega al cliente. El proxy
/// valida el JWT (lo adjunta `supabase_flutter`) y forwardea con el secret
/// server-side. Rate limit server-side (50/día, 1000/mes por user).
class ReceiptVisionClient {
  const ReceiptVisionClient();

  /// Modelo fijo con visión (igual que iOS). El proxy igual lo valida.
  static const String model = 'claude-haiku-4-5-20251001';
  static const int maxTokens = 1024;

  /// System prompt de extracción — PORTADO VERBATIM del `parseImageReceipts`
  /// de iOS. Reglas de lectura de montos LatAm (es) / en, GASTOS solamente,
  /// salida JSON estricta sin markdown.
  static const String extractionPrompt = '''
Sos un experto en analizar imágenes de recibos, tickets, comprobantes y screenshots de listados de transacciones (de wallets como MercadoPago, Naranja X, Brubank, Uala, o cualquier app financiera). Tu única salida debe ser un JSON válido — sin explicaciones, sin markdown, sin bloques de código.

Estructura esperada:
{"transactions": [
  {"amount": <número decimal positivo>, "date": "<YYYY-MM-DD o null>", "merchant": "<nombre o null>", "currency": "<código ISO o null>", "category": "<categoría o null>"}
]}

Si te paso varias imágenes, agregá los gastos de TODAS al mismo array (no las separes).

REGLAS DE LECTURA DE MONTOS — críticas, leelas con atención:
- Mirá el número exactamente como aparece. NO redondees, NO inventes decimales que no están.
- El separador de miles en español rioplatense es "." y el decimal es ",". "\$ 23.100" = 23100.00 (veintitres mil cien). "\$ 1.250,50" = 1250.50.
- El separador de miles en inglés es "," y el decimal es ".". "\$1,250.50" = 1250.50.
- Si ves "\$ 4.090" sin coma decimal → es 4090, NO 4.09 ni 4090.00 con .00 espureo.
- Si ves "\$23.100" → es 23100, NO 23.10.
- Cuando hay duda entre un número grande sin decimales y uno pequeño con decimales, mirá el contexto: en Argentina los gastos de wallet suelen ser miles (\$1.000-\$50.000), no centavos.
- Solo tomá el monto del gasto en sí, ignorá saldos, totales acumulados, números de operación, CBU/alias, fechas.

REGLAS GENERALES:
- Si es UN ticket/recibo de compra → un solo elemento por imagen.
- Si es un LISTADO de movimientos de wallet → un elemento por cada gasto.
- Solo incluí GASTOS (transferencias enviadas, pagos, débitos). Ignorá ingresos, transferencias recibidas y saldos.
- amount: SIEMPRE positivo (valor absoluto del gasto).
- merchant: nombre limpio del comercio o destinatario. Sin "Transferencia a", sin CUIT, sin números de operación, sin "Pago de servicio".
- currency: detectá por símbolo o contexto. "\$" en wallets argentinas (Naranja X, Mercado Pago, Brubank, Uala) → "ARS". "R\$" → "BRL". "€" → "EUR". null si no hay info clara.
- date: si la fila no tiene fecha pero hay un encabezado cercano (ej. "4 de mayo"), usá esa. Año actual si no se ve.
- category: una de "Alimentación", "Transporte", "Salud", "Suscripciones", "Servicios", "Ropa", "Entretenimiento", "Educación", "Hogar", "Transferencias", "Otros".

Si no identificás NINGÚN gasto → devolvé {"transactions": []}.''';

  /// Extrae las transacciones (gastos) de [jpegs]. Una sola request al proxy
  /// con un bloque `image` por cada JPEG + un bloque de texto con la consigna.
  ///
  /// Devuelve la lista consolidada (puede venir de varias imágenes). Si el
  /// modelo no identificó ningún gasto, devuelve una lista vacía.
  ///
  /// Lanza [ReceiptVisionException] (mensajes en español rioplatense) ante:
  /// sin sesión, rate limit (429), error HTTP (>=400), o JSON inválido.
  Future<List<ParsedReceiptTx>> parseReceipts(List<Uint8List> jpegs) async {
    if (jpegs.isEmpty) return const <ParsedReceiptTx>[];

    if (!supabaseReady) {
      throw const ReceiptVisionException(ReceiptVisionErrorKind.noSession);
    }
    final SupabaseClient client = supabase;
    if (client.auth.currentSession == null) {
      throw const ReceiptVisionException(ReceiptVisionErrorKind.noSession);
    }

    // Bloques de contenido: una imagen base64 por JPEG + la consigna de texto
    // al final (mismo orden que iOS: imágenes, luego el prompt del usuario).
    final List<Map<String, dynamic>> content = <Map<String, dynamic>>[
      for (final Uint8List jpeg in jpegs)
        <String, dynamic>{
          'type': 'image',
          'source': <String, dynamic>{
            'type': 'base64',
            'media_type': 'image/jpeg',
            'data': base64Encode(jpeg),
          },
        },
      <String, dynamic>{
        'type': 'text',
        'text': jpegs.length == 1
            ? 'Identificá todos los gastos de esta imagen y devolveme el JSON.'
            : 'Identificá todos los gastos de las ${jpegs.length} imágenes y '
                'devolveme el JSON consolidado.',
      },
    ];

    final Map<String, dynamic> body = <String, dynamic>{
      'system': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'text',
          'text': extractionPrompt,
          'cache_control': <String, dynamic>{'type': 'ephemeral'},
        },
      ],
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{'role': 'user', 'content': content},
      ],
      'model': model,
      'max_tokens': maxTokens,
    };

    final FunctionResponse res;
    try {
      res = await client.functions.invoke('ai-proxy', body: body);
    } on FunctionException catch (e) {
      if (e.status == 429) {
        throw const ReceiptVisionException(ReceiptVisionErrorKind.rateLimit);
      }
      throw ReceiptVisionException.api(e.status);
    } catch (_) {
      throw const ReceiptVisionException(ReceiptVisionErrorKind.network);
    }

    if (res.status == 429) {
      throw const ReceiptVisionException(ReceiptVisionErrorKind.rateLimit);
    }
    if (res.status < 200 || res.status >= 300) {
      throw ReceiptVisionException.api(res.status);
    }

    final dynamic data = res.data;
    if (data is! Map) {
      throw const ReceiptVisionException(
          ReceiptVisionErrorKind.invalidResponse);
    }

    final String text = _extractText(Map<String, dynamic>.from(data));
    return _decode(text);
  }

  /// Concatena los bloques `type:text` del `content` de la respuesta Anthropic
  /// (espejo de `extractText(from:)` de iOS).
  static String _extractText(Map<String, dynamic> json) {
    final List<dynamic> content =
        (json['content'] as List<dynamic>?) ?? const <dynamic>[];
    final List<String> texts = <String>[];
    for (final dynamic block in content) {
      if (block is! Map) continue;
      if (block['type'] == 'text') {
        final String? t = block['text'] as String?;
        if (t != null && t.isNotEmpty) texts.add(t);
      }
    }
    return texts.join('\n');
  }

  /// Parsea el texto de la respuesta como JSON `{transactions:[...]}` y mapea a
  /// [ParsedReceiptTx], saneando cada fila (monto > 0, fecha = hoy si falta,
  /// defaults de comercio/moneda/categoría). Port de `decodeReceiptsJSON` de
  /// iOS (que descarta filas sin monto positivo).
  static List<ParsedReceiptTx> _decode(String raw) {
    // El modelo a veces envuelve en ```json … ``` pese al prompt: limpiamos.
    final String cleaned =
        raw.replaceAll('```json', '').replaceAll('```', '').trim();
    if (cleaned.isEmpty) {
      throw const ReceiptVisionException(
          ReceiptVisionErrorKind.invalidResponse);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      throw const ReceiptVisionException(
          ReceiptVisionErrorKind.invalidResponse);
    }
    if (decoded is! Map) {
      throw const ReceiptVisionException(
          ReceiptVisionErrorKind.invalidResponse);
    }

    final List<dynamic> rows =
        (decoded['transactions'] as List<dynamic>?) ?? const <dynamic>[];
    final DateTime now = DateTime.now();
    final List<ParsedReceiptTx> result = <ParsedReceiptTx>[];

    for (final dynamic row in rows) {
      if (row is! Map) continue;
      final Map<String, dynamic> r = Map<String, dynamic>.from(row);

      final Decimal? amount = _amountOf(r['amount']);
      // Descartamos filas sin monto positivo (igual que iOS).
      if (amount == null || amount <= Decimal.zero) continue;

      result.add(ParsedReceiptTx(
        amount: amount,
        date: _dateOf(r['date']) ?? now,
        merchant: _stringOf(r['merchant']) ?? '',
        currency: (_stringOf(r['currency']) ?? '').toUpperCase(),
        category: _stringOf(r['category']) ?? 'Otros',
      ));
    }
    return result;
  }

  /// Normaliza el monto del JSON (num o String) a [Decimal]. El modelo suele
  /// devolver un número, pero toleramos string por las dudas.
  static Decimal? _amountOf(dynamic value) {
    if (value is num) {
      return Decimal.tryParse(value.toString());
    }
    if (value is String && value.trim().isNotEmpty) {
      return Decimal.tryParse(value.trim());
    }
    return null;
  }

  /// Parsea `YYYY-MM-DD` (o un ISO más largo) a [DateTime] local. Null si el
  /// campo venía vacío o ilegible.
  static DateTime? _dateOf(dynamic value) {
    final String? s = _stringOf(value);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  /// String no vacío, o null (el modelo manda `null`/`""` para faltantes).
  static String? _stringOf(dynamic value) {
    if (value is String) {
      final String t = value.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }
}

/// Provider del [ReceiptVisionClient]. Singleton sin estado (la sesión y el
/// cliente Supabase son globales), igual que `anthropicProxyProvider`.
final receiptVisionClientProvider = Provider<ReceiptVisionClient>(
  (ref) => const ReceiptVisionClient(),
);

/// Categoría de error de la extracción por visión.
enum ReceiptVisionErrorKind {
  noSession,
  rateLimit,
  api,
  invalidResponse,
  network,
}

/// Error tipado de la extracción de recibos, con mensaje amigable en español
/// rioplatense. Espejo de `AnthropicError` de iOS, acotado a este flujo.
class ReceiptVisionException implements Exception {
  const ReceiptVisionException(this.kind, {this.status = 0});

  factory ReceiptVisionException.api(int status) =>
      ReceiptVisionException(ReceiptVisionErrorKind.api, status: status);

  final ReceiptVisionErrorKind kind;
  final int status;

  /// Mensaje listo para mostrar (SnackBar / banner), rioplatense.
  String get friendlyMessage => switch (kind) {
        ReceiptVisionErrorKind.noSession =>
          'No hay sesión activa para escanear recibos. Volvé a iniciar sesión.',
        ReceiptVisionErrorKind.rateLimit =>
          'Llegaste al límite de uso de la IA por hoy. Probá mañana o cargá el '
              'gasto a mano.',
        ReceiptVisionErrorKind.api =>
          'No pudimos leer el recibo (HTTP $status). Probá de nuevo en un momento.',
        ReceiptVisionErrorKind.invalidResponse =>
          'No pudimos interpretar el recibo. Probá con una foto más nítida.',
        ReceiptVisionErrorKind.network =>
          'No pude conectarme para leer el recibo. Revisá tu conexión y '
              'probá de nuevo.',
      };

  @override
  String toString() => 'ReceiptVisionException($kind, status: $status)';
}
