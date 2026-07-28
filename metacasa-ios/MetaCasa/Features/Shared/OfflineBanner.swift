import SwiftUI

/// Aviso discreto de que los datos en pantalla salieron del cache local.
///
/// No es decorativo: sin esto la app mostraría saldos y totales viejos
/// indistinguibles de los reales. Siempre lleva la FECHA del último sync.
struct OfflineBanner: View {
    @Environment(\.locale) private var locale
    let syncedAt: Date?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .bold))
            label
                .font(.mcCaption)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Color.brandWarning.opacity(0.22))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.brandWarning.opacity(0.45))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var label: Text {
        guard let syncedAt else {
            return Text("offline.banner.generic")
        }
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)
        return Text("offline.banner.since \(syncedAt.formatted(style))")
    }
}

extension View {
    /// Inserta el aviso arriba del contenido cuando hay datos cacheados en
    /// pantalla. Se aplica una sola vez, sobre el `TabView` — así cubre todas
    /// las pantallas (incluidas las push) sin tocar cada vista.
    func offlineDataBanner() -> some View {
        modifier(OfflineBannerModifier())
    }
}

private struct OfflineBannerModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Lectura directa del singleton `@Observable`: SwiftUI trackea
        // cualquier propiedad observable leída durante `body`, no hace falta
        // `@State` para un objeto que vive toda la sesión.
        let status = OfflineStatus.shared
        return content
            .safeAreaInset(edge: .top, spacing: 0) {
                if status.isServingCachedData {
                    OfflineBanner(syncedAt: status.cachedSince)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: status.isServingCachedData)
    }
}
