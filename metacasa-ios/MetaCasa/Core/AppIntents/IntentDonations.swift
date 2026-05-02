import Foundation
import AppIntents

/// Donaciones proactivas de App Intents al sistema para que iOS sugiera
/// al usuario atajos de Siri/Spotlight relevantes ("Cargar gasto",
/// "Ver balance") basados en su uso histórico.
///
/// Cuando el user abre la app, ejecuta una transacción o consulta el
/// balance, donamos la intent correspondiente. iOS aprende patrones
/// (hora del día, ubicación, frecuencia) y después:
/// - Sugiere el shortcut en la Search del home screen.
/// - Ofrece el intent como banner en Lock Screen en momentos relevantes.
/// - Permite al user crear un atajo personalizado desde la app Shortcuts.
///
/// iOS 16+ usa la API moderna de `AppIntent.donate()` — no hace falta
/// convertir a INInteraction manual.
///
/// Privacy: las donaciones viven solo en el dispositivo del usuario.
/// No se sincronizan vía iCloud ni se envían a servidores.
@MainActor
enum IntentDonations {
    /// Donar al sistema una ejecución reciente de AddExpenseIntent.
    /// Lo llama el flujo de agregar transacción después de guardar.
    static func donateAddExpense() async {
        let intent = AddExpenseIntent()
        do {
            try await intent.donate()
        } catch {
            #if DEBUG
            print("[Donation] AddExpenseIntent failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Donar consulta de balance. Se dispara cuando el user abre el tab Home.
    /// iOS puede usar esto para ofrecer "Oye Siri, ver balance" como banner.
    static func donateCheckBalance() async {
        let intent = CheckBalanceIntent()
        do {
            try await intent.donate()
        } catch {
            #if DEBUG
            print("[Donation] CheckBalanceIntent failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Donar al arrancar la app. Permite que iOS tenga ambos intents en
    /// el catálogo de sugerencias sin necesidad de que el user los haya
    /// ejecutado al menos una vez manualmente.
    static func donateAll() async {
        await donateAddExpense()
        await donateCheckBalance()
    }
}
