import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Servicio de biometría — espejo del `BiometricAuth` del iOS (LocalAuthentication).
///
/// Allows **device-passcode fallback** (no `biometricOnly`), igual que el iOS
/// usa `.deviceOwnerAuthentication` (no `…WithBiometrics`): si el usuario no
/// tiene huella/rostro enrolado pero sí PIN/patrón, igual puede confirmar.
///
/// Por ahora es **advisory / no bloqueante** (como en iOS hoy): la app no se
/// traba detrás de esto. Queda expuesto vía [biometricServiceProvider] para
/// cablear un toggle de "Bloqueo con biometría" más adelante (Fase 3/4),
/// momento en el que el gate o un wrapper de la app lo invocará al foreground.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// `true` si el dispositivo puede pedir biometría **o** credencial de
  /// dispositivo (PIN/patrón). Combina `canCheckBiometrics` con
  /// `isDeviceSupported()` (este último cubre el caso "solo passcode, sin
  /// biometría enrolada"). Tolerante a errores de plataforma → `false`.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  /// Pide al usuario que confirme su identidad. Retorna `true` si pasó, `false`
  /// si canceló o falló (no lanza: el caller decide qué hacer con `false`,
  /// igual que el iOS mapea los cancels a `false`).
  ///
  /// `biometricOnly: false` habilita el fallback al código del dispositivo
  /// (PIN/patrón) — equivalente del `deviceOwnerAuthentication` del iOS.
  /// `stickyAuth: true` evita que un cambio de app a background cancele el
  /// prompt a medias.
  Future<bool> authenticate({
    String reason = 'Confirmá tu identidad para abrir la app',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      // Lockout, sin enrolar, sin hardware, error de plataforma → tratamos como
      // "no autenticó". Al ser advisory, no rompemos la sesión por esto.
      return false;
    }
  }
}

/// Provider del [BiometricService]. Singleton; sin estado mutable propio.
final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(),
);
