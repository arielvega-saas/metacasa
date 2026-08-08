import XCTest
@testable import Home_Finance

/// El asistente como experto en la app.
///
/// El problema real de una app con muchas funciones no es que falten: es que la
/// mitad no se usa porque nadie sabe que están. Alguien que no conoce "Comparar
/// meses" nunca va a preguntar por "Comparar meses" — va a preguntar "¿gasté
/// más que antes?", que es la misma necesidad dicha con las palabras de alguien
/// que no leyó el manual. El asistente es el único lugar donde esa traducción
/// puede ocurrir.
///
/// El riesgo del otro lado es peor: **mandar al usuario a una pantalla que no
/// existe**. Por eso acá se verifica que cada ruta que el asistente puede
/// nombrar exista de verdad en la app.
final class AsistenteExpertoEnLaAppTests: XCTestCase {

    private let kb = AppKnowledgeBase.full

    // MARK: - Sabe de lo que existe hoy

    /// Cada función nueva tiene que estar en la base, o el asistente responde
    /// "no tengo esa función" sobre algo que sí está.
    func testLaBaseConoceLasFuncionesNuevas() {
        for tema in ["Comparar meses", "En pesos de hoy", "Últimos 7 días",
                     "Deshacer", "Retomar", "CER"] {
            XCTAssertTrue(kb.contains(tema), "la base no menciona: \(tema)")
        }
    }

    /// Cómo se usa algo se responde con pasos, no con una descripción general.
    func testLasInstruccionesTienenPasosNumerados() {
        guard let rango = kb.range(of: "Comparar dos meses descontando la inflación:") else {
            return XCTFail("falta el cómo-se-usa de Comparar meses")
        }
        let bloque = String(kb[rango.upperBound...].prefix(400))
        for paso in ["1)", "2)", "3)"] {
            XCTAssertTrue(bloque.contains(paso), "falta el paso \(paso)")
        }
    }

    // MARK: - Ofrecer sin que se lo pidan

    func testExisteLaGuiaDeCuandoOfrecerUnaHerramienta() {
        XCTAssertTrue(kb.contains("CUÁNDO OFRECER UNA HERRAMIENTA"))
        // La necesidad dicha con las palabras del usuario, no el nombre de la
        // pantalla: es lo que hace que la traducción funcione.
        XCTAssertTrue(kb.contains("¿gasté más que antes?"))
    }

    /// Sin el freno, un asistente que sugiere termina sugiriendo en cada
    /// respuesta y se vuelve ruido.
    func testLaGuiaLimitaLasSugerenciasYProhibeInventar() {
        XCTAssertTrue(kb.contains("No más de una por respuesta"))
        XCTAssertTrue(kb.contains("Nunca inventes una pantalla ni una ruta"))
    }

    // MARK: - Ninguna ruta inventada

    /// Toda ruta "Más → X" que el asistente puede nombrar tiene que existir en
    /// el menú real. Mandar a alguien a una pantalla que no existe es peor que
    /// no sugerir nada.
    func testLasRutasQueNombraExistenEnElMenu() throws {
        let menu = try textoDelMenuMas()
        let rutas = rutasMencionadas(en: kb)
        XCTAssertFalse(rutas.isEmpty, "el test no encontró ninguna ruta que verificar")

        for ruta in rutas {
            let existe = menu.contains { $0.localizedCaseInsensitiveContains(ruta) }
            XCTAssertTrue(existe, "la base manda a 'Más → \(ruta)' y no existe en el menú")
        }
    }

    /// Extrae los destinos de las rutas escritas como "Más → Destino".
    private func rutasMencionadas(en texto: String) -> Set<String> {
        var out: Set<String> = []
        for linea in texto.split(separator: "\n") {
            guard let r = linea.range(of: "Más → ") else { continue }
            let resto = linea[r.upperBound...]
            // El destino termina en coma, punto, paréntesis, pipe o flecha.
            // Las comillas también cierran el destino: en el texto las rutas
            // aparecen citadas ("podés crear una meta en 'Más → Metas' con…").
            var destino = resto.prefix { !",.()|→:\"'".contains($0) }
                .trimmingCharacters(in: .whitespaces)
            destino = destino.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            // "sección Análisis" es un encabezado del menú, no una pantalla.
            if destino.hasPrefix("sección ") { continue }
            if destino.count >= 4 { out.insert(destino) }
        }
        return out
    }

    /// Los nombres reales del menú "Más", resueltos desde el catálogo.
    private func textoDelMenuMas() throws -> [String] {
        // Las claves salen del menú de verdad (`MainTabView.moreLink`). Una
        // lista escrita a mano se desactualiza y el test deja de proteger.
        let claves = ["more.accounts", "more.envelopes", "more.goals", "more.bills",
                      "more.recurring", "more.installments", "more.debts",
                      "more.reports", "more.compareMonths", "more.annualView",
                      "more.heatmap", "more.fixedTerm", "more.compoundInterest",
                      "more.edit_household", "more.members", "more.categories",
                      "more.upgrade", "more.help", "more.settings"]
        let nombres = claves.compactMap { clave -> String? in
            let v = String(localized: String.LocalizationValue(clave))
            return v == clave ? nil : v
        }
        XCTAssertGreaterThan(nombres.count, 5, "no se resolvieron los nombres del menú")
        return nombres
    }
}

/// Las necesidades que se resuelven de más de una forma.
///
/// El asistente contestó bien "¿puedo deshacer algo que cargaste?" —explicó el
/// botón Deshacer del chat— pero no mencionó que también se puede borrar desde
/// Movimientos. El dato estaba en la base; faltaba el puente entre la NECESIDAD
/// y todos los caminos que la resuelven. Contar uno solo deja al usuario
/// creyendo que es el único.
final class CaminosAlternativosTests: XCTestCase {

    private let kb = AppKnowledgeBase.full

    func testExisteLaSeccionDeCaminosAlternativos() {
        XCTAssertTrue(kb.contains("LO MISMO SE PUEDE HACER DE VARIAS FORMAS"))
    }

    /// El caso exacto que falló: borrar un movimiento tiene cuatro caminos y el
    /// asistente contó uno.
    func testBorrarUnMovimientoListaTodosLosCaminos() throws {
        let bloque = try bloqueDe("CORREGIR O BORRAR UN MOVIMIENTO:")
        XCTAssertTrue(bloque.contains("Deshacer"), "falta el del chat")
        XCTAssertTrue(bloque.contains("Movimientos"), "falta el de la lista")
        XCTAssertTrue(bloque.contains("Eliminar movimiento"), "falta el botón real de la pantalla")
        XCTAssertTrue(bloque.lowercased().contains("desliz"), "falta el swipe")
    }

    /// Cargar un gasto tiene más puertas que ninguna otra cosa en la app, y es
    /// donde más se pierde a un usuario nuevo.
    func testCargarUnGastoListaLasPuertasPrincipales() throws {
        let bloque = try bloqueDe("CARGAR UN GASTO:")
        for camino in ["[+]", "voz", "Siri", "importar"] {
            XCTAssertTrue(bloque.localizedCaseInsensitiveContains(camino),
                          "falta el camino: \(camino)")
        }
    }

    /// La instrucción sin el orden es media instrucción: cuál conviene depende
    /// de qué está haciendo el usuario.
    func testLaGuiaPideEmpezarPorElMasDirecto() {
        XCTAssertTrue(kb.contains("empezando por el más directo"))
    }

    private func bloqueDe(_ titulo: String) throws -> String {
        let r = try XCTUnwrap(kb.range(of: titulo), "falta la sección \(titulo)")
        return String(kb[r.upperBound...].prefix(500))
    }
}
