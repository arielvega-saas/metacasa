import Foundation

/// Enum de la API que **no se rompe** cuando el servidor manda un valor que esta
/// versión de la app todavía no conoce.
///
/// ## Por qué existe
///
/// Un `enum String, Codable` sin esto tira `DataCorrupted` ante un valor nuevo. Y
/// como el decodificador aborta el contenedor entero, **no se pierde una fila: se
/// pierde la respuesta completa**. El usuario abre la app y no ve ninguna cuenta,
/// ningún movimiento — no "uno raro".
///
/// Eso convierte cualquier valor nuevo agregado del lado servidor en un incidente
/// para todas las versiones publicadas: el backend es compartido, así que un tipo
/// de cuenta nuevo creado desde la web le rompería la app a quien todavía tenga
/// la versión anterior instalada. Ya pasó una vez: por esto se descartó agregar
/// el tipo `TRANSFERENCIA` a las transacciones (ver `AUDITORIA-2026-08-01.md`).
///
/// ## Cómo se usa
///
/// ```swift
/// extension AccountType: UnknownTolerantDecodable {
///     static var unknownFallback: Self { .other }
/// }
/// ```
///
/// Sólo tiene sentido en enums con un caso neutro real (`other`, `unknown`). Si un
/// enum **no** tiene a dónde caer sin mentir —`TxType`, donde inventar entre gasto
/// e ingreso falsearía los totales— la respuesta correcta no es un fallback: es no
/// agregar valores nuevos hasta que la base instalada esté al día.
protocol UnknownTolerantDecodable: RawRepresentable, Decodable where RawValue == String {
    /// A dónde cae un valor que esta versión no conoce.
    static var unknownFallback: Self { get }
}

extension UnknownTolerantDecodable {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.unknownFallback
    }
}
