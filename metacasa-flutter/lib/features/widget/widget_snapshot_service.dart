import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/utils/money.dart';

/// Sincroniza un snapshot financiero compacto a la home-screen widget nativa
/// (Android via `home_widget`). Port directo de `WidgetSnapshotSync` de iOS
/// (`Core/WidgetSnapshotSync.swift`): mismos campos, mismos nombres de clave,
/// mismo formateo de montos.
///
/// **Contrato de claves** (lo lee `BalanceWidgetProvider.kt` desde el
/// `SharedPreferences` `HomeWidgetPreferences`):
/// `householdName`, `currency`, `balanceMonth`, `ingresosMonth`, `gastosMonth`,
/// `nextBillTitle`, `nextBillAmount`, `nextBillInDays`, `updatedAt`.
///
/// Los montos se persisten YA FORMATEADOS (igual que iOS, que escribe strings
/// para no requerir `Locale`/`NumberFormat` dentro del proceso del widget).
///
/// Todas las llamadas a `HomeWidget` están guardadas: en `flutter test` y en
/// desktop el `MethodChannel` no tiene plugin nativo y tira
/// `MissingPluginException`; lo absorbemos para que el flujo principal nunca
/// se rompa por el widget (mismo espíritu del `guard … return` de iOS cuando el
/// App Group no existe).
class WidgetSnapshotService {
  const WidgetSnapshotService();

  /// Nombre del `AppWidgetProvider` Android (clase `.BalanceWidgetProvider`
  /// registrada en el `AndroidManifest`). `home_widget` lo usa para disparar el
  /// `onUpdate` tras persistir las prefs.
  static const String _androidProviderName = 'BalanceWidgetProvider';

  /// Nombre TOTALMENTE calificado de la clase del `AppWidgetProvider`. Hace
  /// falta porque el `applicationId` (`com.metacasa.app`) ≠ `namespace`
  /// (`com.metacasa.metacasa`): `home_widget` resuelve `androidName` como
  /// `<applicationId>.<name>` (= `com.metacasa.app.BalanceWidgetProvider`, que NO
  /// existe → `ClassNotFoundException`). Pasamos el path real vía
  /// `qualifiedAndroidName`.
  static const String _androidProviderQualified =
      'com.metacasa.metacasa.BalanceWidgetProvider';

  /// Locale de formateo de los montos del widget. Fijamos `es_AR` para
  /// consistencia con el resto de la app (todos los `Money.format` usan el
  /// default `es_AR`); el widget siempre muestra los números (no respeta el modo
  /// privacidad, igual que iOS).
  static const String _locale = 'es_AR';

  /// Escribe el snapshot más reciente y le pide al sistema que repinte el
  /// widget. No-op silencioso si no hay plugin nativo (test/desktop).
  ///
  /// - [householdName]: nombre del hogar activo.
  /// - [currencyCode]: ISO 4217 del hogar (define símbolo del monto).
  /// - [balanceMonth]/[ingresos]/[gastos]: cifras del período (sin formatear;
  ///   acá las formateamos con [Money]).
  /// - [nextBillTitle]/[nextBillAmount]/[nextBillInDays]: próximo vencimiento
  ///   (opcionales; si no hay, el widget oculta esa sección).
  Future<void> sync({
    required String householdName,
    required String currencyCode,
    required Decimal balanceMonth,
    required Decimal ingresos,
    required Decimal gastos,
    String? nextBillTitle,
    Decimal? nextBillAmount,
    String? nextBillCurrencyCode,
    int? nextBillInDays,
  }) async {
    try {
      final String balanceStr = _fmt(balanceMonth, currencyCode);
      final String ingresosStr = _fmt(ingresos, currencyCode);
      final String gastosStr = _fmt(gastos, currencyCode);
      final String? nextBillAmountStr = nextBillAmount == null
          ? null
          : _fmt(nextBillAmount, nextBillCurrencyCode ?? currencyCode);

      await Future.wait(<Future<bool?>>[
        HomeWidget.saveWidgetData<String>('householdName', householdName),
        HomeWidget.saveWidgetData<String>('currency', currencyCode),
        HomeWidget.saveWidgetData<String>('balanceMonth', balanceStr),
        HomeWidget.saveWidgetData<String>('ingresosMonth', ingresosStr),
        HomeWidget.saveWidgetData<String>('gastosMonth', gastosStr),
        // Las claves opcionales se escriben aun en null para limpiar un valor
        // previo (saveWidgetData con null borra la entrada).
        HomeWidget.saveWidgetData<String>('nextBillTitle', nextBillTitle),
        HomeWidget.saveWidgetData<String>('nextBillAmount', nextBillAmountStr),
        HomeWidget.saveWidgetData<int>('nextBillInDays', nextBillInDays),
        HomeWidget.saveWidgetData<String>(
          'updatedAt',
          DateTime.now().toUtc().toIso8601String(),
        ),
      ]);

      await HomeWidget.updateWidget(
        name: _androidProviderName,
        androidName: _androidProviderName,
        qualifiedAndroidName: _androidProviderQualified,
      );
    } catch (error, stack) {
      // Falla silenciosa: el widget es secundario. En test/desktop esto es
      // esperado (`MissingPluginException`); en device, un fallo del widget no
      // debe tumbar el dashboard. No logueamos montos (regla fintech), solo el
      // tipo de error en debug.
      if (kDebugMode) {
        debugPrint('WidgetSnapshotService.sync skipped: $error');
      }
      assert(() {
        // Mantenemos el stack disponible para debugging local sin romper prod.
        debugPrintStack(stackTrace: stack, label: 'widget snapshot');
        return true;
      }());
    }
  }

  /// Formatea un monto igual que el resto de la app: estilo compacto (sin
  /// decimales) y locale `es_AR`.
  String _fmt(Decimal value, String currencyCode) => Money.format(
        value,
        currencyCode: currencyCode,
        style: MoneyStyle.compact,
        locale: _locale,
      );
}

/// Provider del servicio de snapshot del widget. `const` singleton sin estado.
final widgetSnapshotServiceProvider = Provider<WidgetSnapshotService>(
  (ref) => const WidgetSnapshotService(),
);
