/// Configuración de entorno. Los valores se inyectan en build-time con
/// `--dart-define-from-file=env.json` (NO se hardcodean en el código).
///
/// La anon/publishable key de Supabase es pública por diseño (la protege RLS),
/// pero igual vive en `env.json` (gitignoreado) para no commitearla y poder
/// rotar por entorno.
///
/// Correr local:  `flutter run --dart-define-from-file=env.json`
/// Build release: `flutter build appbundle --dart-define-from-file=env.json`
abstract final class Env {
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// `true` si hay credenciales. Si no, la app igual arranca (modo diseño/UI).
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
