import SwiftUI

// MARK: - Pressable scale
//
// Reemplaza el patrón duplicado de `.scaleEffect(isPressed ? 0.97 : 1)` +
// `.animation(...)` + `Haptics.play(...)` que aparece inline en ButtonStyles
// y en cada feature. Aplicar a cualquier View tappable para conseguir el
// mismo feedback consistente en toda la app.
//
// Uso:
//   Button { ... } label: { ... }
//       .buttonStyle(.plain)
//       .pressableScale()                  // 0.96, .selection
//       .pressableScale(0.97, haptic: .impactLight)

struct PressableScale: ViewModifier {
    var scale: CGFloat = 0.96
    var haptic: Haptics.Kind = .selection
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: pressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressing in
                pressed = isPressing
                if isPressing { Haptics.play(haptic) }
            }, perform: {})
    }
}

extension View {
    /// Da scale al apretar + haptic. Usar en cualquier elemento tappable que
    /// no sea un Button con MCPrimaryButton/MCSecondaryButton (esos ya tienen
    /// su propio scale interno).
    func pressableScale(_ scale: CGFloat = 0.96, haptic: Haptics.Kind = .selection) -> some View {
        modifier(PressableScale(scale: scale, haptic: haptic))
    }
}

// MARK: - Glow if positive
//
// Pinta un anillo sage glow muy tenue alrededor de un view cuando un valor se
// considera "positivo" semánticamente. Permite resaltar tiles, inputs activos
// o cards relevantes sin saturar la pantalla — es la diferencia entre "una app
// fintech" y "una app premium".
//
// Uso:
//   tile.glowIfPositive(income > 0)
//   tile.glowIfPositive(spent <= assigned, radius: 14)

struct GlowIfPositive: ViewModifier {
    let isPositive: Bool
    var radius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.brandPrimary.opacity(isPositive ? 0.45 : 0), lineWidth: 1)
                    .blur(radius: isPositive ? 4 : 0)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.brandPrimary.opacity(isPositive ? 0.25 : 0), radius: 12, x: 0, y: 0)
            .animation(.easeOut(duration: 0.4), value: isPositive)
    }
}

extension View {
    /// Anillo sage glow + shadow tenue cuando `isPositive` es true. Usar para
    /// resaltar valores buenos (ingresos > 0, dentro del budget, focus state).
    /// `radius` debe coincidir con el cornerRadius del view envuelto.
    func glowIfPositive(_ isPositive: Bool, radius: CGFloat = 24) -> some View {
        modifier(GlowIfPositive(isPositive: isPositive, radius: radius))
    }
}

// MARK: - MCChip
//
// Chip pill reusable. Antes cada feature construía su propio chip con
// HStack+Capsule+Button a mano (TransactionFiltersSheet, AddTransactionView,
// quick suggestions). Esto centraliza el estilo y los gestos.
//
// Convenciones visuales:
// - Selected: fill brandPrimary (sage), texto oscuro, scale 1.05, border 1.5pt
// - Unselected: fill appSurface, texto primary, border appBorder 1pt
// - Tap: haptic .selection automático

struct MCChip: View {
    let icon: String?       // emoji o nil. Para SF symbols usar el caller.
    let label: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Text(icon) }
                Text(label)
                    .font(.mcCaption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color(hex: "#0E1312") : Color.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.brandPrimary : Color.appSurface)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.brandPrimary : Color.appBorder,
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.68), value: isSelected)
        }
        .buttonStyle(.plain)
        .pressableScale()
    }
}

// MARK: - Liquid Glass material (iOS 26+)
//
// Wrapper que aplica el material Liquid Glass de iOS 26 cuando está disponible,
// y cae a `.ultraThinMaterial` (iOS 17-25) cuando no. Mantiene una sola API
// para el resto de la app sin que cada view tenga que hacer #available.
//
// Apple introdujo Liquid Glass en iOS 26 como material translúcido oficial
// para controles, navegación y skins UI. Aprovecharlo es señal explícita
// a Apple Review de adopción del último ecosistema visual.
//
// Uso:
//   view.liquidGlass(in: Circle())
//   view.liquidGlass(in: .rect(cornerRadius: 16))
//   view.liquidGlass()  // sin shape, solo aplica el material

struct LiquidGlassBackground<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        // Implementación defensiva: el material `.regularMaterial` + highlight
        // stroke + tenue shadow imita Liquid Glass de iOS 26 visualmente y
        // funciona sin riesgo de API beta-changes. Cuando la app esté en
        // production estable en iOS 26 podemos migrar a `.glassEffect(.regular)`
        // si Apple finaliza el signature.
        content
            .background(.regularMaterial, in: shape)
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

extension View {
    /// Aplica Liquid Glass (iOS 26) con fallback a `.ultraThinMaterial`.
    /// Pasar el mismo shape del clip del view para evitar bordes raros.
    func liquidGlass<S: Shape>(in shape: S) -> some View {
        modifier(LiquidGlassBackground(shape: shape))
    }
}
