import Foundation
import Supabase

/// Cliente Supabase compartido. Inicializado lazy al primer uso.
enum SupabaseService {
    static let client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey
        )
    }()
}
