import SwiftUI

struct AccountsView: View {
    @Environment(AppState.self) private var appState
    @State private var accounts: [Account] = []
    @State private var isLoading = true
    @State private var showAdd = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else if accounts.isEmpty {
                    ContentUnavailableView(
                        "Sin cuentas",
                        systemImage: "wallet.pass",
                        description: Text("Creá una para empezar a organizar tus saldos")
                    )
                } else {
                    List {
                        ForEach(accounts) { a in
                            NavigationLink(destination: destination(for: a)) {
                                accountRow(a)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Cuentas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAccountView { await load() }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func destination(for account: Account) -> some View {
        if account.type == .creditCard {
            CreditCardDetailView(account: account)
        } else {
            Text(account.name)
                .font(.mcH2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
        }
    }

    private func accountRow(_ a: Account) -> some View {
        HStack(spacing: 14) {
            Image(systemName: a.type.systemIcon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 44, height: 44)
                .background(Color.brandPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(a.name).font(.mcBody.weight(.bold)).foregroundStyle(Color.textPrimary)
                Text(a.type.label).font(.mcCaption).foregroundStyle(Color.textMuted)
            }
            Spacer()
            Text(CurrencyFormatter.format(a.startingBalance, currency: a.currency))
                .font(.mcBody.weight(.bold))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.vertical, 8)
    }

    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            accounts = try await AccountService.shared.fetchAll(householdId: hid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
