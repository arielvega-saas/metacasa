import Foundation

/// Sugerencia inteligente de categoría basada en keywords del texto que
/// escribe el user (nota, descripción o comercio). Heurística simple pero
/// efectiva para la mayoría de gastos comunes en LatAm/US/BR.
///
/// Cómo funciona:
/// 1. Normaliza el input (lowercase + strip de acentos).
/// 2. Busca matches contra un diccionario multilingüe de keywords → categoría.
/// 3. Scorea: match exacto > palabra completa > substring. Ordena descendente.
/// 4. Devuelve la top-N opciones (default 3).
///
/// El diccionario se compila-in para no depender de red. Si el user tiene
/// categorías custom, `suggestFromKnown` las respeta priorizándolas sobre
/// las built-in.
///
/// Integración: `AddTransactionView` llama `CategorySuggester.suggest(...)`
/// cuando el user tipea en el campo nota y muestra un ribbon horizontal con
/// las 3 sugerencias tappables (1-tap selecciona la categoría).
///
/// Privacy: todo en memoria, sin envío a servidor ni ML model remoto.
enum CategorySuggester {

    /// Resultado de sugerencia: categoría + confidence 0-1.
    struct Suggestion: Sendable, Equatable {
        let category: String
        let confidence: Double
        /// Para debug / analytics: qué keyword hizo match.
        let matchedKeyword: String
    }

    /// Sugerencia principal basada en keywords built-in + categorías
    /// conocidas del hogar (si `known` no está vacío, se prioriza).
    ///
    /// - Parameters:
    ///   - input: texto del user (nota, descripción, comercio).
    ///   - type: gasto o ingreso (filtra el diccionario).
    ///   - known: categorías custom del hogar. Si una matchea también,
    ///     se prioriza sobre las built-in.
    ///   - limit: cantidad máxima de sugerencias a devolver.
    static func suggest(
        input: String,
        type: TxType,
        known: [String] = [],
        limit: Int = 3
    ) -> [Suggestion] {
        let normalized = normalize(input)
        guard !normalized.isEmpty else { return [] }

        var scored: [(cat: String, score: Double, kw: String)] = []

        // Pass 1: keywords built-in.
        let source = type == .gasto ? expenseKeywords : incomeKeywords
        for (keyword, category) in source {
            let kNorm = normalize(keyword)
            if let score = matchScore(input: normalized, keyword: kNorm) {
                scored.append((cat: category, score: score, kw: keyword))
            }
        }

        // Pass 2: categorías custom (si alguna matchea el nombre, prioriza).
        for cat in known {
            let cNorm = normalize(cat)
            if let score = matchScore(input: normalized, keyword: cNorm) {
                // Custom categories tienen boost para respetar la preferencia
                // del usuario.
                scored.append((cat: cat, score: score * 1.1, kw: cat))
            }
        }

        // Dedup por categoría, guardando el score más alto.
        var byCategory: [String: (score: Double, kw: String)] = [:]
        for entry in scored {
            if let existing = byCategory[entry.cat] {
                if entry.score > existing.score {
                    byCategory[entry.cat] = (entry.score, entry.kw)
                }
            } else {
                byCategory[entry.cat] = (entry.score, entry.kw)
            }
        }

        // Ranking final: score descendente + cap a limit.
        return byCategory
            .sorted { $0.value.score > $1.value.score }
            .prefix(limit)
            .map { Suggestion(category: $0.key, confidence: min(1.0, $0.value.score), matchedKeyword: $0.value.kw) }
    }

    // MARK: - Scoring

    /// Score 0-1. Nil si no hay match.
    /// - 1.0: input == keyword (match exacto).
    /// - 0.85: keyword es palabra completa dentro del input (separada por espacios/puntuación).
    /// - 0.6: keyword es substring del input.
    /// - 0.4: input es substring del keyword (typo partial).
    private static func matchScore(input: String, keyword: String) -> Double? {
        if input == keyword { return 1.0 }
        let words = input.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        if words.contains(keyword) { return 0.85 }
        if input.contains(keyword) { return 0.6 }
        if keyword.contains(input) && input.count >= 3 { return 0.4 }
        return nil
    }

    /// Lowercase + strip diacritics + trim.
    private static func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Keyword dictionaries (multi-lingual)

    /// Gastos: keyword → categoría canónica.
    /// Las categorías canónicas son los nombres default que usa la app
    /// (ver `CategoryCatalog`). Si el user renombra una categoría, la
    /// sugerencia todavía devuelve el canónico — el `AddTransactionView`
    /// hace matching case-insensitive contra las categorías actuales del
    /// hogar antes de seleccionar.
    private static let expenseKeywords: [(keyword: String, category: String)] = [
        // Alimentación
        ("supermercado", "Alimentación"),
        ("super", "Alimentación"),
        ("carrefour", "Alimentación"),
        ("coto", "Alimentación"),
        ("dia", "Alimentación"),
        ("jumbo", "Alimentación"),
        ("vea", "Alimentación"),
        ("disco", "Alimentación"),
        ("walmart", "Alimentación"),
        ("costco", "Alimentación"),
        ("carniceria", "Alimentación"),
        ("verduleria", "Alimentación"),
        ("panaderia", "Alimentación"),
        ("almacen", "Alimentación"),
        ("mercado", "Alimentación"),
        ("grocery", "Alimentación"),
        ("supermarket", "Alimentación"),
        ("restaurant", "Alimentación"),
        ("restaurante", "Alimentación"),
        ("resto", "Alimentación"),
        ("bar", "Alimentación"),
        ("café", "Alimentación"),
        ("cafe", "Alimentación"),
        ("cafeteria", "Alimentación"),
        ("starbucks", "Alimentación"),
        ("mcdonalds", "Alimentación"),
        ("burger", "Alimentación"),
        ("subway", "Alimentación"),
        ("pedidos ya", "Alimentación"),
        ("rappi", "Alimentación"),
        ("uber eats", "Alimentación"),
        ("delivery", "Alimentación"),
        ("ifood", "Alimentación"),
        ("pizza", "Alimentación"),
        ("sushi", "Alimentación"),
        ("almuerzo", "Alimentación"),
        ("cena", "Alimentación"),
        ("desayuno", "Alimentación"),
        ("lunch", "Alimentación"),
        ("dinner", "Alimentación"),

        // Transporte
        ("uber", "Transporte"),
        ("cabify", "Transporte"),
        ("didi", "Transporte"),
        ("lyft", "Transporte"),
        ("taxi", "Transporte"),
        ("remis", "Transporte"),
        ("nafta", "Transporte"),
        ("combustible", "Transporte"),
        ("gasolina", "Transporte"),
        ("gas station", "Transporte"),
        ("ypf", "Transporte"),
        ("shell", "Transporte"),
        ("axion", "Transporte"),
        ("subte", "Transporte"),
        ("colectivo", "Transporte"),
        ("tren", "Transporte"),
        ("metro", "Transporte"),
        ("peaje", "Transporte"),
        ("estacionamiento", "Transporte"),
        ("parking", "Transporte"),
        ("parquimetro", "Transporte"),
        ("sube", "Transporte"),
        ("vtv", "Transporte"),
        ("cochera", "Transporte"),

        // Servicios (bills)
        ("luz", "Servicios"),
        ("edesur", "Servicios"),
        ("edenor", "Servicios"),
        ("electricity", "Servicios"),
        ("gas", "Servicios"),
        ("metrogas", "Servicios"),
        ("agua", "Servicios"),
        ("water", "Servicios"),
        ("aysa", "Servicios"),
        ("internet", "Servicios"),
        ("fibertel", "Servicios"),
        ("telecom", "Servicios"),
        ("movistar", "Servicios"),
        ("claro", "Servicios"),
        ("personal", "Servicios"),
        ("directv", "Servicios"),
        ("cablevision", "Servicios"),
        ("expensas", "Servicios"),

        // Entretenimiento
        ("netflix", "Entretenimiento"),
        ("spotify", "Entretenimiento"),
        ("disney", "Entretenimiento"),
        ("hbo", "Entretenimiento"),
        ("prime video", "Entretenimiento"),
        ("youtube", "Entretenimiento"),
        ("apple music", "Entretenimiento"),
        ("apple tv", "Entretenimiento"),
        ("cine", "Entretenimiento"),
        ("cinema", "Entretenimiento"),
        ("movie", "Entretenimiento"),
        ("teatro", "Entretenimiento"),
        ("concierto", "Entretenimiento"),
        ("recital", "Entretenimiento"),

        // Salud
        ("farmacia", "Salud"),
        ("pharmacy", "Salud"),
        ("medicamento", "Salud"),
        ("hospital", "Salud"),
        ("clinica", "Salud"),
        ("medico", "Salud"),
        ("dentista", "Salud"),
        ("kinesiologo", "Salud"),
        ("psicologo", "Salud"),
        ("prepaga", "Salud"),
        ("osde", "Salud"),
        ("swiss medical", "Salud"),
        ("galeno", "Salud"),
        ("medicus", "Salud"),

        // Compras / Hogar
        ("ikea", "Hogar"),
        ("easy", "Hogar"),
        ("sodimac", "Hogar"),
        ("mueble", "Hogar"),
        ("decoracion", "Hogar"),
        ("ferreteria", "Hogar"),
        ("limpieza", "Hogar"),
        ("productos limpieza", "Hogar"),

        // Educación
        ("libro", "Educación"),
        ("libreria", "Educación"),
        ("curso", "Educación"),
        ("colegio", "Educación"),
        ("universidad", "Educación"),
        ("coursera", "Educación"),
        ("udemy", "Educación"),
        ("duolingo", "Educación"),

        // Ropa
        ("ropa", "Ropa"),
        ("zapatillas", "Ropa"),
        ("zapatos", "Ropa"),
        ("zara", "Ropa"),
        ("h&m", "Ropa"),
        ("nike", "Ropa"),
        ("adidas", "Ropa"),
        ("reebok", "Ropa"),
        ("uniqlo", "Ropa"),

        // Otros comunes
        ("regalo", "Otros"),
        ("regalos", "Otros"),
        ("cumple", "Otros"),
        ("mascota", "Otros"),
        ("veterinaria", "Otros"),
        ("peluqueria", "Otros")
    ]

    /// Ingresos: keywords típicos para distinguir categoría.
    private static let incomeKeywords: [(keyword: String, category: String)] = [
        ("sueldo", "Sueldo"),
        ("salario", "Sueldo"),
        ("salary", "Sueldo"),
        ("paycheck", "Sueldo"),
        ("pago", "Sueldo"),
        ("freelance", "Freelance"),
        ("proyecto", "Freelance"),
        ("consultoria", "Freelance"),
        ("factura", "Freelance"),
        ("invoice", "Freelance"),
        ("alquiler", "Alquileres"),
        ("rent", "Alquileres"),
        ("inquilino", "Alquileres"),
        ("dividendo", "Inversiones"),
        ("dividend", "Inversiones"),
        ("interes", "Inversiones"),
        ("interest", "Inversiones"),
        ("plazo fijo", "Inversiones"),
        ("venta", "Otros"),
        ("reintegro", "Otros"),
        ("refund", "Otros"),
        ("premio", "Otros"),
        ("regalo", "Otros")
    ]
}
