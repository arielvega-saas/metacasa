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
}
