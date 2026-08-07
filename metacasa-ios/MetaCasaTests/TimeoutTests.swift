import XCTest
@testable import Home_Finance

/// Que un tope de tiempo **efectivamente deje de esperar**.
///
/// Esta regla ya se rompió tres veces en el mismo repo, siempre igual: alguien
/// escribe un `withThrowingTaskGroup` con la operación y un sleep compitiendo,
/// se queda con el primero que termina y llama `cancelAll()`. Parece correcto y
/// no lo es — un task group **espera a todos sus hijos al salir del scope**, así
/// que si el hijo ignora la cancelación el grupo sigue bloqueado y el tope no
/// hace nada. Cancelar no es lo mismo que dejar de esperar.
///
/// Los síntomas fueron: la app colgada en el splash para siempre
/// (`AccessController`/`TrialManager` contra StoreKit) y el asistente en
/// "pensando…" para siempre en el iPhone —no en la web, porque solo iOS recorre
/// el loop de tool calling—.
///
/// El test que importa es `testNoEsperaAUnaOperacionQueIgnoraLaCancelacion`:
/// es el único que distingue la implementación buena de la rota. Un test con
/// una operación cooperativa pasa con las dos.
/// Ignora la cancelación a propósito: el `try?` se traga el `CancellationError`
/// y sigue durmiendo. Es cómo se comporta una llamada de StoreKit throttleada o
/// un socket colgado. Va suelta y no como método para poder cruzar la closure
/// `@Sendable` sin capturar el `XCTestCase`.
private func operacionSorda(_ vueltas: Int = 30) async -> String {
    for _ in 0..<vueltas {
        try? await Task.sleep(for: .milliseconds(100))
    }
    return "llegué tarde"
}

final class TimeoutTests: XCTestCase {

    func testNoEsperaAUnaOperacionQueIgnoraLaCancelacion() async {
        let arranque = ContinuousClock.now
        let resultado = await withTimeout(.milliseconds(200)) { await operacionSorda() }
        let transcurrido = ContinuousClock.now - arranque

        XCTAssertNil(resultado, "Vencido el plazo tiene que devolver nil")
        // La operación sorda tarda ~3 s. Si el tope funciona volvemos apenas
        // pasados los 200 ms; con el task group volvíamos recién a los 3 s.
        XCTAssertLessThan(transcurrido, .seconds(1),
                          "Volvió tarde: está esperando a la operación en vez de abandonarla")
    }

    func testDevuelveElValorCuandoLlegaATiempo() async {
        let resultado = await withTimeout(.seconds(5)) { "listo" }
        XCTAssertEqual(resultado, "listo")
    }

    /// El empate es real —la operación puede terminar justo al vencer el plazo—
    /// y reanudar dos veces una continuación es un crash, no un warning.
    func testNoCrasheaCuandoElPlazoYLaOperacionEmpatan() async {
        for _ in 0..<50 {
            _ = await withTimeout(.milliseconds(10)) {
                try? await Task.sleep(for: .milliseconds(10))
                return "empate"
            }
        }
    }
}
