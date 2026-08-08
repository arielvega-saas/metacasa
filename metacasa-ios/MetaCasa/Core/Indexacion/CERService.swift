import Foundation

/// La serie del CER, que es el índice con el que se reexpresa la plata.
///
/// ─── POR QUÉ EL CER Y NO EL IPC ────────────────────────────────────────────
/// El IPC del INDEC sale **una vez por mes y con ~13 días de atraso**. El CER es
/// **diario**, oficial, legalmente vinculante (es el que indexa los contratos) y
/// tiene serie desde 2002. Para reexpresar el gasto de un martes cualquiera se
/// necesita un valor para ese martes, no para "julio".
///
/// Los dos cierran: al 2026-08 el CER interanual y el IPC interanual dan ambos
/// 33,5%. La diferencia es que el CER se construye interpolando el IPC del mes
/// anterior, así que arrastra ~1,5 meses de desfasaje. **Se elige uno y se usa
/// en toda la app**: tener dos índices es la forma segura de que dos pantallas
/// muestren dos números distintos para lo mismo.
///
/// Fuente: `api.bcra.gob.ar/estadisticas/v4.0/monetarias/30`. Pública, sin API
/// key. Ojo: la v3.0 devuelve **410 Gone** — está deprecada.
actor CERService {
    static let shared = CERService()
    private init() {}

    /// Serie completa en memoria, indexada por día calendario.
    private var serie: [String: Decimal] = [:]
    private var cargada = false

    /// Días ordenados, para poder resolver un feriado con el hábil anterior.
    private var diasOrdenados: [String] = []

    // MARK: - API

    /// El valor del índice para ese día.
    ///
    /// Si el día no tiene dato —sábado, domingo, feriado— devuelve **el último
    /// anterior**, que es lo correcto: el CER de un domingo es el del viernes,
    /// no un valor interpolado que nadie publicó.
    func valor(para fecha: Date) async -> Decimal? {
        await cargarSiHaceFalta()
        let clave = Self.clave(fecha)
        if let exacto = serie[clave] { return exacto }
        // Búsqueda del anterior más cercano. La serie está ordenada ascendente.
        guard let idx = diasOrdenados.lastIndex(where: { $0 <= clave }) else { return nil }
        return serie[diasOrdenados[idx]]
    }

    /// Copia inmutable de la serie, para calcular sin volver al actor.
    ///
    /// Reexpresar mil movimientos no puede hacer mil `await`: se pide el
    /// snapshot una vez y se calcula todo con él. Es un **valor** `Sendable` y
    /// no una closure a propósito — una closure capturando el estado del actor
    /// no puede cruzar la frontera de aislamiento.
    struct Snapshot: Sendable {
        fileprivate let serie: [String: Decimal]
        fileprivate let dias: [String]

        /// Igual que `valor(para:)`: día exacto, o el último anterior.
        func valor(_ fecha: Date) -> Decimal? {
            let clave = CERService.clave(fecha)
            if let exacto = serie[clave] { return exacto }
            guard let idx = dias.lastIndex(where: { $0 <= clave }) else { return nil }
            return serie[dias[idx]]
        }

        var estaVacio: Bool { serie.isEmpty }
    }

    func snapshot() async -> Snapshot {
        await cargarSiHaceFalta()
        return Snapshot(serie: serie, dias: diasOrdenados)
    }

    /// Fuerza una actualización desde el BCRA. Se llama al abrir la app.
    func refrescar() async {
        await descargar()
    }

    // MARK: - Carga

    private func cargarSiHaceFalta() async {
        guard !cargada else { return }
        // Primero el disco: la app tiene que poder reexpresar sin red. El CER
        // de ayer sigue siendo válido hoy — un día de desfasaje sobre un índice
        // que se mueve ~0,06% diario no cambia ninguna decisión.
        if let guardada = Self.leerDeDisco(), !guardada.isEmpty {
            aplicar(guardada)
        }
        await descargar()
    }

    private func descargar() async {
        // 24 meses alcanzan para todo lo que la app muestra y mantiene la
        // descarga en pocos KB.
        let cal = Calendar.current
        let hoy = Date()
        let desde = cal.date(byAdding: .month, value: -24, to: hoy) ?? hoy
        var comps = URLComponents(string: "https://api.bcra.gob.ar/estadisticas/v4.0/monetarias/30")
        comps?.queryItems = [
            URLQueryItem(name: "desde", value: Self.clave(desde)),
            URLQueryItem(name: "hasta", value: Self.clave(hoy)),
            URLQueryItem(name: "limit", value: "1000"),
        ]
        guard let url = comps?.url else { return }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            let decoded = try JSONDecoder().decode(RespuestaBCRA.self, from: data)
            var nueva: [String: Decimal] = [:]
            for variable in decoded.results {
                for punto in variable.detalle {
                    // El JSON trae `Double`; se pasa por String para no
                    // arrastrar el error binario a un valor que multiplica
                    // importes. Misma regla que con los montos del asistente.
                    if let d = Decimal(string: String(punto.valor)) {
                        nueva[punto.fecha] = d
                    }
                }
            }
            guard !nueva.isEmpty else { return }
            aplicar(nueva)
            Self.guardarEnDisco(nueva)
        } catch {
            // Sin red se sigue con lo que haya en disco. Un índice viejo es
            // mejor que ninguno; ninguno esconde la feature entera.
            NSLog("[CER] no se pudo actualizar: %@", error.localizedDescription)
        }
    }

    private func aplicar(_ nueva: [String: Decimal]) {
        serie = nueva
        diasOrdenados = nueva.keys.sorted()
        cargada = true
    }

    // MARK: - Disco

    private static func archivo() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cer-serie.json")
    }

    private static func leerDeDisco() -> [String: Decimal]? {
        guard let data = try? Data(contentsOf: archivo()) else { return nil }
        guard let crudo = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
        return crudo.compactMapValues { Decimal(string: $0) }
    }

    private static func guardarEnDisco(_ serie: [String: Decimal]) {
        let comoTexto = serie.mapValues { "\($0)" }
        guard let data = try? JSONEncoder().encode(comoTexto) else { return }
        try? data.write(to: archivo(), options: .atomic)
    }

    // MARK: - Fechas

    /// Día calendario en ISO. El índice es por DÍA, no por instante: mezclar
    /// husos acá desplaza el valor un día entero.
    nonisolated static func clave(_ fecha: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: fecha)
    }

    // MARK: - JSON del BCRA

    private struct RespuestaBCRA: Decodable {
        let results: [Variable]
        struct Variable: Decodable {
            let detalle: [Punto]
        }
        struct Punto: Decodable {
            let fecha: String
            let valor: Double
        }
    }
}
