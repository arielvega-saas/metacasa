import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/router.dart';
import 'core/theme/app_theme.dart';
import 'state/settings_providers.dart';

// Re-export del gate raíz para que viva conceptualmente junto a `MetaCasaApp`
// (ver `config/root_gate.dart`). El switch real por `appGateProvider` está allí.
export 'config/root_gate.dart' show RootGate;

/// Raíz de la app — espejo del `MetaCasaApp`/`RootView` de iOS.
///
/// `MaterialApp.router` cableado al [routerProvider] (shell de tabs + gate).
/// El tema y el idioma son **switchables en runtime** desde Ajustes:
/// `themeMode` lo gobierna [appearanceModeProvider] (default dark, dark-first
/// igual que iOS) y `locale` lo gobierna [localeOverrideProvider] (null =
/// seguir el device contra [supportedLocales]).
class MetaCasaApp extends ConsumerWidget {
  const MetaCasaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Preferencias de app (persistidas vía shared_preferences). Observarlas acá
    // hace que un cambio en Ajustes re-pinte toda la app al instante.
    final ThemeMode themeMode = ref.watch(appearanceModeProvider);
    final Locale? localeOverride = ref.watch(localeOverrideProvider);
    return MaterialApp.router(
      title: 'Home Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode, // dark por default; switchable desde Apariencia
      // Override de idioma: null → resuelve según el device (LatAm-first); un
      // valor fuerza es/en/pt. Sin esto AmountText formateaba la plata en en_US
      // (separadores gringos). es-AR usa la base `es` (separadores . y ,).
      locale: localeOverride,
      // Localización: es (fallback, LatAm-first) · en · pt.
      supportedLocales: const [Locale('es'), Locale('en'), Locale('pt')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
