import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Inicializa el cliente Supabase (se reusa el MISMO backend que iOS/web).
///
/// Si no hay credenciales (`--dart-define` ausente), no-opea: la app igual
/// bootea al gate (que en ese caso resuelve a `unauthenticated`) para poder
/// trabajar UI/diseño sin red. Importante: **no** acceder a
/// `Supabase.instance` cuando esto no corrió — ver `supabase` getter abajo.
///
/// Sesión segura: pasamos un [SecureLocalStorage] backed por
/// `flutter_secure_storage` (Android Keystore), de modo que el JSON de la
/// sesión Supabase (que incluye `access_token` + `refresh_token`) quede
/// cifrado at-rest en el Keystore, no en SharedPreferences en claro. Es el
/// equivalente Android del Keychain que usa el iOS (`KeychainStore`).
Future<void> initSupabase() async {
  if (!Env.hasSupabase) return;
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(),
    ),
  );
}

/// `true` si `initSupabase()` corrió y dejó una instancia lista. Equivale a
/// `Env.hasSupabase` porque ese es el único camino por el que `initSupabase()`
/// llama a `Supabase.initialize()`. Lo usan los providers/gate para no tocar
/// `Supabase.instance` (que tira un assert si no se inicializó, p. ej. en
/// `flutter test` sin credenciales).
bool get supabaseReady => Env.hasSupabase;

/// Acceso al cliente. Solo válido tras `initSupabase()` con credenciales.
SupabaseClient get supabase => Supabase.instance.client;

/// `LocalStorage` de Supabase respaldado por `flutter_secure_storage`.
///
/// `supabase_flutter` persiste **toda la sesión** (un JSON con access +
/// refresh token) bajo una sola key vía esta interfaz. La implementación
/// default usa `SharedPreferences` (texto plano). Acá la reemplazamos por
/// almacenamiento cifrado:
///
/// - **Android**: `flutter_secure_storage` v10 cifra por default con el
///   **Android Keystore** (AES-GCM para los datos + RSA-OAEP para envolver la
///   key). NO pasamos `encryptedSharedPreferences` (deprecado en v10 y a
///   removerse en v11). Esto satisface el requisito MASVS de "refresh tokens
///   solo en Keystore".
/// - **iOS**: el plugin usa Keychain con `first_unlock_this_device`.
///
/// La key de persistencia replica el formato default de supabase_flutter
/// (`sb-<host>-auth-token`) para no romper migraciones futuras ni colisionar.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // v10: el constructor default ya es Keystore-backed (AES-GCM +
              // RSA-OAEP). `resetOnError` evita que una key corrupta deje al
              // usuario trabado: ante error de descifrado, limpia y re-loguea.
              aOptions: AndroidOptions(resetOnError: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  /// Misma key que arma supabase_flutter por default, derivada del host del
  /// proyecto. Si falta la URL (no debería: `initSupabase` no nos instancia
  /// sin credenciales) caemos a un nombre genérico estable.
  static String get _key {
    final url = Env.supabaseUrl;
    if (url.isEmpty) return 'sb-metacasa-auth-token';
    return 'sb-${Uri.parse(url).host.split('.').first}-auth-token';
  }

  @override
  Future<void> initialize() async {
    // El plugin de secure storage es lazy; no hay init explícito que hacer.
  }

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);
}
