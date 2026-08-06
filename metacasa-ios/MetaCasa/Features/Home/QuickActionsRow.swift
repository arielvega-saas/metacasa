import SwiftUI

/// Fila de acciones primarias del Home, pegada al saldo.
///
/// Es el patrón que tienen Mercado Pago, Nubank, Ualá y Naranja X: cuatro círculos
/// grandes debajo del número, con lo que la gente viene a hacer. No es un menú ni un
/// carrusel — son **las** acciones, y por eso son fijas: si se pudieran ocultar desde el
/// editor del dashboard dejarían de ser primarias.
///
/// Se eligieron por frecuencia real de uso, no por cantidad de features:
///
/// - **Gasto** e **Ingreso** entran directo con el tipo ya elegido. Ese toque de más en el
///   selector es justo el que se saltea y hace que un sueldo entre cargado como gasto.
/// - **Vencimiento** es lo que convierte la app en algo que te avisa, no sólo que anota.
/// - **Preguntar** es el diferencial contra YNAB y Mobills, y estaba escondido en un FAB
///   flotante que se confunde con un botón de "agregar".
///
/// Deliberadamente **no** hay una quinta: cinco círculos entran apretados en un iPhone SE
/// y la fila deja de leerse de un vistazo, que es lo único que tiene que hacer.
struct QuickActionsRow: View {
    let onExpense: () -> Void
    let onIncome: () -> Void
    let onBill: () -> Void
    let onAssistant: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            action("home.quickAction.expense", "arrow.up.right", .brandDanger, onExpense)
            action("home.quickAction.income", "arrow.down.left", .brandSuccess, onIncome)
            action("home.quickAction.bill", "calendar.badge.clock", .brandSecondary, onBill)
            action("home.quickAction.ask", "sparkles", .brandPrimary, onAssistant)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
        )
    }

    private func action(
        _ titleKey: LocalizedStringKey,
        _ icon: String,
        _ tint: Color,
        _ perform: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.play(.impactLight)
            perform()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.14), in: Circle())
                Text(titleKey)
                    .font(.mcCaption)
                    .foregroundStyle(Color.textPrimary)
                    // Una sola línea y sin encoger: en alemán o con Dynamic Type grande,
                    // dejar que el texto se parta descuadra la altura de los cuatro
                    // círculos y la fila deja de leerse como una fila.
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            // El área táctil es toda la columna, no sólo el círculo: apuntarle a 52 pt
            // con el pulgar en una mano es incómodo.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(titleKey))
        .accessibilityAddTraits(.isButton)
    }
}
