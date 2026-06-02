import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_init.dart';

/// Resultado de un `signUp`. El proyecto Supabase de MetaCasa exige confirmar
/// el email antes del primer login, así que `signUp` no siempre devuelve una
/// sesión: si `res.session == null` el usuario tiene que abrir el link del
/// mail. Espejo del `AuthError.emailConfirmationPending` del iOS, modelado acá
/// como resultado normal (no excepción) porque es un flujo esperado, no un fallo.
enum AuthSignUpResult { signedIn, emailConfirmationPending }

/// Error de auth con mensaje listo para mostrar (ya en español rioplatense).
/// Las pantallas lo catchean y pintan `e.message` en la card de error, sin
/// tener que re-traducir nada. Espejo conceptual del `AuthError` del iOS.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  /// Mensaje human-friendly, en español, apto para UI.
  final String message;

  @override
  String toString() => 'AuthFailure($message)';
}

/// Repositorio de autenticación — espejo del `AuthManager` del iOS.
///
/// `supabase_flutter` ya persiste la sesión (vía `SecureLocalStorage`, Keystore)
/// y la refresca sola, así que acá no replicamos el `restoreSession` /
/// `ensureFreshToken` manual del iOS (que existía por un bug de supabase-swift).
/// Exponemos las operaciones de auth y traducimos los errores a [AuthFailure].
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// Sesión actual (o `null` si no hay). No hace red: lee el estado en memoria
  /// que `supabase_flutter` mantiene tras restaurar del almacenamiento seguro.
  Session? get currentSession => _auth.currentSession;

  /// Usuario actual (o `null`).
  User? get currentUser => _auth.currentUser;

  /// Stream de cambios de auth (signedIn / signedOut / tokenRefreshed / …).
  /// El gate lo escucha para re-evaluar a qué subtree mandar.
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Alta de cuenta. `emailRedirectTo` apunta al dominio propio
  /// (`usehomefinance.com/auth/confirm`), que la app reclama como App Link: al
  /// tocar el link del mail, la app se abre y `AuthDeepLinkHandler` completa la
  /// confirmación con `verifyOTP(token_hash)`. Si la app no está instalada, el
  /// mismo link cae a la web. Pasarlo explícito hace que el flow no dependa del
  /// "Site URL" del dashboard de Supabase. 1:1 con iOS.
  ///
  /// Si el proyecto requiere confirmar email, `res.session` viene `null` →
  /// devolvemos [AuthSignUpResult.emailConfirmationPending].
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _auth.signUp(
        email: _normalize(email),
        password: password,
        emailRedirectTo: 'https://usehomefinance.com/auth/confirm?next=/dashboard',
      );
      return res.session == null
          ? AuthSignUpResult.emailConfirmationPending
          : AuthSignUpResult.signedIn;
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    } catch (_) {
      throw const AuthFailure(_kGeneric);
    }
  }

  /// Inicio de sesión con email + contraseña. Normaliza el email
  /// (lower + trim) igual que el iOS antes de mandarlo.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithPassword(
        email: _normalize(email),
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    } catch (_) {
      throw const AuthFailure(_kGeneric);
    }
  }

  /// Envía el email de recuperación de contraseña.
  Future<void> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(_normalize(email));
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    } catch (_) {
      throw const AuthFailure(_kGeneric);
    }
  }

  /// Cierra sesión. Tolerante a fallos (como el iOS: `try?`): aun si la llamada
  /// remota falla, el estado local se limpia.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // best-effort, igual que iOS
    }
  }

  /// Email en minúsculas y sin espacios al borde — lo que esperan Supabase y RLS.
  String _normalize(String email) => email.trim().toLowerCase();

  /// Traduce un [AuthException] de Supabase a un mensaje en español.
  ///
  /// Preferimos el `code` (estable entre versiones) sobre el `message` (texto
  /// en inglés que puede cambiar). Cubrimos los casos que el usuario realmente
  /// ve en login/signup/reset; el resto cae al genérico.
  String _friendly(AuthException e) {
    final code = e.code?.toLowerCase();
    final msg = e.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return 'Confirmá tu email antes de entrar. Revisá tu bandeja (y spam).';
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('already registered') ||
        msg.contains('user already registered')) {
      return 'Ya existe una cuenta con ese email. Probá iniciar sesión.';
    }
    if (code == 'weak_password' || msg.contains('password should be')) {
      return 'La contraseña es muy débil. Usá al menos 8 caracteres.';
    }
    if (code == 'validation_failed' ||
        msg.contains('unable to validate email') ||
        msg.contains('invalid email')) {
      return 'Revisá el email: parece que no es válido.';
    }
    if (code == 'over_request_rate_limit' ||
        e.statusCode == '429' ||
        msg.contains('rate limit')) {
      return 'Demasiados intentos. Esperá un momento y volvé a probar.';
    }
    if (code == 'over_email_send_rate_limit') {
      return 'Esperá un momento antes de pedir otro email.';
    }
    // Fallback: si el backend mandó algo legible lo mostramos, si no genérico.
    return e.message.isNotEmpty ? e.message : _kGeneric;
  }

  static const String _kGeneric =
      'Algo salió mal. Revisá tu conexión y volvé a intentar.';
}

/// Provider del [AuthRepository]. Singleton ligado al cliente Supabase global
/// ya inicializado en `initSupabase()`.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(supabase),
);
