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

/// Agrupador de pantallas secundarias (Cuentas, Metas, Recurrentes, Miembros, Paywall, Ajustes).
struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Organización") {
                    NavigationLink {
                        AccountsView()
                    } label: {
                        Label("Cuentas", systemImage: "wallet.pass.fill")
                    }
                    NavigationLink {
                        GoalsView()
                    } label: {
                        Label("Metas", systemImage: "target")
                    }
                    NavigationLink {
                        RecurringListView()
                    } label: {
                        Label("Recurrentes", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                Section("Hogar") {
                    NavigationLink {
                        HouseholdSettingsView()
                    } label: {
                        Label("Editar hogar", systemImage: "house.fill")
                    }
                    NavigationLink {
                        HouseholdMembersView()
                    } label: {
                        Label("Miembros e invitaciones", systemImage: "person.3.fill")
                    }
                    NavigationLink {
                        ManageCategoriesView()
                    } label: {
                        Label("Categorías", systemImage: "tag.fill")
                    }
                }
                Section("Premium") {
                    NavigationLink {
                        PaywallView()
                    } label: {
                        Label("Upgrade", systemImage: "crown.fill")
                    }
                }
                Section("App") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Ajustes", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("Más")
        }
    }
}
