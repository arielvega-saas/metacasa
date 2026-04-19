import SwiftUI

struct CreateJoinHouseholdView: View {
    @Environment(AppState.self) private var appState
    @State private var mode: Mode = .create
    @State private var householdName = "Mi Hogar"
    @State private var currency = "USD"
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
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("LogoMetacasa")
                .resizable().scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text("Tu hogar")
                .font(.mcH1)
                .foregroundStyle(Color.textPrimary)
            Text("Creá uno nuevo o unite a uno existente con un invite.")
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
            MCTextField(title: "Moneda principal (ISO)", text: $currency, autocapitalize: .characters)

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
}
