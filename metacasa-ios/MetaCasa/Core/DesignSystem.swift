import SwiftUI

// MARK: - Colores (dark theme de MetaCasa, portado de la PWA)

extension Color {
    static let appBackground = Color(hex: "#09090b")
    static let appSurface = Color(hex: "#18181b").opacity(0.65)
    static let appSurfaceInset = Color(hex: "#09090b").opacity(0.5)
    static let appBorder = Color.white.opacity(0.07)

    static let textPrimary = Color(hex: "#fafafa")
    static let textMuted = Color(hex: "#71717a")
    static let textDim = Color(hex: "#3f3f46")

    static let brandPrimary = Color(hex: "#6366f1")  // indigo-500
    static let brandSuccess = Color(hex: "#10b981")  // emerald-500
    static let brandDanger = Color(hex: "#f43f5e")   // rose-500
    static let brandWarning = Color(hex: "#f59e0b")  // amber-500

    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r: Double = Double((int >> 16) & 0xFF) / 255
        let g: Double = Double((int >> 8) & 0xFF) / 255
        let b: Double = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Tipografía

extension Font {
    static let mcDisplay = Font.system(size: 36, weight: .black)
    static let mcH1 = Font.system(size: 24, weight: .black)
    static let mcH2 = Font.system(size: 20, weight: .bold)
    static let mcAmount = Font.system(size: 26, weight: .black).monospacedDigit()
    static let mcLabel = Font.system(size: 11, weight: .bold).smallCaps()
    static let mcBody = Font.system(size: 14, weight: .medium)
    static let mcCaption = Font.system(size: 12, weight: .medium)
}

// MARK: - Card modifier

struct MCCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

extension View {
    func mcCard() -> some View { modifier(MCCard()) }
}

// MARK: - Button styles

struct MCPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .black).smallCaps())
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.brandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MCSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Amount label

struct AmountLabel: View {
    let amount: Decimal
    let currency: String
    let kind: Kind
    enum Kind { case gasto, ingreso, neutro }

    var body: some View {
        Text(CurrencyFormatter.format(amount, currency: currency, showSign: kind == .ingreso))
            .font(.mcAmount)
            .foregroundStyle(color)
    }

    private var color: Color {
        switch kind {
        case .gasto: return .brandDanger
        case .ingreso: return .brandSuccess
        case .neutro: return .textPrimary
        }
    }
}
