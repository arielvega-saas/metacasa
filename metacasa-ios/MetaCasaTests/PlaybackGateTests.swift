import XCTest
@testable import Home_Finance

/// Reanudar dos veces una `CheckedContinuation` mata el proceso
/// ("SWIFT TASK CONTINUATION MISUSE"). No lanza, no se puede atrapar: la app se
/// cierra y el usuario ve "Home Finance falló".
///
/// En `CloudTTSService` los caminos que quieren cerrar una reproducción son
/// genuinamente concurrentes —el audio termina solo, el usuario toca el orb,
/// se cierra la hoja de voz, arranca otra locución— y no se puede garantizar
/// por inspección que sólo uno gane. Estos tests fijan las dos defensas:
///
///  1. **El gate es idempotente**: abrir de más es inofensivo.
///  2. **La generación**: una locución que terminó tarde no toca el canal de la
///     que la reemplazó.
final class PlaybackGateTests: XCTestCase {

    // MARK: - Idempotencia del gate

    /// Réplica de `CloudTTSService.PlaybackGate` (es privado por diseño: sólo
    /// ese archivo debe poder abrirlo).
    @MainActor
    private final class Gate {
        private var cont: CheckedContinuation<Void, Never>?
        private(set) var aperturas = 0
        init(_ cont: CheckedContinuation<Void, Never>) { self.cont = cont }
        func open() {
            aperturas += 1
            cont?.resume()
            cont = nil
        }
    }

    /// El caso que mataba la app: dos caminos cierran la misma reproducción.
    @MainActor
    func testAbrirDosVecesNoReanudaDosVeces() async {
        var gate: Gate?
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let g = Gate(cont)
            gate = g
            g.open()   // el audio terminó
            g.open()   // y además el usuario tocó el orb
            g.open()   // y se cerró la hoja
        }
        XCTAssertEqual(gate?.aperturas, 3, "los tres caminos corrieron…")
        // …y sin embargo llegamos hasta acá: la continuación se reanudó una vez.
    }

    @MainActor
    func testAbrirUnaVezReanudaNormalmente() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            Gate(cont).open()
        }
    }

    // MARK: - Generación de locución

    /// Réplica del control de `speak`: sólo la locución vigente puede cerrar el
    /// canal compartido.
    @MainActor
    private final class Canal {
        private var generacion: UInt64 = 0
        private var handler: (() -> Void)?
        private(set) var llamadas: [String] = []

        /// Devuelve el número de esta locución.
        func tomar(_ nombre: String) -> UInt64 {
            generacion &+= 1
            // Cierra la anterior antes de pisarla.
            if let previo = handler { handler = nil; previo() }
            handler = { [weak self] in self?.llamadas.append(nombre) }
            return generacion
        }

        /// Cierre desde una locución que puede haber quedado obsoleta.
        func cerrarSiVigente(_ mia: UInt64) {
            guard generacion == mia else { return }
            let h = handler
            handler = nil
            h?()
        }
    }

    /// El bug real: `fetchAudio` de la locución 1 tarda 30 s y falla; para
    /// entonces la locución 2 ya tomó el canal. Sin el número, el `catch` de la
    /// 1 consumía y llamaba el callback de la 2 —reanudando la continuación de
    /// un flujo ajeno—.
    @MainActor
    func testUnaLocucionVencidaNoCierraElCanalDeLaSiguiente() {
        let canal = Canal()
        let primera = canal.tomar("primera")
        let segunda = canal.tomar("segunda")

        // La primera falla tarde: no debe tocar nada.
        canal.cerrarSiVigente(primera)
        XCTAssertEqual(canal.llamadas, ["primera"],
                       "sólo el cierre que hizo `tomar` al ser reemplazada")

        // La segunda sí es la vigente.
        canal.cerrarSiVigente(segunda)
        XCTAssertEqual(canal.llamadas, ["primera", "segunda"])
    }

    /// Al ser reemplazada, la locución anterior tiene que recibir su aviso: su
    /// continuación está esperando y descartarla dejaba el modo voz trabado.
    @MainActor
    func testAlSerReemplazadaLaAnteriorRecibeSuAviso() {
        let canal = Canal()
        _ = canal.tomar("primera")
        _ = canal.tomar("segunda")
        XCTAssertEqual(canal.llamadas, ["primera"], "no puede quedar colgada")
    }

    @MainActor
    func testElCanalNoSeCierraDosVecesPorLaMismaLocucion() {
        let canal = Canal()
        let g = canal.tomar("única")
        canal.cerrarSiVigente(g)
        canal.cerrarSiVigente(g)
        XCTAssertEqual(canal.llamadas, ["única"])
    }
}
