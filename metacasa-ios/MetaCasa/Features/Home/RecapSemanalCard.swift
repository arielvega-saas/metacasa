import SwiftUI

/// La tarjeta del resumen semanal en Inicio.
///
/// El titular no es el total: es **cómo viene** y **en qué**. "Gastaste
/// $174.050" no le dice nada a nadie; "$30.000 más en Alimentación que la
/// semana pasada, aunque en términos reales gastaste menos" sí.
///
/// Y cuando el dato es flojo —días sin cargar movimientos— lo dice en vez de
/// dar un veredicto. Una app de plata que afirma de más pierde la confianza una
/// sola vez.
@MainActor
struct RecapSemanalCard: View {
    let recap: RecapSemanal?
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            encabezado
            if let recap {
                contenido(recap)
            } else {
                Text("recap.empty")
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
            }
        }
        .mcCard()
    }

    private var encabezado: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
            Text("recap.title")
                .font(.mcH2)
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
    }

    @ViewBuilder
    private func contenido(_ r: RecapSemanal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("recap.spent")
                    .font(.mcLabel)
                    .foregroundStyle(Color.textMuted)
                Text(Money.format(r.gasto, currency: currency, style: .compact))
                    .font(.mcSerifInline)
                    .foregroundStyle(Color.textPrimary)
            }

            comparacion(r)

            if let subida = r.mayorSubida {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.bold))
                    Text("recap.biggestRise")
                        .font(.mcCaption)
                        .foregroundStyle(Color.textMuted)
                    Text("\(subida.categoria) +\(Money.format(subida.delta, currency: currency, style: .compact))")
                        .font(.mcCaption.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            // Honestidad del dato antes que titular lindo.
            if r.diasSinRegistro >= 3 {
                Text("recap.missingDays \(r.diasSinRegistro)")
                    .font(.mcCaption)
                    .foregroundStyle(Color.brandWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// La comparación con la semana anterior.
    ///
    /// Si hay índice de inflación se muestra la variación REAL y se aclara —un
    /// porcentaje sin decir "real" al lado de un número nominal se lee como
    /// nominal y engaña—. El ícono acompaña al color: en daltonismo y con
    /// "diferenciar sin color" activado, el color solo no alcanza.
    @ViewBuilder
    private func comparacion(_ r: RecapSemanal) -> some View {
        let real = r.variacionReal
        let pct = real ?? porcentajeNominal(r)
        let baja = (real ?? porcentajeNominal(r)) < 0

        if r.gastoPrevio > 0 {
            HStack(spacing: 6) {
                Image(systemName: baja ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.caption)
                    .foregroundStyle(baja ? Color.brandSuccess : Color.brandWarning)
                Text(porcentajeTexto(pct))
                    .font(.mcCaption.weight(.semibold))
                    .foregroundStyle(baja ? Color.brandSuccess : Color.brandWarning)
                Text(real != nil ? "recap.realChange" : "recap.vsPrevious")
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
            }
            Text(baja ? "recap.better" : "recap.worse")
                .font(.mcCaption)
                .foregroundStyle(Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func porcentajeNominal(_ r: RecapSemanal) -> Decimal {
        guard r.gastoPrevio > 0 else { return 0 }
        return (r.gasto - r.gastoPrevio) / r.gastoPrevio
    }

    private func porcentajeTexto(_ v: Decimal) -> String {
        let pct = ((v as NSDecimalNumber).doubleValue * 100).rounded()
        return "\(pct > 0 ? "+" : "")\(Int(pct))%"
    }
}
