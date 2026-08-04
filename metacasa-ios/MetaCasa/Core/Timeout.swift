import Foundation

/// Corre `operation` con un tope de tiempo. Devuelve `nil` si no terminó a tiempo.
///
/// Existe por un bug concreto: **la app quedaba colgada en el splash para siempre**.
///
/// `TrialManager` ancla el trial en `AppTransaction.shared` y `AccessController` consulta
/// `Transaction.currentEntitlements`. Las dos son de StoreKit y las dos pueden **no volver nunca**
/// cuando Apple throttlea (`AppTransaction throttled`, `SKInternalErrorDomain Code=12`), cuando no
/// hay conexión con el App Store, o cuando la cuenta del dispositivo está en un estado raro.
///
/// Lo traicionero es que el código *parecía* defendido: `appStoreOriginalPurchaseDate()` tenía un
/// `do/catch` con fallback al Keychain. Pero **un cuelgue no es un error**: el `catch` nunca corre,
/// el fallback nunca se alcanza, y `RootView` se queda mostrando `LaunchView()` sin mensaje, sin
/// reintento y sin forma de entrar.
///
/// ## Por qué NO se usa `withTaskGroup`
///
/// El primer intento de este helper fue un `withTaskGroup` con dos hijos (la operación y un sleep),
/// devolviendo el primero que terminara y llamando `cancelAll()`. **No funcionó, y el motivo es la
/// parte importante de este archivo**: un task group *espera a todos sus hijos al salir del scope*.
/// `cancelAll()` sólo pide la cancelación; si el hijo la ignora —y una llamada de StoreKit colgada
/// la ignora— el grupo se queda esperando igual. La app seguía trabada exactamente igual que antes.
///
/// **Cancelar no es lo mismo que dejar de esperar.** Para no esperar hace falta salir de la
/// concurrencia estructurada: dos `Task` sueltas compitiendo por una continuación, con un guard de
/// "resume una sola vez". La operación colgada puede seguir viva en background —no la podemos
/// matar— pero ya no bloquea a nadie.
func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @escaping @Sendable () async -> T
) async -> T? {
    // `ResumeOnce` ya existía en `SpeechRecognizerService` para el mismo problema (una
    // continuación que dos caminos pueden reanudar). Se reusa en vez de declarar otra: reanudar
    // dos veces es un crash, no un warning, y tener dos guardas distintas es cómo divergen.
    // Acá el empate es real: la operación puede terminar justo cuando vence el tope.
    let guardia = ResumeOnce<T?>()
    return await withCheckedContinuation { (cont: CheckedContinuation<T?, Never>) in
        Task { let valor = await operation(); guardia.resumeOnce(cont, with: valor) }
        Task { try? await Task.sleep(for: duration); guardia.resumeOnce(cont, with: nil) }
    }
}
