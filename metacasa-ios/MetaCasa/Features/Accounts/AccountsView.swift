import SwiftUI

struct AccountsView: View {
    @Environment(AppState.self) private var appState
    @State private var accounts: [Account] = []
    /// Saldo corriente por cuenta (startingBalance + transacciones del último
    /// año), mismo criterio que el net worth del Home.
    @State private var balances: [UUID: Decimal] = [:]
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
                        String(localized: "accounts.empty"),
                        systemImage: "wallet.pass",
                        description: Text("accounts.empty.hint")
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
        .navigationTitle(Text("more.accounts"))
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
            // `.balance`: saldos normales positivos se ven neutros; cuentas
            // con saldo negativo (tarjetas de crédito, préstamos) se renderean
            // en rojo con "-$X" para señalar deuda.
            AmountLabel(
                amount: balances[a.id] ?? a.startingBalance,
                currency: a.currency,
                kind: .balance
            )
            .font(.mcBody.weight(.bold))
        }
        .padding(.vertical, 8)
    }

    private func load() async {
        guard let hid = appState.currentHouseholdId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // Saldo corriente real (no el inicial), calculado server-side por
            // el RPC `account_balances` — mismo criterio que el net worth del
            // Home y sin bajar transacciones al device.
            async let accountsTask = AccountService.shared.fetchAll(householdId: hid)
            async let balancesTask = AccountService.shared.balances(householdId: hid)
            accounts = try await accountsTask
            balances = (try? await balancesTask) ?? [:]
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
