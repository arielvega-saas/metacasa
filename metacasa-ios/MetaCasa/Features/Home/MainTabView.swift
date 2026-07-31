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
    var body: some View {
        NavigationStack {
            List {
                Section("more.section.organization") {
                    NavigationLink {
                        AccountsView()
                    } label: {
                        Label {
                            Text("more.accounts")
                        } icon: {
                            Image(systemName: "wallet.pass.fill")
                        }
                    }
                    NavigationLink {
                        GoalsView()
                    } label: {
                        Label {
                            Text("more.goals")
                        } icon: {
                            Image(systemName: "target")
                        }
                    }
                    NavigationLink {
                        RecurringListView()
                    } label: {
                        Label {
                            Text("more.recurring")
                        } icon: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    NavigationLink {
                        BillsListView()
                    } label: {
                        Label {
                            Text("more.bills")
                        } icon: {
                            Image(systemName: "calendar.badge.exclamationmark")
                        }
                    }
                    NavigationLink {
                        InstallmentsListView()
                    } label: {
                        Label {
                            Text("more.installments")
                        } icon: {
                            Image(systemName: "creditcard.and.123")
                        }
                    }
                    NavigationLink {
                        DebtsListView()
                    } label: {
                        Label {
                            Text("more.debts")
                        } icon: {
                            Image(systemName: "arrow.down.to.line")
                        }
                    }
                    NavigationLink {
                        BudgetView()
                    } label: {
                        Label {
                            Text("more.envelopes")
                        } icon: {
                            Image(systemName: "tray.2.fill")
                        }
                    }
                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label {
                            Text("more.reports")
                        } icon: {
                            Image(systemName: "chart.bar.xaxis")
                        }
                    }
                    NavigationLink {
                        CompareMonthsView()
                    } label: {
                        Label {
                            Text("more.compareMonths")
                        } icon: {
                            Image(systemName: "arrow.left.arrow.right.square")
                        }
                    }
                    NavigationLink {
                        AnnualView()
                    } label: {
                        Label {
                            Text("more.annualView")
                        } icon: {
                            Image(systemName: "calendar")
                        }
                    }
                    NavigationLink {
                        FixedTermCalculatorView()
                    } label: {
                        Label {
                            Text("more.fixedTerm")
                        } icon: {
                            Image(systemName: "percent")
                        }
                    }
                    NavigationLink {
                        CompoundInterestCalculatorView()
                    } label: {
                        Label {
                            Text("more.compoundInterest")
                        } icon: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                        }
                    }
                    NavigationLink {
                        SpendingHeatmapView()
                    } label: {
                        Label {
                            Text("more.heatmap")
                        } icon: {
                            Image(systemName: "square.grid.3x3.square")
                        }
                    }
                }
                Section("more.section.household") {
                    NavigationLink {
                        HouseholdSettingsView()
                    } label: {
                        Label {
                            Text("more.edit_household")
                        } icon: {
                            Image(systemName: "house.fill")
                        }
                    }
                    NavigationLink {
                        HouseholdMembersView()
                    } label: {
                        Label {
                            Text("more.members")
                        } icon: {
                            Image(systemName: "person.3.fill")
                        }
                    }
                    NavigationLink {
                        ManageCategoriesView()
                    } label: {
                        Label {
                            Text("more.categories")
                        } icon: {
                            Image(systemName: "tag.fill")
                        }
                    }
                }
                Section("more.section.premium") {
                    NavigationLink {
                        PaywallView()
                    } label: {
                        Label {
                            Text("more.upgrade")
                        } icon: {
                            Image(systemName: "crown.fill")
                        }
                    }
                }
                Section("more.section.app") {
                    NavigationLink {
                        HelpCenterView()
                    } label: {
                        Label {
                            Text("more.help")
                        } icon: {
                            Image(systemName: "questionmark.circle.fill")
                        }
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label {
                            Text("more.settings")
                        } icon: {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }
            .navigationTitle(Text("tab.more"))
        }
    }
}
