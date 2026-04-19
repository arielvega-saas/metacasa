import SwiftUI

struct CreateJoinHouseholdView: View {
    @Environment(AppState.self) private var appState
    @State private var mode: Mode = .create
    @State private var householdName = "Mi Hogar"
    @State private var currency = localeCurrency()
    @State private var inviteToken = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode { case create, join }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        modePicker
                        Group {
                            switch mode {
                            case .create: createForm
                            case .join: joinForm
                            }
                        }
                        .transition(.opacity)
                        .animation(.default, value: mode)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("LogoMetacasa")
                .resizable().scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            Text("Home Finance")
                .font(.mcH1)
                .foregroundStyle(Color.textPrimary)
            Text("Creá un hogar nuevo o unite a uno con invite.")
                .font(.mcBody).multilineTextAlignment(.center)
                .foregroundStyle(Color.textMuted)
        }
    }

    private var modePicker: some View {
        Picker("Modo", selection: $mode) {
            Text("Crear").tag(Mode.create)
            Text("Unirme").tag(Mode.join)
        }
        .pickerStyle(.segmented)
    }

    private var createForm: some View {
        VStack(spacing: 16) {
            MCTextField(title: "Nombre del hogar", text: $householdName, autocapitalize: .words)

            VStack(alignment: .leading, spacing: 6) {
                Text("MONEDA PRINCIPAL").font(.mcLabel).foregroundStyle(Color.textMuted)
                CurrencyPickerButton(selectedCode: $currency, label: "Moneda del hogar")
            }

            if let msg = errorMessage {
                Text(msg).font(.mcCaption).foregroundStyle(Color.brandDanger)
            }
            Button {
                Task { await submitCreate() }
            } label: {
                Text(isLoading ? "Creando..." : "Crear hogar")
            }
            .buttonStyle(MCPrimaryButton())
            .disabled(isLoading || householdName.isEmpty)

            Text("Vas a poder agregar otras monedas y cambiar esta después.")
                .font(.mcCaption)
                .foregroundStyle(Color.textDim)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private var joinForm: some View {
        VStack(spacing: 16) {
            MCTextField(title: "Token de invitación", text: $inviteToken)

            if let msg = errorMessage {
                Text(msg).font(.mcCaption).foregroundStyle(Color.brandDanger)
            }
            Button {
                Task { await submitJoin() }
            } label: {
                Text(isLoading ? "Uniéndote..." : "Unirme al hogar")
            }
            .buttonStyle(MCPrimaryButton())
            .disabled(isLoading || inviteToken.isEmpty)

            Text("Pedile al admin del hogar que te genere un invite.")
                .font(.mcCaption)
                .foregroundStyle(Color.textDim)
                .multilineTextAlignment(.center)
        }
    }

    @MainActor
    private func submitCreate() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let h = try await HouseholdService.shared.create(
                name: householdName,
                defaultCurrency: currency.uppercased()
            )
            appState.households.append(h)
            appState.currentHouseholdId = h.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func submitJoin() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await HouseholdService.shared.acceptInvitation(token: inviteToken)
            try await appState.loadHouseholds()
        } catch {
            errorMessage = "No se pudo aceptar: \(error.localizedDescription)"
        }
    }

    /// Adivina la moneda según el locale del device (ARS, USD, EUR, BRL, MXN, etc).
    /// Si no podemos mapear, USD como default.
    static func localeCurrency() -> String {
        let code = Locale.current.currency?.identifier.uppercased() ?? "USD"
        return CurrenciesCatalog.info(for: code) != nil ? code : "USD"
    }
}
