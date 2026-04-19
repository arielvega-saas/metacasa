import SwiftUI

struct MainTabView: View {
    @State private var selected: Tab = .home
    enum Tab { case home, transactions, add, budget, settings }

    var body: some View {
        TabView(selection: $selected) {
            HomeView()
                .tabItem { Label("Inicio", systemImage: "house.fill") }
                .tag(Tab.home)

            TransactionListView()
                .tabItem { Label("Movimientos", systemImage: "list.bullet.rectangle.fill") }
                .tag(Tab.transactions)

            AddTransactionView()
                .tabItem { Label("Agregar", systemImage: "plus.circle.fill") }
                .tag(Tab.add)

            BudgetView()
                .tabItem { Label("Presupuesto", systemImage: "chart.pie.fill") }
                .tag(Tab.budget)

            MoreView()
                .tabItem { Label("Más", systemImage: "ellipsis.circle.fill") }
                .tag(Tab.settings)
        }
        .tint(.brandPrimary)
    }
}

/// Agrupador de pantallas secundarias (Cuentas, Metas, Ajustes, Paywall).
struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Organización") {
                    NavigationLink("Cuentas") { AccountsView() }
                    NavigationLink("Metas") { GoalsView() }
                }
                Section("Premium") {
                    NavigationLink("Upgrade") { PaywallView() }
                }
                Section("App") {
                    NavigationLink("Ajustes") { SettingsView() }
                }
            }
            .navigationTitle("Más")
        }
    }
}
