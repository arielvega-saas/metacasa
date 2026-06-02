import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Escucha los App Links / Universal Links de confirmación de email
/// (`https://usehomefinance.com/auth/confirm?token_hash=...&type=...`) y
/// completa la sesión con `verifyOTP(token_hash)`.
///
/// Por qué un handler propio y no el de `supabase_flutter`: su deep-link
/// observer sólo procesa links con `code` (PKCE) o `access_token` (implicit) —
/// ignora los de `token_hash`. Además desactivamos el deep-linking automático
/// de Flutter (`flutter_deeplinking_enabled=false` en el manifest) para que el
/// GoRouter no intente navegar al link y choque con el gate. Así este es el
/// único componente que procesa el link.
///
/// `token_hash` es el flujo cross-device de Supabase: el mail se puede abrir en
/// otro dispositivo (no depende de `code_verifier`). Tras `verifyOTP`, el
/// `onAuthStateChange` dispara y el `appGateProvider` entra al shell logueado.
class AuthDeepLinkHandler {
  AuthDeepLinkHandler(this._client);

  final SupabaseClient _client;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  String? _lastHandledTokenHash;

  /// Arranca el observer: primero el link inicial (app abierta en frío por el
  /// deep link) y después el stream (links recibidos con la app ya viva).
  Future<void> start() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handle(initial);
    } catch (_) {
      // Sin link inicial o error de plataforma: seguimos con el stream.
    }
    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (_) {/* link malformado: lo ignoramos */},
    );
  }

  Future<void> _handle(Uri uri) async {
    if (uri.path != '/auth/confirm') return;
    final tokenHash = uri.queryParameters['token_hash'];
    final typeRaw = uri.queryParameters['type'];
    if (tokenHash == null || typeRaw == null) return;
    final type = _parseType(typeRaw);
    if (type == null) return;

    // Dedup: un token_hash es de un solo uso; el link inicial y el stream
    // pueden traerlo casi a la vez.
    if (tokenHash == _lastHandledTokenHash) return;
    _lastHandledTokenHash = tokenHash;

    try {
      await _client.auth.verifyOTP(type: type, tokenHash: tokenHash);
      // Éxito: onAuthStateChange → appGateProvider entra al shell.
    } catch (_) {
      // Link vencido/usado: permitimos reintentar con un link nuevo.
      _lastHandledTokenHash = null;
    }
  }

  /// Sólo los tipos que la app reclama en `/auth/confirm`. La recuperación de
  /// contraseña usa `/auth/reset` en la web y no llega acá.
  OtpType? _parseType(String raw) {
    switch (raw) {
      case 'signup':
        return OtpType.signup;
      case 'magiclink':
        return OtpType.magiclink;
      case 'email':
        return OtpType.email;
      case 'email_change':
        return OtpType.emailChange;
      default:
        return null;
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
