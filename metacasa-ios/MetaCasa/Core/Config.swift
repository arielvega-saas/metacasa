import Foundation

enum Config {
    static let supabaseURL: URL = {
        guard let str = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: str) else {
            fatalError("SUPABASE_URL missing or invalid in Info.plist")
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY missing in Info.plist")
        }
        return key
    }()

    static let bundleId: String = Bundle.main.bundleIdentifier ?? "com.metacasa.app"

    static let appVersion: String = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0"
    static let buildNumber: String = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"

    /// API key pública de RevenueCat (iOS). Se setea en `Info.plist` bajo la clave
    /// `REVENUECAT_API_KEY` una vez que el usuario crea la app en el dashboard
    /// de RevenueCat. Si no está presente, el paywall queda en modo placeholder
    /// y las compras no se ejecutan.
    static var revenueCatAPIKey: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String
        return (value?.isEmpty ?? true) ? nil : value
    }
}
