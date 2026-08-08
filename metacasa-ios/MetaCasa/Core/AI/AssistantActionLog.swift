import Foundation

/// Lo que el asistente escribió en este turno, con lo necesario para revertirlo.
///
/// ─── POR QUÉ ────────────────────────────────────────────────────────────────
/// Un asistente que escribe en la base necesita una salida. Hasta acá, si
/// interpretaba mal —el monto, la categoría, cuál de dos movimientos parecidos—
/// el usuario tenía que ir a Movimientos, encontrarlo y arreglarlo a mano,
/// sabiendo de antemano qué se había roto. Un botón "Deshacer" al lado de la
/// confirmación convierte eso en un toque.
///
/// Es también la contracara honesta de dejar que la IA escriba: la app no
/// promete que nunca se va a equivocar, promete que equivocarse no cuesta caro.
struct AccionRevertible: Identifiable, Sendable, Equatable {
    enum Clase: String, Sendable {
        case alta
        case edicion
    }

    let id: UUID
    let clase: Clase
    /// Lo que se le muestra al usuario: "Gasto de ARS 78.972,57 en Herramientas".
    let descripcion: String
    /// Para `alta`, el movimiento creado (revertir = borrarlo).
    /// Para `edicion`, **el estado ANTERIOR** (revertir = volver a escribirlo).
    let objetivo: Transaction

    init(id: UUID = UUID(), clase: Clase, descripcion: String, objetivo: Transaction) {
        self.id = id
        self.clase = clase
        self.descripcion = descripcion
        self.objetivo = objetivo
    }

    static func == (a: AccionRevertible, b: AccionRevertible) -> Bool { a.id == b.id }
}

/// Buffer de acciones revertibles del turno en curso.
///
/// Vive fuera del handler a propósito: hay **dos motores** (on-device y nube) y
/// cada uno crea su propio handler. Un buffer compartido hace que la UI no
/// tenga que saber cuál atendió el turno.
actor AssistantActionLog {
    static let shared = AssistantActionLog()
    private init() {}

    private var acciones: [AccionRevertible] = []

    func iniciarTurno() {
        acciones = []
    }

    func registrar(_ accion: AccionRevertible) {
        acciones.append(accion)
    }

    func delTurno() -> [AccionRevertible] {
        acciones
    }

    /// Revierte una acción contra la base.
    ///
    /// No es "recordar el estado y confiar": vuelve a escribir y deja que el
    /// servicio falle si no puede. Si tira, el llamador se entera —igual que
    /// con las escrituras del asistente, un fracaso silencioso acá sería peor
    /// que no ofrecer deshacer.
    func revertir(_ accion: AccionRevertible) async throws {
        switch accion.clase {
        case .alta:
            try await TransactionService.shared.delete(id: accion.objetivo.id)
        case .edicion:
            _ = try await TransactionService.shared.update(accion.objetivo)
        }
        acciones.removeAll { $0.id == accion.id }
    }
}
