import Foundation

/// Los pulgares arriba/abajo de cada respuesta del asistente.
///
/// ─── POR QUÉ ES LOCAL Y ANÓNIMO ───────────────────────────────────────────
/// El problema real: no hay forma de enterarse de qué respuestas del asistente
/// están mal. Las conversaciones son privadas y no salen del dispositivo, y
/// mandarlas a un servidor para "mejorar el producto" sería exactamente lo que
/// la pantalla de privacidad promete que no pasa.
///
/// Entonces esto guarda **conteos, no contenido**: cuántos pulgares arriba,
/// cuántos abajo, y de qué tipo era la respuesta votada. Con eso alcanza para
/// saber si el asistente está empeorando y en qué clase de respuesta, que es la
/// pregunta que importa. Si algún día se quiere mandar el texto, va a hacer
/// falta pedir permiso explícito, y este tipo ya deja el lugar donde hacerlo.
enum AssistantFeedbackLog {

    /// Qué clase de respuesta se votó. Sirve para distinguir "el asistente
    /// responde mal las consultas" de "el asistente carga mal los movimientos",
    /// que son dos problemas distintos con dos arreglos distintos.
    enum Clase: String {
        case confirmacion   // empieza con ✅/⚠️/❌ — resultado de una acción
        case listado        // varias líneas con viñetas
        case respuesta      // texto normal
    }

    private static let claveArriba = "assistant.feedback.up"
    private static let claveAbajo = "assistant.feedback.down"

    static func registrar(util: Bool, mensaje: String) {
        let clase = clasificar(mensaje)
        let clave = (util ? claveArriba : claveAbajo) + "." + clase.rawValue
        let d = UserDefaults.standard
        d.set(d.integer(forKey: clave) + 1, forKey: clave)
    }

    /// Conteos acumulados, para mostrarlos en Ajustes → Diagnóstico.
    static func conteos() -> [String: Int] {
        let d = UserDefaults.standard
        var out: [String: Int] = [:]
        for sentido in [claveArriba, claveAbajo] {
            for clase in [Clase.confirmacion, .listado, .respuesta] {
                let clave = sentido + "." + clase.rawValue
                let n = d.integer(forKey: clave)
                if n > 0 { out[clave] = n }
            }
        }
        return out
    }

    static func clasificar(_ mensaje: String) -> Clase {
        let t = mensaje.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("✅") || t.hasPrefix("⚠️") || t.hasPrefix("⚠") || t.hasPrefix("❌") {
            return .confirmacion
        }
        let vinetas = t.split(separator: "\n").count { linea in
            let l = linea.trimmingCharacters(in: .whitespaces)
            return l.hasPrefix("•") || l.hasPrefix("-") || l.hasPrefix("·")
        }
        return vinetas >= 3 ? .listado : .respuesta
    }
}
