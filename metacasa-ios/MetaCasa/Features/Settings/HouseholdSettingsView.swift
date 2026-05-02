import SwiftUI
import Observation

@MainActor
@Observable
final class HouseholdSettingsViewModel {
    var name: String = ""
    var currency: String = "USD"
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    func loadFrom(_ h: Household) {
        name = h.name
        currency = h.defaultCurrency
    }

    func saveName(householdId: UUID) async -> Household? {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await HouseholdService.shared.renameHousehold(id: householdId, name: name)
            successMessage = "Nombre actualizado"
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func saveCurrency(householdId: UUID) async -> Household? {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await HouseholdService.shared.updateCurrency(householdId: householdId, currency: currency)
            successMessage = "Moneda actualizada"
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

struct HouseholdSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = HouseholdSettingsViewModel()
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            Section("Datos del hogar") {
                TextField("Nombre", text: $viewModel.name)
                    .textInputAutocapitalization(.words)

                HStack {
                    Text("Moneda")
                    Spacer()
                    CurrencyPickerButton(selectedCode: $viewModel.currency, label: "")
                }
            }

            if let msg = viewModel.errorMessage {
                Section { Text(msg).foregroundStyle(.red) }
            }
            if let msg = viewModel.successMessage {
                Section { Text(msg).foregroundStyle(.green) }
            }

            Section {
                Button {
                    Task { await saveAll() }
                } label: {
                    if viewModel.isLoading {
                        HStack { ProgressView(); Text("Guardando...") }
                    } else {
                        Text("Guardar cambios")
                    }
                }
                .disabled(viewModel.isLoading || !hasChanges)
            }

            if currentRole == .owner {
                Section("Zona peligrosa") {
                    Button("Eliminar hogar", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle(Text("Editar hogar"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let h = currentHousehold { viewModel.loadFrom(h) }
        }
        .confirmationDialog(
            "¿Eliminar hogar?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar todo", role: .destructive) {
                Task { await deleteHousehold() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminan hogar, miembros, categorías, cuentas, transacciones, presupuestos y metas. Irreversible.")
        }
    }

    private var currentHousehold: Household? {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })
    }

    private var hasChanges: Bool {
        guard let h = currentHousehold else { return false }
        return viewModel.name != h.name || viewModel.currency != h.defaultCurrency
    }

    /// Consultamos localmente quién es el caller comparando con appState.households
    /// (asumimos que el rol viene con el fetchMembers futuro; por ahora consideramos
    /// owner al creador del hogar).
    private var currentRole: MemberRole {
        guard let h = currentHousehold else { return .viewer }
        return h.createdBy == appState.currentUserId ? .owner : .member
    }

    @MainActor
    private func saveAll() async {
        guard let h = currentHousehold else { return }

        // Si cambió solo el nombre
        if viewModel.name != h.name, viewModel.currency == h.defaultCurrency {
            if let updated = await viewModel.saveName(householdId: h.id) {
                updateLocal(updated)
            }
            return
        }
        // Si cambió solo la moneda
        if viewModel.currency != h.defaultCurrency, viewModel.name == h.name {
            if let updated = await viewModel.saveCurrency(householdId: h.id) {
                updateLocal(updated)
            }
            return
        }
        // Si cambió ambos
        if let u1 = await viewModel.saveName(householdId: h.id) {
            updateLocal(u1)
        }
        if let u2 = await viewModel.saveCurrency(householdId: h.id) {
            updateLocal(u2)
        }
    }

    private func updateLocal(_ updated: Household) {
        if let idx = appState.households.firstIndex(where: { $0.id == updated.id }) {
            appState.households[idx] = updated
        }
    }

    @MainActor
    private func deleteHousehold() async {
        guard let hid = appState.currentHouseholdId else { return }
        do {
            try await SupabaseRPC.delete(
                from: "households",
                query: PgQuery().eq("id", hid)
            )
            appState.households.removeAll { $0.id == hid }
            appState.currentHouseholdId = appState.households.first?.id
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
