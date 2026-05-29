import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Consentimiento de privacidad del Asistente IA, persistido localmente.
///
/// Espejo del gate de Apple Review 5.1.1 + GDPR/CCPA del iOS
/// (`PrivacyManager.assistantCloudConsent`, que guarda en `UserDefaults`): antes
/// de cualquier request a Claude el usuario tiene que aceptar el
/// [AssistantConsentSheet]. La decisión vive en `shared_preferences` con la clave
/// [kPrefAiConsentKey], igual semántica que el resto de las prefs locales
/// (`pref_theme_mode`, `pref_locale`).
///
/// Patrón calcado de `settings_providers.dart`: el `build()` devuelve el default
/// (`false`) sincrónicamente y dispara una restauración diferida desde disco; la
/// escritura es fire-and-forget. Defensivo ante `flutter test` sin binding del
/// plugin (no tumba el árbol, se queda en el default).

/// Clave de `shared_preferences` para el consentimiento del Asistente IA.
const String kPrefAiConsentKey = 'pref_ai_consent';

/// Notifier del consentimiento del asistente. Default `false` (sin consentir →
/// el FAB muestra el sheet de consentimiento antes de abrir el chat).
class AiConsentNotifier extends Notifier<bool> {
  @override
  bool build() {
    _restore();
    return false;
  }

  Future<void> _restore() async {
    // Defensivo: si el plugin no está disponible (p. ej. `flutter test` sin
    // binding) o falla la lectura, conservamos el default (`false`).
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(kPrefAiConsentKey) ?? false) {
        state = true;
      }
    } catch (_) {
      // Sin persistencia: nos quedamos en el default (sin consentir).
    }
  }

  /// Marca el consentimiento como otorgado y lo persiste. Idempotente.
  Future<void> accept() async {
    state = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefAiConsentKey, true);
    } catch (_) {
      // Si no se pudo persistir, al menos el estado en memoria queda aceptado
      // para esta sesión; el sheet volverá a aparecer en la próxima apertura.
    }
  }
}

/// Provider del consentimiento del Asistente IA. `true` ⇒ ya aceptó el sheet de
/// privacidad y el FAB puede abrir el chat directo.
final aiConsentProvider = NotifierProvider<AiConsentNotifier, bool>(
  AiConsentNotifier.new,
);
