import SwiftUI

/// Placeholder de paywall. La integración real con RevenueCat + StoreKit 2 se construye
/// cuando tengas App Store Connect configurado y productos creados (Fase 3 avanzada).
struct PaywallView: View {
    @State private var hasActivePremium = false
    @State private var isChecking = true

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.brandWarning)
                        .padding(.top, 40)

                    Text("Home Finance Premium")
                        .font(.mcH1)
                        .foregroundStyle(Color.textPrimary)

                    if hasActivePremium {
                        activeCard
                    } else {
                        pitchCard
                        featuresList
                        pricesCard
                        upgradeButton
                    }

                    Text("Las suscripciones se gestionan en tu cuenta de App Store.")
                        .font(.mcCaption)
                        .foregroundStyle(Color.textDim)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Premium")
        .task { await checkEntitlements() }
    }

    private var activeCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.brandSuccess)
                .font(.system(size: 44))
            Text("Ya tenés Premium activo").font(.mcH2).foregroundStyle(Color.textPrimary)
            Text("Gracias por apoyar el desarrollo de la app.")
                .font(.mcBody).foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .mcCard()
    }

    private var pitchCard: some View {
        Text("Llevá tu gestión financiera al siguiente nivel. Hogares ilimitados, metas, reportes avanzados y sin anuncios.")
            .font(.mcBody)
            .foregroundStyle(Color.textMuted)
            .multilineTextAlignment(.center)
            .mcCard()
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 12) {
            feature("Hogares ilimitados", icon: "house.fill")
            feature("Miembros ilimitados por hogar", icon: "person.3.fill")
            feature("Categorías personalizadas sin límite", icon: "tag.fill")
            feature("Multi-moneda con tasas automáticas", icon: "arrow.left.arrow.right.circle.fill")
            feature("Reportes avanzados y exportación", icon: "chart.bar.doc.horizontal.fill")
            feature("Metas de ahorro ilimitadas", icon: "target")
            feature("Widgets y Live Activities", icon: "rectangle.on.rectangle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    private func feature(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 24)
            Text(title).font(.mcBody).foregroundStyle(Color.textPrimary)
            Spacer()
        }
    }

    private var pricesCard: some View {
        HStack(spacing: 12) {
            priceTile(title: "Mensual", price: "USD 4,99", note: "/mes")
            priceTile(title: "Anual", price: "USD 39,99", note: "/año · -30%", highlighted: true)
        }
    }

    private func priceTile(title: String, price: String, note: String, highlighted: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased()).font(.mcLabel).foregroundStyle(Color.textMuted)
            Text(price).font(.mcH2).foregroundStyle(Color.textPrimary)
            Text(note).font(.mcCaption).foregroundStyle(Color.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(highlighted ? Color.brandPrimary.opacity(0.12) : Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(highlighted ? Color.brandPrimary : Color.appBorder, lineWidth: highlighted ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var upgradeButton: some View {
        Button("Probar 7 días gratis") {
            // TODO: llamar RevenueCat Purchases.shared.purchase(package:)
        }
        .buttonStyle(MCPrimaryButton())
    }

    @MainActor
    private func checkEntitlements() async {
        isChecking = true
        defer { isChecking = false }
        hasActivePremium = (try? await EntitlementService.shared.hasActive(UserEntitlement.Name.premium)) ?? false
    }
}
