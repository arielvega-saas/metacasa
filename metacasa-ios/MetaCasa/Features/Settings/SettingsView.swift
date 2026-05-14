import SwiftUI

/// Pantalla de Ajustes refactorizada (Sprint 2026-05-06).
///
/// Reorganización: pasamos de 8 secciones genéricas tipo `List` iOS a 3 bloques
/// semánticos con cards Midnight Sage (Organización / Herramientas / Avanzado),
/// más un footer con email + version + legal links. Cada item tiene icon
/// teñido en circle, haptic al tap y `.pressableScale` para sentirse premium.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(PrivacyManager.self) private var privacy
    @Environment(OnboardingProgress.self) private var onboarding
    @State private var showSignOutConfirm = false
    @State private var showWelcomeTour = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                organizationSection
                toolsSection
                advancedSection
                footerSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(Text("more.settings"))
        .confirmationDialog("settings.signoutConfirm", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("settings.signout", role: .destructive) {
                Task { await appState.signOut() }
            }
            Button("action.cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showWelcomeTour) {
            WelcomeTourView()
        }
    }

    // MARK: - Sections

    private var organizationSection: some View {
        sectionContainer(
            title: String(localized: "settings.org.title", defaultValue: "ORGANIZACIÓN"),
            subtitle: String(localized: "settings.org.subtitle", defaultValue: "Tu hogar y cómo lo configurás")
        ) {
            if let current = currentHousehold {
                HouseholdHeaderRow(name: current.name, currency: current.defaultCurrency)
                rowDivider
            }
            if appState.households.count > 1 {
                householdSwitcherRow
                rowDivider
            }
            navRow(icon: "house.fill", labelKey: "more.edit_household") {
                HouseholdSettingsView()
            }
            rowDivider
            navRow(icon: "person.3.fill", labelKey: "more.members") {
                HouseholdMembersView()
            }
            rowDivider
            navRow(icon: "tag.fill", labelKey: "more.categories") {
                ManageCategoriesView()
            }
        }
    }

    private var toolsSection: some View {
        sectionContainer(
            title: String(localized: "settings.tools.title", defaultValue: "HERRAMIENTAS"),
            subtitle: String(localized: "settings.tools.subtitle", defaultValue: "Apariencia, idioma y datos")
        ) {
            navRow(icon: "moon.stars", labelKey: "settings.appearance") { AppearanceSettingsView() }
            rowDivider
            navRow(icon: "bell.badge", labelKey: "settings.notifications") { NotificationSettingsView() }
            rowDivider
            navRow(icon: "globe", labelKey: "settings.language") { LanguageSettingsView() }
            rowDivider
            navRow(icon: "dollarsign.arrow.circlepath", labelKey: "settings.fxRates") { FXRatesView() }
            rowDivider
            navRow(icon: "externaldrive.badge.icloud", labelKey: "settings.backup") { BackupView() }
            rowDivider
            actionRow(icon: "play.circle", labelKey: "tour.replay") {
                showWelcomeTour = true
            }
            if onboarding.isDismissed {
                rowDivider
                actionRow(icon: "checklist", labelKey: "onboarding.restore") {
                    Haptics.play(.success)
                    onboarding.resetDismissal()
                    Task { await onboarding.refresh(appState: appState) }
                }
            }
        }
    }

    private var advancedSection: some View {
        sectionContainer(
            title: String(localized: "settings.advanced.title", defaultValue: "AVANZADO"),
            subtitle: String(localized: "settings.advanced.subtitle", defaultValue: "Privacidad y sesión")
        ) {
            PrivacyToggleRow()
            rowDivider
            BiometricsStatusRow()
            rowDivider
            actionRow(icon: "rectangle.portrait.and.arrow.right",
                      labelKey: "settings.signout",
                      destructive: true) {
                showSignOutConfirm = true
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            if let email = appState.session?.email {
                Text(email)
                    .font(.mcCaption)
                    .foregroundStyle(Color.textDim)
            }
            HStack(spacing: 10) {
                NavigationLink {
                    LegalView(kind: .privacy)
                } label: {
                    Text("settings.legal.privacy")
                        .font(.mcCaption.weight(.semibold))
                        .foregroundStyle(Color.textMuted)
                }
                Text("·").foregroundStyle(Color.textDim)
                NavigationLink {
                    LegalView(kind: .terms)
                } label: {
                    Text("settings.legal.terms")
                        .font(.mcCaption.weight(.semibold))
                        .foregroundStyle(Color.textMuted)
                }
            }
            Text("v\(Config.appVersion) (\(Config.buildNumber))")
                .font(.mcCaption)
                .foregroundStyle(Color.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - Special rows

    private var householdSwitcherRow: some View {
        Menu {
            ForEach(appState.households) { h in
                Button {
                    Haptics.play(.selection)
                    appState.switchHousehold(to: h.id)
                } label: {
                    Label(h.name, systemImage: appState.currentHouseholdId == h.id ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.brandPrimary.opacity(0.12)))
                Text("settings.changeHousehold")
                    .font(.mcBody)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.textDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Helpers

    private func sectionContainer<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.mcLabel)
                    .foregroundStyle(Color.textMuted)
                Text(subtitle)
                    .font(.mcCaption)
                    .foregroundStyle(Color.textDim)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
        }
    }

    private func navRow<Destination: View>(
        icon: String,
        labelKey: LocalizedStringKey,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            rowContent(icon: icon, labelKey: labelKey, value: nil, destructive: false, hasChevron: true)
        }
        .buttonStyle(.plain)
        .pressableScale(0.99)
    }

    private func actionRow(
        icon: String,
        labelKey: LocalizedStringKey,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.play(.selection)
            action()
        } label: {
            rowContent(icon: icon, labelKey: labelKey, value: nil, destructive: destructive, hasChevron: false)
        }
        .buttonStyle(.plain)
        .pressableScale(0.99)
    }

    private func rowContent(
        icon: String,
        labelKey: LocalizedStringKey,
        value: String?,
        destructive: Bool,
        hasChevron: Bool
    ) -> some View {
        let displayColor = destructive ? Color.brandDanger : Color.brandPrimary
        let textColor = destructive ? Color.brandDanger : Color.textPrimary
        return HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(displayColor)
                .frame(width: 38, height: 38)
                .background(Circle().fill(displayColor.opacity(0.12)))
            Text(labelKey)
                .font(.mcBody)
                .foregroundStyle(textColor)
            Spacer()
            if let value {
                Text(value)
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
            }
            if hasChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textDim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Divider()
            .background(Color.appBorder.opacity(0.5))
            .padding(.leading, 16 + 38 + 14)
    }

    private var currentHousehold: Household? {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })
    }
}

// MARK: - Special rows (sub-views)

/// Header row del bloque "Organización": muestra el nombre + currency del
/// hogar actual. Read-only, sin chevron.
private struct HouseholdHeaderRow: View {
    let name: String
    let currency: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "house.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.brandPrimary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.mcBody.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("more.section.household")
                    .font(.mcCaption)
                    .foregroundStyle(Color.textMuted)
            }
            Spacer()
            Text(currency)
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Color.textMuted)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.appSurfaceInset))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// Toggle row para el modo privacidad. Sub-struct porque `@Bindable` requiere
/// estar en el body de un View, no en una computed property.
private struct PrivacyToggleRow: View {
    @Environment(PrivacyManager.self) private var privacy

    var body: some View {
        @Bindable var privacy = privacy
        HStack(spacing: 14) {
            Image(systemName: privacy.isEnabled ? "eye.slash.fill" : "eye.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.brandPrimary.opacity(0.12)))
            Text("settings.privacy")
                .font(.mcBody)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Toggle("", isOn: $privacy.isEnabled)
                .labelsHidden()
                .tint(.brandPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// Status row de biometría — display-only.
private struct BiometricsStatusRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.brandPrimary.opacity(0.12)))
            Text("settings.biometrics")
                .font(.mcBody)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(BiometricAuth.isAvailable
                 ? BiometricAuth.biometryLabel
                 : String(localized: "settings.biometrics.unavailable"))
                .font(.mcCaption)
                .foregroundStyle(Color.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
