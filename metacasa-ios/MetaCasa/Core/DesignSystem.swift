import SwiftUI
import UIKit

// MARK: - Colores — Design System "Midnight Sage" (2026-04-21)
//
// Paleta elegida tras comparar 4 variantes: fondo casi negro verdoso con
// acentos sage glow + dorado champagne. Estética zen/spa nocturno, bordes
// finos luminosos, tipografía serif en números para darle carácter editorial.
// Contrapunto al look "fintech saturado" de apps tipo Revolut — esto se lee
// como "premium personal" no como "tech-bro app".
//
// Todos los colores de superficie/texto cambian automáticamente según el
// `userInterfaceStyle`. Los accent colors se ajustan para contraste en
// ambos modos.

extension Color {
    // Backgrounds (warm green-tinted)
    static let appBackground = Color.dynamic(
        light: "#F5F7F4",   // off-white con tinte sage muy sutil
        dark:  "#0E1312"    // Midnight Sage — casi negro verdoso
    )
    static let appSurface = Color.dynamic(
        light: "#ffffff",
        dark:  "#151C1A"    // cards ligeramente más claras que bg, mismo tinte
    )
    static let appSurfaceInset = Color.dynamic(
        light: "#EEF0EC",
        dark:  "#0B0F0E"    // insets más oscuros para profundidad
    )
    static let appBorder = Color.dynamic(
        light: "#E3E6E1",
        dark:  "#B8D4C2",   // sage glow — se ve como borde luminoso
        lightOpacity: 1.0,
        darkOpacity: 0.12
    )

    // Text (cream warm)
    static let textPrimary = Color.dynamic(light: "#0E1312", dark: "#E8E4DC")
    static let textMuted   = Color.dynamic(light: "#5A6560", dark: "#7A8782")
    static let textDim     = Color.dynamic(light: "#B8BDB6", dark: "#3E4844")

    // Brand — Midnight Sage accents
    static let brandPrimary   = Color(hex: "#B8D4C2")  // sage glow — acento principal
    static let brandSecondary = Color(hex: "#D4C19C")  // dorado champagne — acento cálido
    static let brandSuccess   = Color(hex: "#9FC4AD")  // sage saturated
    static let brandDanger    = Color(hex: "#E8B4A6")  // warm coral (no red frío)
    static let brandWarning   = Color(hex: "#D4C19C")  // champagne (reusa secondary)

    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r: Double = Double((int >> 16) & 0xFF) / 255
        let g: Double = Double((int >> 8) & 0xFF) / 255
        let b: Double = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// Construye un color que cambia automáticamente entre light y dark según
    /// el `userInterfaceStyle` del trait collection. Los `*Opacity` permiten
    /// dar transparencia distinta por modo (ej. surfaces con material en dark
    /// pero opacas en light para mantener contraste).
    static func dynamic(
        light lightHex: String,
        dark darkHex: String,
        lightOpacity: CGFloat = 1.0,
        darkOpacity: CGFloat = 1.0
    ) -> Color {
        Color(uiColor: UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? darkHex : lightHex
            let opacity = trait.userInterfaceStyle == .dark ? darkOpacity : lightOpacity
            return UIColor(hex: hex).withAlphaComponent(opacity)
        })
    }
}

extension UIColor {
    convenience init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Tipografía — Midnight Sage system
//
// Mezcla sans (Inter/SF) + serif (New York, built-in iOS) para dar carácter
// editorial. La sans se usa en UI (labels, botones, rows). La serif se usa
// en los montos grandes (hero balance, stats, budget amounts) que son el
// "héroe" del data display.

extension Font {
    // Sans — UI / headings
    static let mcDisplay  = Font.system(size: 36, weight: .black)
    static let mcH1       = Font.system(size: 24, weight: .black)
    static let mcH2       = Font.system(size: 20, weight: .bold)
    static let mcAmount   = Font.system(size: 26, weight: .black).monospacedDigit()
    static let mcLabel    = Font.system(size: 11, weight: .bold).smallCaps()
    static let mcBody     = Font.system(size: 14, weight: .medium)
    static let mcCaption  = Font.system(size: 12, weight: .medium)

    // Serif — para números héroe (fuente New York, serif built-in iOS)
    /// Para el balance grande del Home (~52pt).
    static let mcSerifHero    = Font.system(size: 52, weight: .regular, design: .serif)
    /// Para amounts destacados: ready-to-assign, envelope remaining (~34pt).
    static let mcSerifDisplay = Font.system(size: 34, weight: .regular, design: .serif)
    /// Para labels medianos de amount: stats tiles, insights (~22pt).
    static let mcSerifAmount  = Font.system(size: 22, weight: .regular, design: .serif)
    /// Para amounts inline en rows: transaction items, summary (~16pt).
    static let mcSerifInline  = Font.system(size: 16, weight: .regular, design: .serif)
    /// Para títulos de sección con sabor editorial (~28pt).
    static let mcSerifTitle   = Font.system(size: 28, weight: .regular, design: .serif)
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
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color(hex: "#0E1312"))   // texto oscuro sobre sage
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.brandPrimary)             // sage glow
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
    // `@Environment(\.locale)` ata este Text al locale efectivo del root.
    // Cuando el usuario cambia de idioma en Ajustes → Idioma, MetaCasaApp
    // propaga el nuevo Locale al environment y SwiftUI re-renderiza TODOS
    // los AmountLabel con el formato correcto (ej. "US$ 25.000" en es-AR →
    // "$25,000" en en-US).
    @Environment(\.locale) private var locale
    @Environment(PrivacyManager.self) private var privacy
    let amount: Decimal
    let currency: String
    let kind: Kind

    /// Semántica del monto a mostrar. Determina signo + color de forma
    /// consistente en toda la app.
    ///
    /// - `.gasto`: dinero que SALE. Siempre con signo `-` y color rojo.
    ///   Asume `amount >= 0` (la DB siempre guarda montos positivos y el tipo
    ///   de la transacción define la dirección).
    /// - `.ingreso`: dinero que ENTRA. Sin signo, color verde.
    /// - `.balance`: saldo o diferencia que puede ser positivo/negativo. El
    ///   signo lo define el valor (negativos con `-`, positivos sin signo).
    ///   Color: rojo si negativo, verde si positivo, neutro si cero.
    /// - `.neutro`: sin signo, color default. Para allocated, target, saldos
    ///   de cuenta positivos, referencias de monto.
    enum Kind { case gasto, ingreso, balance, neutro }

    var body: some View {
        // Importante:
        // - No fijamos `.font()` acá: dejamos que el caller lo elija (mcDisplay,
        //   mcAmount, mcH1, etc.). Si querés monospacedDigit, setealo vos.
        // - `minimumScaleFactor(0.5)` + `lineLimit(1)` + `allowsTightening`
        //   evitan que montos grandes (ej. $1.234.567,89) se corten o se
        //   envuelvan en widgets angostos.
        // - `.contentTransition(.numericText())` anima los cambios de dígito.
        Text(privacy.obfuscate(Money.format(displayAmount, currency: currency, locale: locale)))
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .allowsTightening(true)
            .foregroundStyle(color)
            .privacySensitive()
    }

    /// Amount final que se pasa al formatter. Para `.gasto` forzamos negativo
    /// (la DB guarda el valor absoluto; la UI exige el signo menos explícito).
    private var displayAmount: Decimal {
        switch kind {
        case .gasto:
            // Si el caller ya mandó negativo, lo respetamos (edge case). Si
            // mandó positivo (el caso normal), lo negamos para el display.
            return amount > 0 ? -amount : amount
        case .ingreso, .balance, .neutro:
            return amount
        }
    }

    private var color: Color {
        switch kind {
        case .gasto:   return .brandDanger
        case .ingreso: return .brandSuccess
        case .balance:
            if amount < 0 { return .brandDanger }
            if amount > 0 { return .brandSuccess }
            return .textPrimary
        case .neutro:  return .textPrimary
        }
    }
}

/// Text reactivo al locale para montos. Úsalo en lugar de
/// `Text(CurrencyFormatter.format(...))` para que al cambiar el idioma en
/// runtime se re-formatee automáticamente (y no quede el formato de la sesión
/// anterior).
struct MoneyText: View {
    @Environment(\.locale) private var locale
    @Environment(PrivacyManager.self) private var privacy
    let amount: Decimal
    let currency: String
    var style: Money.Style = .compact
    var showSign: Bool = false

    var body: some View {
        Text(privacy.obfuscate(Money.format(amount, currency: currency, style: style, showSign: showSign, locale: locale)))
            .privacySensitive()
    }
}
