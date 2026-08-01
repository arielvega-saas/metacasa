import SwiftUI

struct MainTabView: View {
    @State private var selected: Tab = .home
    @State private var lastNonAddTab: Tab = .home
    @State private var showAdd = false
    enum Tab: Hashable { case home, transactions, add, budget, settings }

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabs
            } else {
                legacyTabs
            }
        }
        .tint(.brandPrimary)
        // Aviso "estás viendo datos guardados": va sobre el TabView para cubrir
        // todas las pantallas (incluidas las push) con una sola aplicación.
        .offlineDataBanner()
        .onChange(of: selected) { _, new in
            if new == .add {
                Haptics.play(.impactMedium)
                showAdd = true
                selected = lastNonAddTab
            } else {
                lastNonAddTab = new
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTransactionView()
        }
    }

    /// Tab API declarativa de iOS 18+ (Fase 4.11 del `PLAN_NIVEL_PRO.md`).
    ///
    /// Además de ser la API vigente, `.sidebarAdaptable` es lo que hace que la misma declaración
    /// se dibuje como tab bar en iPhone y como **sidebar en iPad**, sin escribir un
    /// `NavigationSplitView` a mano ni duplicar la jerarquía. Hoy el target sigue siendo iPhone-only
    /// (`TARGETED_DEVICE_FAMILY: "1"` en `project.yml`), así que en la práctica se ve como siempre;
    /// habilitar iPad pasa a ser cambiar ese flag + subir screenshots de iPad a App Store Connect.
    @available(iOS 18.0, *)
    private var modernTabs: some View {
        TabView(selection: $selected) {
            SwiftUI.Tab(value: Tab.home) {
                HomeView()
            } label: {
                Label { Text("tab.home") } icon: { Image(systemName: "house.fill") }
            }

            SwiftUI.Tab(value: Tab.transactions) {
                TransactionListView()
            } label: {
                Label { Text("tab.transactions") } icon: { Image(systemName: "list.bullet.rectangle.fill") }
            }

            // Pseudo-tab: no muestra contenido, dispara el alta y vuelve al tab anterior
            // (ver el `onChange` de arriba). Se mantiene el mismo truco que en la versión legacy.
            SwiftUI.Tab(value: Tab.add) {
                Color.clear
            } label: {
                Label { Text("tab.add") } icon: { Image(systemName: "plus.circle.fill") }
            }
            .accessibilityLabel(Text("a11y.fab.addTransaction"))

            SwiftUI.Tab(value: Tab.budget) {
                BudgetHubView()
            } label: {
                Label { Text("tab.budget") } icon: { Image(systemName: "chart.pie.fill") }
            }

            SwiftUI.Tab(value: Tab.settings) {
                MoreView()
            } label: {
                Label { Text("tab.more") } icon: { Image(systemName: "ellipsis.circle.fill") }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    /// Camino para iOS 17, que sigue siendo el deployment target.
    private var legacyTabs: some View {
        TabView(selection: $selected) {
            HomeView()
                .tabItem {
                    Label {
                        Text("tab.home")
                    } icon: {
                        Image(systemName: "house.fill")
                    }
                }
                .tag(Tab.home)

            TransactionListView()
                .tabItem {
                    Label {
                        Text("tab.transactions")
                    } icon: {
                        Image(systemName: "list.bullet.rectangle.fill")
                    }
                }
                .tag(Tab.transactions)

            Color.clear
                .tabItem {
                    Label {
                        Text("tab.add")
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .tag(Tab.add)
                .accessibilityLabel(Text("a11y.fab.addTransaction"))

            BudgetHubView()
                .tabItem {
                    Label {
                        Text("tab.budget")
                    } icon: {
                        Image(systemName: "chart.pie.fill")
                    }
                }
                .tag(Tab.budget)

            MoreView()
                .tabItem {
                    Label {
                        Text("tab.more")
                    } icon: {
                        Image(systemName: "ellipsis.circle.fill")
                    }
                }
                .tag(Tab.settings)
        }
    }
}

/// Agrupador de pantallas secundarias (Cuentas, Metas, Recurrentes, Miembros, Paywall, Ajustes).
struct MoreView: View {

    /// Fila de navegación del menú.
    ///
    /// Existe para que agregar una pantalla sea una línea y no siete: la forma
    /// `NavigationLink { } label: { Label { Text } icon: { Image } }` se repetía 19 veces idéntica y
    /// enterraba la estructura del menú debajo del boilerplate. La clave se pasa como
    /// `LocalizedStringKey` para que el String Catalog la siga extrayendo igual.
    @ViewBuilder
    private func moreLink<Destination: View>(
        _ titleKey: LocalizedStringKey,
        _ systemImage: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Label {
                Text(titleKey)
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Antes: UNA sección "Organización" con 13 pantallas seguidas. Media app quedaba
                // escondida en una pared de texto que nadie escanea. Ahora se agrupa por el modelo
                // mental del usuario — qué tengo / qué debo / cómo me fue / con qué calculo — que es
                // como agrupan Monarch y YNAB. El orden dentro de cada grupo va de lo más usado a lo
                // menos usado, no alfabético.
                Section("more.section.money") {
                    moreLink("more.accounts", "wallet.pass.fill") { AccountsView() }
                    moreLink("more.envelopes", "tray.2.fill") { BudgetView() }
                    moreLink("more.goals", "target") { GoalsView() }
                }

                Section("more.section.commitments") {
                    moreLink("more.bills", "calendar.badge.exclamationmark") { BillsListView() }
                    moreLink("more.recurring", "arrow.triangle.2.circlepath") { RecurringListView() }
                    moreLink("more.installments", "creditcard.and.123") { InstallmentsListView() }
                    moreLink("more.debts", "arrow.down.to.line") { DebtsListView() }
                }

                Section("more.section.analysis") {
                    moreLink("more.reports", "chart.bar.xaxis") { ReportsView() }
                    moreLink("more.compareMonths", "arrow.left.arrow.right.square") { CompareMonthsView() }
                    moreLink("more.annualView", "calendar") { AnnualView() }
                    moreLink("more.heatmap", "square.grid.3x3.square") { SpendingHeatmapView() }
                }

                Section("more.section.tools") {
                    moreLink("more.fixedTerm", "percent") { FixedTermCalculatorView() }
                    moreLink("more.compoundInterest", "chart.line.uptrend.xyaxis") { CompoundInterestCalculatorView() }
                }

                Section("more.section.household") {
                    moreLink("more.edit_household", "house.fill") { HouseholdSettingsView() }
                    moreLink("more.members", "person.3.fill") { HouseholdMembersView() }
                    moreLink("more.categories", "tag.fill") { ManageCategoriesView() }
                }

                Section("more.section.premium") {
                    moreLink("more.upgrade", "crown.fill") { PaywallView() }
                }

                Section("more.section.app") {
                    moreLink("more.help", "questionmark.circle.fill") { HelpCenterView() }
                    moreLink("more.settings", "gearshape.fill") { SettingsView() }
                }
            }
            .navigationTitle(Text("tab.more"))
        }
    }
}
