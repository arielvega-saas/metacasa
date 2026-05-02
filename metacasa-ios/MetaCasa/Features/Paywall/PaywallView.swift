import SwiftUI
import RevenueCat

/// Paywall real conectado a RevenueCat. Hasta que haya `REVENUECAT_API_KEY` en
/// `Info.plist`, cae al modo placeholder con pricing hardcoded.
///
/// Cuando esté configurado:
///   - Lee el offering "current" del dashboard y renderiza sus packages.
///   - Tap en un package → `Purchases.shared.purchase` via `RevenueCatService`.
///   - Tras una compra exitosa, el webhook actualiza `user_entitlements` y
///     `EntitlementService.hasActive(.premium)` devuelve true.
struct PaywallView: View {
    @State private var hasActivePremium = false
    @State private var isChecking = true
    @State private var offering: Offering?
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var rcConfigured = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.brandWarning)
                        .padding(.top, 40)

                    Text("\(Text("app.name")) Premium")
                        .font(.mcH1)
                        .foregroundStyle(Color.textPrimary)

                    if hasActivePremium {
                        activeCard
                    } else {
                        pitchCard
                        featuresList

                        if rcConfigured, let offering {
                            packagesGrid(offering: offering)
                            upgradeButton
                        } else {
                            pricesCard
                            if !rcConfigured {
                                notConfiguredCard
                            }
                        }

                        restoreButton
                    }

                    if let msg = errorMessage {
                        Text(msg)
                            .font(.mcCaption)
                            .foregroundStyle(Color.brandDanger)
                            .multilineTextAlignment(.center)
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
        .navigationTitle(Text("Premium"))
        .task { await bootstrap() }
    }

    // MARK: - Sections

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
        Text("Llevá tu gestión financiera al siguiente nivel. Hogares ilimitados, metas, reportes avanzados, asistente IA y sin anuncios.")
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
            feature("Asistente IA on-device", icon: "sparkles")
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

    // Grid real con packages del offering actual.
    private func packagesGrid(offering: Offering) -> some View {
        HStack(spacing: 12) {
            ForEach(offering.availablePackages, id: \.identifier) { package in
                packageTile(package: package)
            }
        }
    }

    private func packageTile(package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let isAnnual = package.packageType == .annual
        let title = titleForPackage(package)
        let price = package.storeProduct.localizedPriceString
        let note = subtitleForPackage(package)
        return Button {
            selectedPackage = package
        } label: {
            VStack(spacing: 6) {
                Text(title.uppercased()).font(.mcLabel).foregroundStyle(Color.textMuted)
                Text(price).font(.mcSerifAmount).foregroundStyle(Color.textPrimary)
                Text(note).font(.mcCaption).foregroundStyle(Color.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isAnnual ? Color.brandPrimary.opacity(0.12) : Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected ? Color.brandPrimary : (isAnnual ? Color.brandPrimary.opacity(0.5) : Color.appBorder),
                        lineWidth: isSelected ? 2.5 : (isAnnual ? 2 : 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func titleForPackage(_ package: Package) -> String {
        switch package.packageType {
        case .annual:   return "Anual"
        case .monthly:  return "Mensual"
        case .weekly:   return "Semanal"
        case .lifetime: return "De por vida"
        case .sixMonth: return "6 meses"
        case .threeMonth: return "3 meses"
        case .twoMonth: return "2 meses"
        default:        return package.identifier
        }
    }

    private func subtitleForPackage(_ package: Package) -> String {
        switch package.packageType {
        case .annual:  return "/año"
        case .monthly: return "/mes"
        case .weekly:  return "/sem"
        default:       return ""
        }
    }

    // Placeholder cuando no hay SDK configurado.
    private var pricesCard: some View {
        HStack(spacing: 12) {
            priceTile(title: "Mensual", price: "USD 4,99", note: "/mes")
            priceTile(title: "Anual", price: "USD 39,99", note: "/año · -30%", highlighted: true)
        }
    }

    private func priceTile(title: String, price: String, note: String, highlighted: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased()).font(.mcLabel).foregroundStyle(Color.textMuted)
            Text(price).font(.mcSerifAmount).foregroundStyle(Color.textPrimary)
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

    private var notConfiguredCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Compras deshabilitadas", systemImage: "info.circle.fill")
                .font(.mcLabel).foregroundStyle(Color.brandWarning)
            Text("Agregá tu `REVENUECAT_API_KEY` al Info.plist para activar la compra real.")
                .font(.mcCaption).foregroundStyle(Color.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var upgradeButton: some View {
        Button {
            Task { await performPurchase() }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "crown.fill")
                }
                Text(ctaLabel)
            }
        }
        .buttonStyle(MCPrimaryButton())
        .disabled(isPurchasing || selectedPackage == nil)
    }

    private var ctaLabel: String {
        guard let package = selectedPackage else { return "Suscribirme" }
        let price = package.storeProduct.localizedPriceString
        if let discount = package.storeProduct.introductoryDiscount,
           discount.paymentMode == .freeTrial {
            return "Probar gratis · luego \(price)"
        }
        return "Suscribirme · \(price)"
    }

    private var restoreButton: some View {
        Button {
            Task { await performRestore() }
        } label: {
            Text("Restaurar compras")
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
        }
        .disabled(isPurchasing)
    }

    // MARK: - Actions

    @MainActor
    private func bootstrap() async {
        isChecking = true
        defer { isChecking = false }

        rcConfigured = await RevenueCatService.shared.configured
        hasActivePremium = (try? await EntitlementService.shared.hasActive(UserEntitlement.Name.premium)) ?? false

        if rcConfigured, !hasActivePremium {
            do {
                let off = try await RevenueCatService.shared.currentOffering()
                offering = off
                // Pre-seleccionar el annual si existe.
                selectedPackage = off.annual ?? off.availablePackages.first
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func performPurchase() async {
        guard let package = selectedPackage else { return }
        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let ok = try await RevenueCatService.shared.purchase(package: package)
            if ok {
                hasActivePremium = true
                Haptics.play(.success)
            } else {
                Haptics.play(.warning)
                errorMessage = "La compra se completó pero el entitlement aún no está activo. Probá en unos segundos."
            }
        } catch RevenueCatService.ServiceError.userCanceled {
            // Silencioso: usuario canceló.
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func performRestore() async {
        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let ok = try await RevenueCatService.shared.restore()
            hasActivePremium = ok
            if !ok {
                errorMessage = "No se encontraron compras previas asociadas a tu Apple ID."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
