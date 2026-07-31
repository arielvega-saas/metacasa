import SwiftUI

/// Anillo de presupuesto con semáforo y marca de proyección.
///
/// Patrón #7 del `PLAN_NIVEL_PRO.md` (Copilot). Reemplaza al emoji suelto en la fila de envelope:
/// el mismo espacio pasa a comunicar *cuánto va usado* y *si el ritmo lo va a reventar*, sin agregar
/// una fila más ni pedirle al usuario que interprete un porcentaje.
///
/// Tres capas, de atrás para adelante:
/// 1. **Track**: el círculo completo, gris.
/// 2. **Arco de uso**: lo gastado, con el color del semáforo (`EnvelopeStatus.Severity`).
/// 3. **Marca de proyección**: un tick en la posición donde el ritmo actual va a terminar. Sólo aparece
///    cuando la proyección se pasa del 100%, porque un tick "vas bien" no cambia ninguna decisión.
///
/// El arco arranca a las 12 y va en sentido horario, que es como se lee un reloj de tiempo consumido.
struct BudgetRing<Center: View>: View {
    /// Fracción usada, 0...1 (ya viene topeada por `EnvelopeStatus.percentUsed`).
    let percentUsed: Double
    let severity: EnvelopeStatus.Severity
    /// Proyección al ritmo actual, si la hay. `nil` = no mostrar tick.
    var pace: BudgetPace?
    var lineWidth: CGFloat = 4
    @ViewBuilder var center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Arranca en 0 y se anima hasta el valor real la primera vez que aparece.
    @State private var animatedPercent: Double = 0

    private var tint: Color {
        switch severity {
        case .ok: .brandSuccess
        case .warning: .brandWarning
        case .critical: .brandDanger
        }
    }

    /// Posición angular del tick, 0...1. Se topea en 1 para que una proyección de 300% no dé
    /// varias vueltas al anillo y quede en un lugar arbitrario: pegado al final comunica
    /// "se pasa" igual de bien y no miente sobre cuánto.
    private var projectionMark: Double? {
        guard let pace, pace.willOverspend else { return nil }
        return min(1, pace.projectedPercent)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appSurfaceInset, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedPercent)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if let mark = projectionMark {
                // Un tick corto sobre el radio del anillo, rotado hasta el ángulo proyectado.
                Capsule()
                    .fill(Color.brandDanger)
                    .frame(width: 2, height: lineWidth * 2.4)
                    .offset(y: -ringRadius)
                    .rotationEffect(.degrees(mark * 360))
            }

            center()
        }
        .frame(width: 44, height: 44)
        .onAppear {
            guard !reduceMotion else {
                animatedPercent = percentUsed
                return
            }
            withAnimation(.easeOut(duration: 0.7)) { animatedPercent = percentUsed }
        }
        .onChange(of: percentUsed) { _, newValue in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { animatedPercent = newValue }
        }
    }

    /// El trazo se dibuja centrado sobre el borde, así que el radio útil es la mitad del frame.
    private var ringRadius: CGFloat { 22 - lineWidth / 2 }
}

extension BudgetRing where Center == EmptyView {
    init(percentUsed: Double, severity: EnvelopeStatus.Severity, pace: BudgetPace? = nil, lineWidth: CGFloat = 4) {
        self.init(percentUsed: percentUsed, severity: severity, pace: pace, lineWidth: lineWidth) {
            EmptyView()
        }
    }
}
