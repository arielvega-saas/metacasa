import Foundation

/// ¿La respuesta le está diciendo al usuario que **ya cambió sus datos**?
///
/// ─── POR QUÉ EXISTE ────────────────────────────────────────────────────────
/// El asistente puede redactar una confirmación sin haber ejecutado nada. Caso
/// real: "Actualicé el gasto a 78.972,57 pesos en Herramientas. Tu balance del
/// mes queda en 2.591.362,43 pesos", sobre un registro que en la base seguía
/// intacto —y con un balance que tampoco salía de ninguna cuenta: el gasto
/// habría movido $19.827 y el número informado se movió $145—.
///
/// Ningún prompt evita eso de forma confiable: un modelo chico alucina
/// confirmaciones, y "no digas que hiciste algo que no hiciste" es exactamente
/// el tipo de instrucción que no puede verificar por sí mismo. Así que la
/// verificación la hace la app: cruza esta detección con el contador de
/// escrituras reales del turno (`AIToolHandler.escriturasDelTurno`). Afirmación
/// sin escritura = el turno no se le muestra al usuario como un hecho.
///
/// Es deliberadamente **conservador**: ante la duda, NO afirma. Un falso
/// positivo escala el turno al motor de nube y molesta; un falso negativo deja
/// pasar una mentira sobre la plata del usuario. Sólo los dos primeros son
/// recuperables.
enum AfirmacionDeCambio {

    /// Verbos en primera persona del pasado — el asistente contando lo que hizo.
    private static let verbos = [
        "cargué", "cargue", "agregué", "agregue", "añadí", "anadi",
        "registré", "registre", "guardé", "guarde", "creé", "cree",
        "actualicé", "actualice", "modifiqué", "modifique", "corregí", "corregi",
        "cambié", "cambie", "edité", "edite",
        "borré", "borre", "eliminé", "elimine",
        "transferí", "transferi", "moví", "movi",
        "marqué", "marque", "seteé", "setee", "configuré", "configure",
    ]

    /// Formas impersonales equivalentes: "quedó cargado", "ya está actualizado".
    private static let frases = [
        "quedó cargado", "quedo cargado", "quedó actualizado", "quedo actualizado",
        "quedó guardado", "quedo guardado", "quedó registrado", "quedo registrado",
        "quedó corregido", "quedo corregido", "quedó borrado", "quedo borrado",
        "quedó eliminado", "quedo eliminado", "quedó modificado", "quedo modificado",
        "ya está cargado", "ya esta cargado", "ya está actualizado", "ya esta actualizado",
        "listo, lo cargué", "listo, lo cargue",
    ]

    /// Lo que NIEGA o CONDICIONA la afirmación, y por lo tanto la desactiva:
    /// "no pude cargarlo", "¿querés que lo cargue?", "si lo corrijo…".
    private static let desactivadores = [
        "no pude", "no puedo", "no logré", "no logre", "no se pudo", "no pudo",
        "no encontré", "no encontre", "no existe", "no hay",
        "querés que", "queres que", "quieres que", "confirmás", "confirmas",
        "voy a", "puedo", "podría", "podria", "necesito", "decime", "indicame",
        "error", "falló", "fallo", "no se aplicó", "no se aplico",
    ]

    /// `true` si el texto afirma un cambio ya consumado sobre los datos.
    static func afirmaCambio(_ texto: String) -> Bool {
        let normal = texto.lowercased()

        // Se evalúa oración por oración: en un mismo mensaje puede convivir
        // "no pude borrar el otro" con "cargué el primero".
        // Además del punto hay que cortar en los conectores que contrastan: "no
        // pude borrar el duplicado, PERO cargué la nafta" es una sola oración
        // con una negación y una afirmación adentro, y la negación no puede
        // tapar la afirmación.
        var normalizado = normal
        for conector in [" pero ", " aunque ", " sin embargo ", "; "] {
            normalizado = normalizado.replacingOccurrences(of: conector, with: ". ")
        }
        let oraciones = normalizado.split(whereSeparator: { ".!?\n".contains($0) })

        for oracion in oraciones {
            let o = String(oracion)
            guard !desactivadores.contains(where: { o.contains($0) }) else { continue }

            if frases.contains(where: { o.contains($0) }) { return true }

            // Los verbos se comparan por palabra completa: "cambie" no puede
            // matchear dentro de "cambiemos", y "cree" no dentro de "creería".
            let palabras = o.split(whereSeparator: { !$0.isLetter && $0 != "í" && $0 != "é" })
            if palabras.contains(where: { verbos.contains(String($0)) }) { return true }
        }
        return false
    }
}
