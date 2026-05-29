import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_init.dart';

/// Error de borrado de cuenta. Espejo del `DeletionError` de iOS.
class AccountDeletionException implements Exception {
  AccountDeletionException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() =>
      'AccountDeletionException($statusCode): $message';
}

/// Cliente de la Edge Function `delete-account`.
///
/// La función invoca `auth.admin.deleteUser` con `service_role` server-side.
/// Requerido por App Store Review Guideline 5.1.1(v) y por Google Play para
/// apps con creación de cuenta.
///
/// `supabase_flutter` adjunta automáticamente el header de autorización
/// (`Authorization: Bearer <jwt>`) de la sesión y la `apikey` — no inyectamos
/// headers a mano (a diferencia del `AccountDeletionService` de iOS, que arma
/// el `URLRequest` manualmente).
///
/// Tras un borrado exitoso el JWT del cliente queda inválido; el caller debe
/// ejecutar `supabase.auth.signOut()` para limpiar el estado local.
class AccountDeletionClient {
  AccountDeletionClient(this._client);

  final SupabaseClient _client;

  /// Borra la cuenta del usuario autenticado.
  ///
  /// Lanza [AccountDeletionException] ante cualquier respuesta no-200 (incluida
  /// la `FunctionException` que `functions.invoke` arroja en errores HTTP) o si
  /// no hay sesión activa.
  Future<void> deleteAccount() async {
    if (_client.auth.currentSession == null) {
      throw AccountDeletionException(401, 'No hay una sesión activa para borrar.');
    }
    try {
      final res = await _client.functions.invoke('delete-account');
      if (res.status != 200) {
        throw AccountDeletionException(
          res.status,
          _extractMessage(res.data) ?? 'Respuesta inesperada del servidor.',
        );
      }
    } on FunctionException catch (e) {
      // invoke() lanza esto en respuestas HTTP de error (>=400).
      throw AccountDeletionException(
        e.status,
        _extractMessage(e.details) ?? e.reasonPhrase ?? '(sin detalle)',
      );
    }
  }

  /// Extrae un mensaje legible del body de error (`{ "error": "..." }` o texto).
  String? _extractMessage(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final err = data['error'] ?? data['message'];
      if (err != null) return err.toString();
    }
    final s = data.toString();
    return s.isEmpty ? null : s;
  }
}

/// Provider del [AccountDeletionClient].
final accountDeletionClientProvider = Provider<AccountDeletionClient>(
  (ref) => AccountDeletionClient(supabase),
);
