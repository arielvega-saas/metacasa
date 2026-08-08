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
struct AccionRevertible: Identifiable, Sendable, Equatable, Codable {
    enum Clase: String, Sendable, Codable {
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
    /// Cómo quedó el movimiento DESPUÉS de la escritura del asistente.
    ///
    /// Es el testigo que hace seguro deshacer más tarde: si el movimiento
    /// cambió desde entonces —lo editaste a mano, lo tocó otra persona del
    /// hogar— deshacer pisaría ese cambio sin avisar. Con el testigo se puede
    /// comparar y frenar.
    let resultado: Transaction?

    init(id: UUID = UUID(), clase: Clase, descripcion: String,
         objetivo: Transaction, resultado: Transaction? = nil) {
        self.id = id
        self.clase = clase
        self.descripcion = descripcion
        self.objetivo = objetivo
        self.resultado = resultado
    }

    static func == (a: AccionRevertible, b: AccionRevertible) -> Bool { a.id == b.id }
}

enum ErrorAlDeshacer: LocalizedError {
    case yaNoExiste
    case cambioDespues

    var errorDescription: String? {
        switch self {
        case .yaNoExiste:
            return "Ese movimiento ya no existe: alguien lo borró después."
        case .cambioDespues:
            return "Ese movimiento cambió después de que lo cargué. No lo deshice para no pisar ese cambio — revisalo en Movimientos."
        }
    }
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

    /// Cuántas escrituras registró el turno. El guardrail lo cruza contra lo
    /// que el texto de la respuesta afirma.
    func cantidad() -> Int {
        acciones.count
    }

    /// Revierte una acción contra la base.
    ///
    /// No es "recordar el estado y confiar": vuelve a escribir y deja que el
    /// servicio falle si no puede. Si tira, el llamador se entera —igual que
    /// con las escrituras del asistente, un fracaso silencioso acá sería peor
    /// que no ofrecer deshacer.
    func revertir(_ accion: AccionRevertible) async throws {
        let id = accion.clase == .alta ? accion.objetivo.id : accion.objetivo.id
        let actual = try await TransactionService.shared.fetchOne(id: id)

        switch accion.clase {
        case .alta:
            guard let actual else { throw ErrorAlDeshacer.yaNoExiste }
            // Si el movimiento se editó después, borrarlo se lleva puesto ese
            // cambio. Mejor frenar y decirlo.
            if let testigo = accion.resultado, !Self.equivalentes(actual, testigo) {
                throw ErrorAlDeshacer.cambioDespues
            }
            try await TransactionService.shared.delete(id: id)

        case .edicion:
            guard let actual else { throw ErrorAlDeshacer.yaNoExiste }
            if let testigo = accion.resultado, !Self.equivalentes(actual, testigo) {
                throw ErrorAlDeshacer.cambioDespues
            }
            _ = try await TransactionService.shared.update(accion.objetivo)
        }
        acciones.removeAll { $0.id == accion.id }
    }

    /// Igualdad en lo que el usuario ve y lo que afecta a los totales. No se
    /// comparan campos de servicio (`updatedAt`, período derivado): cambian
    /// solos y harían fallar todo deshacer legítimo.
    static func equivalentes(_ a: Transaction, _ b: Transaction) -> Bool {
        a.amount == b.amount
            && a.category == b.category
            && a.subcategory == b.subcategory
            && (a.note ?? "") == (b.note ?? "")
            && a.type == b.type
            && Calendar.current.isDate(a.date, inSameDayAs: b.date)
    }
}
