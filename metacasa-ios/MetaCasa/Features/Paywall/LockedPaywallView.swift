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

                    Text("paywall.locked.title")
                        .font(.mcH1)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(String(format: String(localized: "paywall.locked.body %@"), String(localized: "app.name")))
                        .font(.mcBody)
                        .foregroundStyle(Color.textMuted)
                        .multilineTextAlignment(.center)
                        .mcCard()

                    featuresList

                    if rcConfigured, let offering {
                        packagesGrid(offering: offering)
                        subscribeButton
                    } else {
                        // Antes acá se mostraban `pricesPlaceholder` (USD 4,99 / 39,99
                        // HARDCODEADOS) y ningún botón de compra. Dos problemas serios:
                        //
                        // 1. Un usuario que quiere pagar, no puede. Está en la pantalla que
                        //    bloquea la app, viendo precios, sin forma de avanzar.
                        // 2. Esos precios pueden no coincidir con los de App Store Connect, y si
                        //    el reviewer cae en este estado es rechazo por 2.1 / 3.1.2 — precios
                        //    que no matchean e IAP no funcional.
                        //
                        // Mostrar un precio inventado es peor que no mostrar ninguno: promete algo
                        // que la app no puede cumplir en ese momento. Ahora se explica el estado y
                        // se ofrece reintentar, que es la única acción útil que existe acá.
                        notConfiguredCard
                        retryOfferingButton
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
            feature(String(localized: "paywall.locked.feature.ai"), icon: "sparkles")
            feature(String(localized: "paywall.locked.feature.households"), icon: "person.3.fill")
            feature(String(localized: "paywall.locked.feature.budgets"), icon: "target")
            feature(String(localized: "paywall.locked.feature.reports"), icon: "chart.bar.doc.horizontal.fill")
            feature(String(localized: "paywall.locked.feature.multicurrency"), icon: "arrow.left.arrow.right.circle.fill")
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
        case .annual:   return String(localized: "paywall.package.annual")
        case .monthly:  return String(localized: "paywall.package.monthly")
        case .weekly:   return String(localized: "paywall.package.weekly")
        case .lifetime: return String(localized: "paywall.package.lifetime")
        case .sixMonth: return String(localized: "paywall.package.sixMonth")
        case .threeMonth: return String(localized: "paywall.package.threeMonth")
        case .twoMonth: return String(localized: "paywall.package.twoMonth")
        default:        return package.identifier
        }
    }

    private func subtitleForPackage(_ package: Package) -> String {
        switch package.packageType {
        case .annual:  return String(localized: "paywall.per.year")
        case .monthly: return String(localized: "paywall.per.month")
        case .weekly:  return String(localized: "paywall.per.week")
        default:       return ""
        }
    }

    // `pricesPlaceholder` (USD 4,99 / 39,99 hardcodeados) se eliminó a propósito. Dejarlo como
    // código muerto era una trampa: el próximo que lo viera lo volvería a usar, y son precios
    // inventados que pueden no coincidir con App Store Connect. Los precios reales SIEMPRE salen
    // del offering de StoreKit, nunca de una constante.

    /// Reintenta cargar el offering. Es la única salida real cuando la carga falló por red o
    /// porque los productos todavía no estaban aprobados: sin esto, el usuario bloqueado tiene
    /// que matar la app y volver a abrirla para tener otra chance de pagar.
    private var retryOfferingButton: some View {
        Button {
            Haptics.play(.selection)
            Task { await bootstrap() }
        } label: {
            if isWorking {
                ProgressView().tint(Color(hex: "#0E1312"))
            } else {
                Text("paywall.locked.retry")
            }
        }
        .buttonStyle(MCPrimaryButton())
        .disabled(isWorking)
    }

    private var notConfiguredCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("paywall.locked.unavailable.title", systemImage: "info.circle.fill")
                .font(.mcLabel).foregroundStyle(Color.brandWarning)
            Text("paywall.locked.unavailable.message")
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
        guard let package = selectedPackage else { return String(localized: "paywall.locked.cta.subscribe") }
        let price = package.storeProduct.localizedPriceString
        if let discount = package.storeProduct.introductoryDiscount,
           discount.paymentMode == .freeTrial {
            return String(format: String(localized: "paywall.cta.trial %@"), price)
        }
        return String(format: String(localized: "paywall.locked.cta.subscribePrice %@"), price)
    }

    private var restoreButton: some View {
        Button {
            Task { await restore() }
        } label: {
            Text("paywall.restore")
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
        }
        .disabled(isWorking)
    }

    private var legalFooter: some View {
        VStack(spacing: 6) {
            Text("paywall.locked.legal")
                .font(.mcCaption)
                .foregroundStyle(Color.textDim)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("paywall.legal.terms", destination: termsURL)
                Link("paywall.legal.privacy", destination: privacyURL)
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
            // `onUnlock()` se llama SIEMPRE, gane o pierda el booleano de RevenueCat.
            //
            // Ese booleano sale de `entitlements["premium"]?.isActive`, así que da `false` si el
            // entitlement del dashboard no se llama literalmente "premium" o si RC todavía no
            // propagó la compra. Antes, en ese caso, Apple YA HABÍA COBRADO y la app seguía
            // trabada — con la respuesta correcta a una línea de distancia, porque `onUnlock()`
            // consulta StoreKit 2 directo (`AccessController`), que sí concede el acceso.
            // El booleano de RC ahora sólo decide el mensaje, no el acceso.
            await onUnlock()
            if ok {
                Haptics.play(.success)
            } else {
                Haptics.play(.warning)
                errorMessage = String(localized: "paywall.locked.error.pending")
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
            // Mismo criterio que en la compra: quien manda es StoreKit, no RevenueCat.
            // Antes, alguien que reinstalaba habiendo pagado podía ver "no tenés suscripciones"
            // aunque StoreKit tuviera la suya activa. Eso termina en refund y una estrella.
            await onUnlock()
            if ok {
                Haptics.play(.success)
            } else {
                errorMessage = String(localized: "paywall.locked.error.noSubs")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
