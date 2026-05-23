import SwiftUI

struct MainTabView: View {
    @State private var selected: Tab = .home
    @State private var lastNonAddTab: Tab = .home
    @State private var showAdd = false
    enum Tab: Hashable { case home, transactions, add, budget, settings }

    var body: some View {
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
        .tint(.brandPrimary)
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
