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

                    Text("paywall.title")
                        .font(.mcH1)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    if hasActivePremium {
                        activeCard
                    } else {
                        pitchCard
                        featuresList

                        if rcConfigured, let offering {
                            packagesGrid(offering: offering)
                            upgradeButton
                            trialTimeline
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

                    Text("paywall.manage.hint")
                        .font(.mcCaption)
                        .foregroundStyle(Color.textDim)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(Text("paywall.navTitle"))
        .task { await bootstrap() }
    }

    // MARK: - Sections

    private var activeCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.brandSuccess)
                .font(.system(size: 44))
            Text("paywall.active.title").font(.mcH2).foregroundStyle(Color.textPrimary)
            Text("paywall.active.thanks")
                .font(.mcBody).foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .mcCard()
    }

    private var pitchCard: some View {
        Text("paywall.pitch")
            .font(.mcBody)
            .foregroundStyle(Color.textMuted)
            .multilineTextAlignment(.center)
            .mcCard()
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 12) {
            feature(String(localized: "paywall.feature.aiUnlimited"), icon: "sparkles")
            feature(String(localized: "paywall.feature.reports"), icon: "chart.bar.doc.horizontal.fill")
            feature(String(localized: "paywall.feature.voice"), icon: "waveform")
            feature(String(localized: "paywall.feature.importXLSX"), icon: "tray.and.arrow.down.fill")
            feature(String(localized: "paywall.feature.export"), icon: "square.and.arrow.up.fill")
            feature(String(localized: "paywall.feature.backup"), icon: "icloud.and.arrow.up.fill")
            feature(String(localized: "paywall.feature.households"), icon: "person.3.fill")
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
        let savings = annualSavingsPercent(in: offering)
        return HStack(spacing: 12) {
            ForEach(offering.availablePackages, id: \.identifier) { package in
                packageTile(
                    package: package,
                    savingsPercent: package.packageType == .annual ? savings : nil
                )
            }
        }
        .padding(.top, savings != nil ? 8 : 0) // aire para el badge flotante
    }

    /// Ahorro real del plan anual vs pagar 12 meses del mensual, calculado con
    /// los precios VIVOS del offering (nunca hardcodeado: si cambiás precios en
    /// App Store Connect, el badge sigue siendo verdad).
    /// Devuelve nil si no hay ambos planes o si el anual no ahorra nada.
    private func annualSavingsPercent(in offering: Offering) -> Int? {
        guard let annual = offering.availablePackages.first(where: { $0.packageType == .annual }),
              let monthly = offering.availablePackages.first(where: { $0.packageType == .monthly })
        else { return nil }
        let annualPrice = annual.storeProduct.price as Decimal
        let monthlyYear = (monthly.storeProduct.price as Decimal) * 12
        guard monthlyYear > 0, annualPrice < monthlyYear else { return nil }
        let ratio = (annualPrice / monthlyYear) as NSDecimalNumber
        let pct = Int(((1 - ratio.doubleValue) * 100).rounded())
        return pct > 0 ? pct : nil
    }

    private func packageTile(package: Package, savingsPercent: Int? = nil) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let isAnnual = package.packageType == .annual
        let title = titleForPackage(package)
        let price = package.storeProduct.localizedPriceString
        let note = subtitleForPackage(package)
        return Button {
            Haptics.play(.selection)
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
            // Badge de ahorro real sobre el borde superior del tile anual.
            .overlay(alignment: .top) {
                if let savingsPercent {
                    Text(String(format: String(localized: "paywall.savings.badge %lld"), savingsPercent))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.brandPrimary)
                        .foregroundStyle(Color.appBackground)
                        .clipShape(Capsule())
                        .offset(y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(title), \(price)"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Línea de tiempo del trial: qué pasa hoy, el día 5 y el día 7.
    /// Reduce la ansiedad del "¿cuándo me cobran?" — patrón de Monarch, y los
    /// benchmarks de RevenueCat lo asocian a menos cancelaciones tempranas.
    private var trialTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("paywall.timeline.title")
                .font(.mcLabel)
                .foregroundStyle(Color.textMuted)
            timelineRow(icon: "lock.open.fill", color: .brandSuccess,
                        title: "paywall.timeline.today", subtitle: "paywall.timeline.today.detail")
            timelineRow(icon: "bell.fill", color: .brandWarning,
                        title: "paywall.timeline.day5", subtitle: "paywall.timeline.day5.detail")
            timelineRow(icon: "creditcard.fill", color: .brandPrimary,
                        title: "paywall.timeline.day7", subtitle: "paywall.timeline.day7.detail")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcCard()
    }

    private func timelineRow(icon: String, color: Color, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.mcBody.weight(.semibold)).foregroundStyle(Color.textPrimary)
                Text(subtitle).font(.mcCaption).foregroundStyle(Color.textMuted)
            }
            Spacer(minLength: 0)
        }
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

    // Placeholder cuando no hay SDK configurado.
    private var pricesCard: some View {
        HStack(spacing: 12) {
            priceTile(title: String(localized: "paywall.package.monthly"), price: "USD 4,99", note: String(localized: "paywall.per.month"))
            priceTile(title: String(localized: "paywall.package.annual"), price: "USD 39,99", note: String(localized: "paywall.per.year.discount"), highlighted: true)
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
            Label("paywall.unavailable.title", systemImage: "info.circle.fill")
                .font(.mcLabel).foregroundStyle(Color.brandWarning)
            // El copy de developer JAMÁS puede llegar a producción/review
            // (lección leccion-monetizacion-release del harness).
            #if DEBUG
            Text(verbatim: "DEV: agregá tu `REVENUECAT_API_KEY` al Info.plist para activar la compra real.")
                .font(.mcCaption).foregroundStyle(Color.textDim)
            #else
            Text("paywall.unavailable.message")
                .font(.mcCaption).foregroundStyle(Color.textDim)
            #endif
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
        guard let package = selectedPackage else { return String(localized: "paywall.cta.try") }
        let price = package.storeProduct.localizedPriceString
        if let discount = package.storeProduct.introductoryDiscount,
           discount.paymentMode == .freeTrial {
            return String(format: String(localized: "paywall.cta.trial %@"), price)
        }
        return String(format: String(localized: "paywall.cta.unlock %@"), price)
    }

    private var restoreButton: some View {
        Button {
            Task { await performRestore() }
        } label: {
            Text("paywall.restore")
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
                errorMessage = String(localized: "paywall.error.verify")
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
                errorMessage = String(localized: "paywall.error.noPurchases")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
