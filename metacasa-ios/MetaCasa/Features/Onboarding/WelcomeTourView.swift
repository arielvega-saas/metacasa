import SwiftUI

/// Tour de bienvenida que se muestra una sola vez después del primer login
/// con hogar creado. Complementa al `SetupChecklistCard` del Home:
/// - El tour **explica qué puede hacer la app** (visión general, filosofía).
/// - El checklist **guía los primeros pasos concretos** para cargar datos.
///
/// UX: 5 páginas con `TabView(selection: ... .page)`, swipe horizontal,
/// botones "Atrás / Siguiente" abajo y "Omitir" arriba. Última página
/// muestra "Empezar" y cierra el tour. Dismiss persiste la bandera
/// `welcome_tour_seen` en UserDefaults para nunca volver a abrirlo.
///
/// Inspirado en patrones de apps de finanzas (YNAB, Monarch, Copilot)
/// que arrancan con un tour conceptual antes de tirar al user al dashboard.
struct WelcomeTourView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let pages: [TourPage] = TourPage.allPages

    var body: some View {
        ZStack {
            // Fondo Midnight Sage con gradient radial sage sutil.
            Color.appBackground.ignoresSafeArea()
            RadialGradient(
                colors: [Color.brandPrimary.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                        pageView(page)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                pageDots
                    .padding(.bottom, 12)
                bottomBar
                    .padding(.bottom, 40)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Top bar (skip)

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                Haptics.play(.impactLight)
                finish()
            } label: {
                Text("tour.skip")
                    .font(.mcLabel)
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.appSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.appBorder, lineWidth: 1)
                    )
            }
            .opacity(currentPage == pages.count - 1 ? 0 : 1)
            .animation(.easeOut(duration: 0.2), value: currentPage)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Page content

    private func pageView(_ page: TourPage) -> some View {
        VStack(spacing: 28) {
            Spacer()

            // Icono hero grande con halo sage.
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 180, height: 180)
                    .blur(radius: 12)
                Circle()
                    .fill(Color.appSurface)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle().stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
                    )
                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(Color.brandPrimary)
            }

            VStack(spacing: 14) {
                Text(LocalizedStringKey(page.titleKey))
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text(LocalizedStringKey(page.bodyKey))
                    .font(.mcBody)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Bullets secundarios si los hay.
            if !page.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(page.bullets, id: \.self) { bulletKey in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundStyle(Color.brandPrimary)
                                .padding(.top, 4)
                            Text(LocalizedStringKey(bulletKey))
                                .font(.mcCaption)
                                .foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 24)
            }

            Spacer()
        }
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<pages.count, id: \.self) { idx in
                Capsule()
                    .fill(idx == currentPage ? Color.brandPrimary : Color.textDim)
                    .frame(
                        width: idx == currentPage ? 20 : 6,
                        height: 6
                    )
                    .animation(.easeOut(duration: 0.2), value: currentPage)
            }
        }
    }

    // MARK: - Bottom bar (back/next/finish)

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if currentPage > 0 {
                Button {
                    Haptics.play(.selection)
                    withAnimation { currentPage -= 1 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("tour.back")
                    }
                    .font(.mcLabel)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {
                Haptics.play(.selection)
                if currentPage == pages.count - 1 {
                    Haptics.play(.success)
                    finish()
                } else {
                    withAnimation { currentPage += 1 }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentPage == pages.count - 1 ? "tour.start" : "tour.next")
                    if currentPage < pages.count - 1 {
                        Image(systemName: "chevron.right")
                    }
                }
            }
            .buttonStyle(MCPrimaryButton())
        }
    }

    // MARK: - Finish

    private func finish() {
        WelcomeTourStorage.markSeen()
        dismiss()
    }
}

// MARK: - Page model

private struct TourPage: Sendable {
    let icon: String
    /// String keys. El view los convierte a LocalizedStringKey al renderizar.
    /// Usar String directamente en vez de LocalizedStringKey porque el último
    /// no es Sendable (bloquea static let en Swift 6 strict concurrency).
    let titleKey: String
    let bodyKey: String
    let bullets: [String]

    static let allPages: [TourPage] = [
        TourPage(
            icon: "house.lodge.fill",
            titleKey: "tour.page1.title",
            bodyKey: "tour.page1.body",
            bullets: []
        ),
        TourPage(
            icon: "chart.pie.fill",
            titleKey: "tour.page2.title",
            bodyKey: "tour.page2.body",
            bullets: [
                "tour.page2.b1",
                "tour.page2.b2",
                "tour.page2.b3"
            ]
        ),
        TourPage(
            icon: "target",
            titleKey: "tour.page3.title",
            bodyKey: "tour.page3.body",
            bullets: [
                "tour.page3.b1",
                "tour.page3.b2"
            ]
        ),
        TourPage(
            icon: "sparkles",
            titleKey: "tour.page4.title",
            bodyKey: "tour.page4.body",
            bullets: [
                "tour.page4.b1",
                "tour.page4.b2",
                "tour.page4.b3"
            ]
        ),
        TourPage(
            icon: "lock.shield.fill",
            titleKey: "tour.page5.title",
            bodyKey: "tour.page5.body",
            bullets: [
                "tour.page5.b1",
                "tour.page5.b2",
                "tour.page5.b3"
            ]
        )
    ]
}

// MARK: - Storage

/// Persistencia del flag "tour ya visto". Si `hasSeenTour == false` y hay
/// hogar activo, `RootView` dispara el sheet. Tras completar o saltar el tour,
/// queda marcado y no se vuelve a mostrar.
enum WelcomeTourStorage {
    private static let key = "welcome_tour_seen"

    static var hasSeenTour: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Usado desde Settings → Preferencias → "Ver tour de bienvenida" para
    /// re-mostrarlo on demand.
    static func reset() {
        UserDefaults.standard.set(false, forKey: key)
    }
}
