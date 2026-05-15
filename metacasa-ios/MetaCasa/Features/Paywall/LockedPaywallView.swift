import SwiftUI
import StoreKit
import RevenueCat

/// Paywall **duro** que se muestra a pantalla completa cuando el trial de 7 días
/// venció y no hay suscripción activa. NO es descartable: la app queda
/// inutilizable hasta que el usuario se suscriba o restaure una compra previa.
///
/// Cumple con App Review (Guideline 3.1.2): muestra precio, que es
/// auto-renovable, botón de restaurar, y links a Términos y Privacidad.
struct LockedPaywallView: View {
    /// Se llama tras una compra/restauración exitosa para re-evaluar el acceso.
    var onUnlock: () async -> Void

    @State private var offering: Offering?
    @State private var selectedPackage: Package?
    @State private var rcConfigured = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    private let termsURL = URL(string: "https://metacasa-app-cf592.web.app/terms.html")!
    private let privacyURL = URL(string: "https://metacasa-app-cf592.web.app/privacy.html")!

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.brandWarning)
                        .padding(.top, 56)

                    Text("Tu prueba gratuita terminó")
                        .font(.mcH1)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Disfrutaste 7 días completos de \(Text("app.name")). Para seguir usando la app, elegí un plan. Cancelás cuando quieras desde tu cuenta de App Store.")
                        .font(.mcBody)
                        .foregroundStyle(Color.textMuted)
                        .multilineTextAlignment(.center)
                        .mcCard()

                    featuresList

                    if rcConfigured, let offering {
                        packagesGrid(offering: offering)
                        subscribeButton
                    } else {
                        pricesPlaceholder
                        notConfiguredCard
                    }

                    restoreButton

                    if let msg = errorMessage {
                        Text(msg)
                            .font(.mcCaption)
                            .foregroundStyle(Color.brandDanger)
                            .multilineTextAlignment(.center)
                    }

                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
            }
        }
        .interactiveDismissDisabled(true)
        .task { await bootstrap() }
    }

    // MARK: - Secciones

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 12) {
            feature("Asistente IA financiero", icon: "sparkles")
            feature("Hogares y miembros ilimitados", icon: "person.3.fill")
            feature("Presupuestos y metas sin límite", icon: "target")
            feature("Reportes avanzados y exportación", icon: "chart.bar.doc.horizontal.fill")
            feature("Multi-moneda con tasas automáticas", icon: "arrow.left.arrow.right.circle.fill")
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
        return Button {
            selectedPackage = package
        } label: {
            VStack(spacing: 6) {
                Text(titleForPackage(package).uppercased())
                    .font(.mcLabel).foregroundStyle(Color.textMuted)
                Text(package.storeProduct.localizedPriceString)
                    .font(.mcSerifAmount).foregroundStyle(Color.textPrimary)
                Text(subtitleForPackage(package))
                    .font(.mcCaption).foregroundStyle(Color.textMuted)
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

    private var pricesPlaceholder: some View {
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
            Label("Compras no disponibles aún", systemImage: "info.circle.fill")
                .font(.mcLabel).foregroundStyle(Color.brandWarning)
            Text("Estamos terminando de habilitar los pagos. Volvé a intentar en unos minutos.")
                .font(.mcCaption).foregroundStyle(Color.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var subscribeButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            HStack {
                if isWorking { ProgressView().tint(.white) }
                else { Image(systemName: "crown.fill") }
                Text(ctaLabel)
            }
        }
        .buttonStyle(MCPrimaryButton())
        .disabled(isWorking || selectedPackage == nil)
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
            Task { await restore() }
        } label: {
            Text("Restaurar compras")
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
        }
        .disabled(isWorking)
    }

    private var legalFooter: some View {
        VStack(spacing: 6) {
            Text("Suscripción auto-renovable. Se cobra a tu Apple ID. Se renueva salvo que la canceles al menos 24 h antes del fin del período, desde Ajustes → Apple ID.")
                .font(.mcCaption)
                .foregroundStyle(Color.textDim)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Términos", destination: termsURL)
                Link("Privacidad", destination: privacyURL)
            }
            .font(.mcCaption)
            .foregroundStyle(Color.brandPrimary)
        }
        .padding(.top, 8)
    }

    // MARK: - Acciones

    @MainActor
    private func bootstrap() async {
        rcConfigured = await RevenueCatService.shared.configured
        guard rcConfigured else { return }
        do {
            let off = try await RevenueCatService.shared.currentOffering()
            offering = off
            selectedPackage = off.annual ?? off.availablePackages.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func purchase() async {
        guard let package = selectedPackage else { return }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let ok = try await RevenueCatService.shared.purchase(package: package)
            if ok {
                Haptics.play(.success)
                await onUnlock()
            } else {
                Haptics.play(.warning)
                errorMessage = "La compra se completó pero el acceso aún no se activó. Probá 'Restaurar compras' en unos segundos."
            }
        } catch RevenueCatService.ServiceError.userCanceled {
            // Silencioso.
        } catch {
            Haptics.play(.error)
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func restore() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let ok = try await RevenueCatService.shared.restore()
            if ok {
                Haptics.play(.success)
                await onUnlock()
            } else {
                errorMessage = "No se encontraron suscripciones activas en tu Apple ID."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
