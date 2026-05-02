import SwiftUI

struct MainTabView: View {
    @State private var selected: Tab = .home
    @State private var showAdd = false
    enum Tab { case home, transactions, budget, settings }

    var body: some View {
        // Midnight Sage tab bar pattern: 4 tabs + FAB circular sage
        // sobresaliente en el centro. Tap al FAB abre AddTransaction como
        // sheet (full screen cover) — patrón premium de apps 2025-2026.
        ZStack(alignment: .bottom) {
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

            // FAB central sobresaliente — sage glow sobre el tab bar.
            // Posicionado absoluto, sobre la línea del tab bar. El tap abre
            // la sheet de AddTransaction (full-screen cover style).
            Button {
                Haptics.play(.impactMedium)
                showAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(hex: "#0E1312"))
                    .frame(width: 58, height: 58)
                    .background(
                        Circle()
                            .fill(Color.brandPrimary)
                            .overlay(
                                Circle().stroke(Color.appBackground, lineWidth: 6)
                            )
                    )
                    .shadow(color: Color.brandPrimary.opacity(0.35), radius: 14, y: 4)
            }
            .buttonStyle(.plain)
            .offset(y: -18)
            .accessibilityLabel(Text("a11y.fab.addTransaction"))
            .accessibilityAddTraits(.isButton)
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
