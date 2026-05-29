import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Providers de **preferencias de app** persistidas localmente (no van a
/// Supabase): apariencia (tema) e idioma. Espejo de `AppearanceManager` y
/// `AppLocaleManager` de iOS, que guardan en `UserDefaults`; acá usamos
/// `shared_preferences` con la misma semántica (single source of truth local,
/// default dark / seguir-sistema).
///
/// Ambos son `NotifierProvider` que cargan el valor persistido en `build()` de
/// forma asíncrona y lo publican cuando llega; mientras tanto exponen el default
/// (dark / null) para que `MaterialApp` arranque sin parpadeo. La escritura es
/// fire-and-forget (no bloquea la UI).

/// Clave de `shared_preferences` para el modo de tema. Misma intención que el
/// `app_appearance_preference` de iOS, renombrada al contrato pedido por el
/// equipo Flutter.
const String kPrefThemeModeKey = 'pref_theme_mode';

/// Clave de `shared_preferences` para el override de idioma. `null`/ausente =
/// seguir el device (equivalente al `SupportedLocale.system` de iOS).
const String kPrefLocaleKey = 'pref_locale';

// ─────────────────────────────── Tema ──────────────────────────────────────

/// Notifier del [ThemeMode] de la app. Default [ThemeMode.dark] (dark-first,
/// igual que iOS). Carga el valor persistido en `build()` y lo publica al
/// resolver; cada cambio se persiste como string (`light`/`dark`/`system`).
class AppearanceModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Carga diferida del valor persistido. Devolvemos el default sincrónicamente
    // para que `MaterialApp` no espere a disco; cuando llega, `state` se
    // actualiza y el árbol se re-pinta con el tema elegido.
    _restore();
    return ThemeMode.dark;
  }

  Future<void> _restore() async {
    // Defensivo: si el plugin no está disponible (p. ej. `flutter test` sin
    // binding registrado) o falla la lectura, conservamos el default en vez de
    // tumbar el árbol con una excepción async no manejada.
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ThemeMode? restored = _decode(prefs.getString(kPrefThemeModeKey));
      if (restored != null && restored != state) {
        state = restored;
      }
    } catch (_) {
      // Sin persistencia: nos quedamos en el default (dark).
    }
  }

  /// Fija el modo y lo persiste (fire-and-forget). Idempotente.
  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefThemeModeKey, _encode(mode));
  }

  static ThemeMode? _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

/// Provider del [ThemeMode] activo. Lo observa `MaterialApp.themeMode` en
/// `app.dart`; el picker de Apariencia lo muta vía `.notifier.set(...)`.
final appearanceModeProvider =
    NotifierProvider<AppearanceModeNotifier, ThemeMode>(
  AppearanceModeNotifier.new,
);

// ─────────────────────────────── Idioma ────────────────────────────────────

/// Override de idioma de la app. `null` = seguir el device (el comportamiento
/// por default, espejo de `SupportedLocale.system`). Un valor fuerza ese idioma
/// (`Locale('es')`, `Locale('en')`, `Locale('pt')`).
///
/// Persistimos solo el `languageCode` (las tres opciones del catálogo no llevan
/// `countryCode`; el formateo regional de montos lo decide `AmountText` a partir
/// del locale resuelto). Un string vacío/ausente = `null` = seguir el sistema.
class LocaleOverrideNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    // Defensivo: ver [AppearanceModeNotifier._restore]. Sin persistencia
    // disponible nos quedamos en `null` (seguir el device).
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Locale? restored = _decode(prefs.getString(kPrefLocaleKey));
      if (restored != state) {
        state = restored;
      }
    } catch (_) {
      // Sin persistencia: seguimos el idioma del device.
    }
  }

  /// Fija el override (o `null` para volver a seguir el device) y lo persiste.
  Future<void> set(Locale? locale) async {
    if (locale == state) return;
    state = locale;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(kPrefLocaleKey);
    } else {
      await prefs.setString(kPrefLocaleKey, locale.languageCode);
    }
  }

  /// Decodifica el string persistido. Solo aceptamos los códigos soportados;
  /// cualquier otro (o vacío) cae a `null` (seguir el sistema).
  static Locale? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return const <String>{'es', 'en', 'pt'}.contains(raw) ? Locale(raw) : null;
  }
}

/// Provider del override de idioma. Lo observa `MaterialApp.locale` en
/// `app.dart` (null → resuelve por device contra `supportedLocales`); el picker
/// de Idioma lo muta vía `.notifier.set(...)`.
final localeOverrideProvider =
    NotifierProvider<LocaleOverrideNotifier, Locale?>(
  LocaleOverrideNotifier.new,
);
