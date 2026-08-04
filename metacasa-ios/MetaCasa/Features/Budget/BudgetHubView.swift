import SwiftUI
import Observation

/// Hub unificado del tab Presupuesto — paridad UX con la web.
///
/// En vez de separar cascada (WaterfallBudgetView) y editor (BudgetView),
/// esta vista mezcla ambos en una experiencia cohesiva:
/// 1. Header: month picker + ingresos + ready-to-assign
/// 2. Summary: total asignado / gastado / disponible
/// 3. Editor de envelopes inline — cada categoría con progreso + tap para editar
/// 4. Botón "+" prominente para agregar categoría
/// 5. Link a cascada detallada (WaterfallBudget) como opcional
/// 6. Link a configurar % ahorro/inversión
///
/// Reemplaza al antiguo tab "Presupuesto" que mostraba solo WaterfallBudgetView.
@MainActor
@Observable
final class BudgetHubViewModel {
    var period: BudgetPeriod?
    var allocations: [BudgetAllocation] = []
    var envelopes: [EnvelopeWithAllocation] = []
    var ingresosMes: Decimal = 0
    var gastosMes: Decimal = 0
    /// Resumen canónico del período (RPC). Es de dónde sale `readyToAssign`.
    var summary: BudgetPeriodSummary?
    var selectedMonth: Date = Date()

    var isLoading = false
    var errorMessage: String?

    struct EnvelopeWithAllocation: Identifiable {
        let allocation: BudgetAllocation
        let status: EnvelopeStatus
        /// No se pudo determinar el saldo: el sobre está en otra moneda y no hay tasa de cambio.
        ///
        /// `envelope_balance` devuelve NULL en ese caso **a propósito** — es fail-loud deliberado del
        /// SQL. Antes acá se hacía `(try? …) ?? budgeted`, que convertía ese NULL en `spent = 0`:
        /// el "no se puede saber" del backend se transformaba en "no gastaste nada" en pantalla,
        /// anulando justo la protección que el SQL se tomó el trabajo de escribir.
        let balanceUnknown: Bool
        var id: UUID { allocation.id }
    }

    /// Plata asignada **desde el ingreso de ESTE mes**. Sin el arrastre.
    ///
    /// Es lo único que puede restarse de `ingresosMes`: el `rolloverFromPrev` viene fondeado con el
    /// ingreso del mes ANTERIOR, así que descontarlo de nuevo sería cobrarlo dos veces.
    ///
    /// Mientras el rollover valía siempre 0 (nadie lo calculaba, ver la migración
    /// `20260803120000_envelope_rollover.sql`) esta distinción no se notaba y acá se sumaban las dos
    /// cosas. Desde que el trigger de rollover escribe valores reales, sumarlas hace que un sobre
    /// arrastrado — que nace con `allocated = 0` y `rollover > 0` — le baje al usuario el "listo
    /// para asignar" sin que haya asignado nada este mes. La web siempre sumó sólo `allocated`.
    var totalAllocated: Decimal {
        allocations.reduce(Decimal(0)) { $0 + $1.allocated }
    }

    /// Total presupuestado: lo asignado este mes MÁS lo arrastrado. Es la plata que hay
    /// efectivamente en los sobres, y por eso es el número que tiene que cerrar con la suma de las
    /// filas de sobres — no el que alimenta "listo para asignar".
    var totalBudgeted: Decimal {
        allocations.reduce(Decimal(0)) { $0 + $1.allocated + $1.rolloverFromPrev }
    }

    /// Total gastado (suma de spent de cada envelope).
    var totalSpent: Decimal {
        envelopes.reduce(Decimal(0)) { $0 + $1.status.spent }
    }

    /// Disponible para asignar, **según el servidor**.
    ///
    /// Antes se calculaba acá como `ingresosMes - totalAllocated`. El número estaba bien en el
    /// caso simple, pero era una definición más: el Home leía la columna de la DB y esta pantalla
    /// calculaba local, así que el mismo usuario veía "$0 con check verde" en una y "$100.000" en
    /// la otra. Y esta versión no convertía la moneda de los sobres ni contaba los que no tienen
    /// cotización.
    ///
    /// Mientras el RPC no responde cae al cálculo local, que es una aproximación razonable para
    /// no mostrar un 0 falso durante la carga.
    var readyToAssign: Decimal {
        summary?.readyToAssign ?? (ingresosMes - totalAllocated)
    }

    /// Sobres sin cotización: el número de arriba está incompleto y hay que decirlo.
    var fxMissingCount: Int { summary?.fxMissingCount ?? 0 }

    func load(householdId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let p = try await BudgetService.shared.ensurePeriodForMonth(
                householdId: householdId,
                containing: selectedMonth
            )
            self.period = p

            let allocs = try await BudgetService.shared.fetchAllocations(periodId: p.id)
            self.allocations = allocs

            // Totales de ingresos/gastos del mes
            let totals = (try? await TransactionService.shared.totals(
                householdId: householdId,
                from: p.periodStart,
                to: p.periodEnd
            )) ?? (ingresos: 0, gastos: 0)
            self.ingresosMes = totals.ingresos
            self.gastosMes = totals.gastos
            self.summary = try? await BudgetService.shared.periodSummary(periodId: p.id)

            // Calcular envelope status
            var computed: [EnvelopeWithAllocation] = []
            for a in allocs {
                let budgeted = a.allocated + a.rolloverFromPrev
                let remaining = try? await BudgetService.shared.envelopeBalance(
                    periodId: p.id, category: a.category, subcategory: a.subcategory
                )
                // `nil` = el SQL devolvió NULL (sin tasa de cambio) o falló la consulta. En los dos
                // casos el gasto es DESCONOCIDO, no cero. Se marca y la fila lo dice.
                let unknown = remaining == nil
                let spent = unknown ? 0 : budgeted - (remaining ?? 0)
                computed.append(EnvelopeWithAllocation(
                    allocation: a,
                    status: EnvelopeStatus(
                        category: a.category,
                        subcategory: a.subcategory,
                        allocated: budgeted,
                        spent: spent
                    ),
                    balanceUnknown: unknown
                ))
            }
            self.envelopes = computed.sorted { $0.status.percentUsed > $1.status.percentUsed }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upsert(periodId: UUID, category: String, subcategory: String, allocated: Decimal, rolloverMode: RolloverMode, currency: String, householdId: UUID) async {
        do {
            let saved = try await BudgetService.shared.upsertAllocation(
                periodId: periodId,
                category: category,
                subcategory: subcategory,
                allocated: allocated,
                currency: currency
            )
            // Si cambió rollover mode, setearlo
            if saved.rolloverMode != rolloverMode {
                try await BudgetService.shared.updateRolloverMode(allocationId: saved.id, mode: rolloverMode)
            }
            await load(householdId: householdId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(allocationId: UUID, householdId: UUID) async {
        do {
            try await BudgetService.shared.deleteAllocation(id: allocationId)
            await load(householdId: householdId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeMonth(delta: Int) {
        let cal = Calendar.current
        selectedMonth = cal.date(byAdding: .month, value: delta, to: selectedMonth) ?? selectedMonth
    }
}

struct BudgetHubView: View {
    @Environment(AppState.self) private var appState
    @Environment(PrivacyManager.self) private var privacy
    @State private var viewModel = BudgetHubViewModel()
    @State private var editorState: EditorState?
    @State private var showWaterfall = false
    @State private var showStrategy = false

    struct EditorState: Identifiable {
        let id = UUID()
        var existing: BudgetAllocation?  // nil = nuevo
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        summaryTiles
                        envelopesSection
                        actionsSection
                        if let msg = viewModel.errorMessage {
                            Text(msg).font(.mcCaption).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .refreshable { await reload() }
            }
            .navigationTitle(Text("tab.budget"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.play(.selection)
                        showStrategy = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .task { await reload() }
            .sheet(item: $editorState) { state in
                EnvelopeEditorSheet(
                    existing: state.existing,
                    currency: householdCurrency,
                    usedCategories: Set(viewModel.allocations.map { $0.category }),
                    onSave: { cat, sub, amount, rollover in
                        guard let p = viewModel.period, let hid = appState.currentHouseholdId else { return }
                        Task {
                            await viewModel.upsert(
                                periodId: p.id,
                                category: cat,
                                subcategory: sub,
                                allocated: amount,
                                rolloverMode: rollover,
                                currency: householdCurrency,
                                householdId: hid
                            )
                            Haptics.play(.success)
                            editorState = nil
                        }
                    },
                    onDelete: { allocation in
                        guard let hid = appState.currentHouseholdId else { return }
                        Task {
                            await viewModel.delete(allocationId: allocation.id, householdId: hid)
                            Haptics.play(.warning)
                            editorState = nil
                        }
                    }
                )
            }
            .sheet(isPresented: $showWaterfall) {
                WaterfallBudgetView()
            }
            .sheet(isPresented: $showStrategy) {
                PlanEditorView(
                    strategy: currentStrategy,
                    onSave: { newStrategy in
                        Task { await saveStrategy(newStrategy) }
                    }
                )
            }
        }
    }

    private var householdCurrency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private var currentStrategy: HouseholdStrategy {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.strategy ?? .default
    }

    // MARK: - Sections

    private var headerCard: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    Haptics.play(.selection)
                    viewModel.changeMonth(delta: -1)
                    Task { await reload() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.appSurfaceInset)
                        .clipShape(Circle())
                }.buttonStyle(.plain)
                Spacer()
                VStack(spacing: 2) {
                    Text(monthTitle).font(.title3.weight(.bold))
                        .contentTransition(.interpolate)
                    Text("budget.period").font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
                }
                Spacer()
                Button {
                    Haptics.play(.selection)
                    viewModel.changeMonth(delta: 1)
                    Task { await reload() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.appSurfaceInset)
                        .clipShape(Circle())
                }.buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("budget.ready_to_assign").font(.mcLabel).foregroundStyle(Color.textMuted)
                AmountLabel(amount: viewModel.readyToAssign, currency: householdCurrency, kind: .balance)
                    .font(.mcSerifDisplay)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        // Swipe horizontal sobre el header para cambiar de mes. El threshold
        // de 50pt evita disparar sobre micro-gestos. Los chevrons quedan como
        // alternativa accesible.
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -50 {
                        Haptics.play(.selection)
                        viewModel.changeMonth(delta: 1)
                        Task { await reload() }
                    } else if value.translation.width > 50 {
                        Haptics.play(.selection)
                        viewModel.changeMonth(delta: -1)
                        Task { await reload() }
                    }
                }
        )
    }

    private var summaryTiles: some View {
        HStack(spacing: 12) {
            summaryTile(
                icon: "arrow.down.circle.fill",
                labelKey: "budget.income",
                amount: viewModel.ingresosMes,
                kind: .ingreso,
                color: .brandSuccess,
                glow: viewModel.ingresosMes > 0
            )
            summaryTile(
                icon: "dot.arrowtriangles.up.right.down.left.circle",
                labelKey: "budget.assigned",
                amount: viewModel.totalBudgeted,
                kind: .neutro,
                color: .brandPrimary,
                // Asignado glow si gastado está dentro del budget. Premia al
                // usuario por mantenerse en presupuesto.
                glow: viewModel.totalBudgeted > 0 && viewModel.totalSpent <= viewModel.totalBudgeted
            )
            summaryTile(
                icon: "arrow.up.circle.fill",
                labelKey: "budget.spent",
                amount: viewModel.totalSpent,
                kind: .gasto,
                color: .brandDanger,
                // Gastar nunca es "positivo" semánticamente — sin glow.
                glow: false
            )
        }
    }

    private func summaryTile(icon: String, labelKey: LocalizedStringKey, amount: Decimal, kind: AmountLabel.Kind, color: Color, glow: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Text(labelKey).font(.caption2.weight(.bold)).foregroundStyle(Color.textMuted)
            }
            AmountLabel(amount: amount, currency: householdCurrency, kind: kind)
                .font(.mcSerifInline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .top) {
            if glow {
                Capsule()
                    .fill(color)
                    .frame(width: 28, height: 3)
                    .padding(.top, 1)
            }
        }
    }

    @ViewBuilder
    private var envelopesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text("budget.categories").font(.mcH2)
                } icon: {
                    Image(systemName: "tray.2.fill").foregroundStyle(Color.brandPrimary)
                }
                .foregroundStyle(Color.textPrimary)
                Spacer()
                Button {
                    Haptics.play(.impactMedium)
                    editorState = EditorState(existing: nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(hex: "#0E1312"))
                        .frame(width: 36, height: 36)
                        .background(Color.brandPrimary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("budget.addCategory"))
            }

            if viewModel.envelopes.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.envelopes) { env in
                    envelopeRow(env)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            EnvelopesIllustration()
                .frame(width: 140, height: 100)

            VStack(spacing: 6) {
                Text("budget.empty.title")
                    .font(.mcSerifTitle)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                Text("budget.empty.hint")
                    .font(.mcBody)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Button {
                Haptics.play(.impactMedium)
                editorState = EditorState(existing: nil)
            } label: {
                Label("budget.addCategory", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
            }
            .buttonStyle(MCPrimaryButton())
            .frame(maxWidth: 260)
            .padding(.top, 4)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    /// Tres "sobres" apilados en perspectiva — sage, champagne, coral.
    /// Diferencia visual al instante vs el `tray` SF Symbol genérico.
    private struct EnvelopesIllustration: View {
        var body: some View {
            ZStack {
                envelope(.brandSecondary, w: 86, h: 60)
                    .offset(x: -22, y: 8)
                    .rotationEffect(.degrees(-8))
                envelope(.brandDanger, w: 86, h: 60)
                    .offset(x: 22, y: 8)
                    .rotationEffect(.degrees(8))
                envelope(.brandPrimary, w: 92, h: 64)
            }
        }

        private func envelope(_ color: Color, w: CGFloat, h: CGFloat) -> some View {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.22))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(0.6), lineWidth: 1)
                // "Solapa" del sobre
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: w / 2, y: h * 0.45))
                    p.addLine(to: CGPoint(x: w, y: 0))
                }
                .stroke(color.opacity(0.6), lineWidth: 1)
            }
            .frame(width: w, height: h)
        }
    }

    /// Proyección de gasto del envelope dentro del período que está en pantalla.
    ///
    /// Devuelve `nil` si todavía no cargó el período, o si `BudgetPace` decide que proyectar no
    /// aporta (mes futuro, mes cerrado, o muy pocos días transcurridos). Al usar las fechas del
    /// período cargado y no "el mes actual", navegar a un mes pasado deja de mostrar proyecciones
    /// automáticamente, que es lo correcto: ahí el gasto ya es un hecho.
    private func pace(for env: BudgetHubViewModel.EnvelopeWithAllocation) -> BudgetPace? {
        guard let period = viewModel.period else { return nil }
        return env.status.pace(periodStart: period.periodStart, periodEnd: period.periodEnd)
    }

    private func envelopeRow(_ env: BudgetHubViewModel.EnvelopeWithAllocation) -> some View {
        Button {
            Haptics.play(.selection)
            editorState = EditorState(existing: env.allocation)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    // El anillo reemplaza al emoji suelto Y a la barra lineal que estaba debajo:
                    // dos representaciones del mismo porcentaje en la misma fila era ruido.
                    // Con saldo desconocido el anillo va vacío y neutro: pintarlo verde al 0%
                    // sería afirmar "no gastaste nada", que es exactamente lo que no sabemos.
                    BudgetRing(
                        percentUsed: env.balanceUnknown ? 0 : env.status.percentUsed,
                        severity: env.balanceUnknown ? .ok : env.status.severity,
                        pace: env.balanceUnknown ? nil : pace(for: env)
                    ) {
                        Text(CategoryCatalog.emoji(for: env.status.category))
                            .font(.subheadline)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(env.status.category)
                            .font(.mcBody.weight(.bold))
                            .foregroundStyle(Color.textPrimary)
                        if !env.status.subcategory.isEmpty {
                            Text(env.status.subcategory)
                                .font(.caption2)
                                .foregroundStyle(Color.textMuted)
                        }
                        if env.balanceUnknown {
                            Label {
                                Text("budget.balanceUnknown")
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            .font(.caption2)
                            .foregroundStyle(Color.brandWarning)
                        } else {
                            Text("budget.percentUsed \(Int(env.status.percentUsed * 100))")
                                .font(.caption2)
                                .foregroundStyle(env.status.isOverBudget ? Color.brandDanger : Color.textMuted)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("budget.remaining").font(.caption2).foregroundStyle(Color.textMuted)
                        AmountLabel(amount: env.status.remaining, currency: householdCurrency, kind: .balance)
                            .font(.mcSerifInline)
                    }
                }
                // La proyección sólo se muestra si el ritmo se pasa Y el envelope todavía no se pasó:
                // si ya estás por encima del presupuesto, "vas a llegar al 110%" es peor que inútil,
                // porque suena a advertencia futura sobre algo que ya pasó.
                if let pace = pace(for: env), pace.willOverspend, !env.status.isOverBudget {
                    Label {
                        Text("budget.pace.projected \(Int(pace.projectedPercent * 100))")
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.brandDanger)
                }
                HStack {
                    AmountLabel(amount: env.status.spent, currency: householdCurrency, kind: .neutro)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.textMuted)
                    Text("/").font(.caption).foregroundStyle(Color.textDim)
                    AmountLabel(amount: env.status.allocated, currency: householdCurrency, kind: .neutro)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.textMuted)
                    Spacer()
                    if env.allocation.rolloverMode != .none {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                            Text(rolloverLabel(env.allocation.rolloverMode))
                                .font(.caption2)
                        }
                        .foregroundStyle(Color.brandPrimary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.brandPrimary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(14)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.play(.selection)
                showWaterfall = true
            } label: {
                HStack {
                    Image(systemName: "chart.pie.fill")
                    Text("budget.viewCascade")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                Haptics.play(.selection)
                showStrategy = true
            } label: {
                HStack {
                    Image(systemName: "banknote.fill")
                    Text("budget.configStrategy")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = AppLocaleStorage.effectiveLocale
        f.dateFormat = "LLLL yyyy"
        return f.string(from: viewModel.selectedMonth).capitalized
    }

    private func rolloverLabel(_ mode: RolloverMode) -> String {
        switch mode {
        case .none: return ""
        case .surplus: return String(localized: "budget.rollover.surplus")
        case .full: return String(localized: "budget.rollover.full")
        }
    }

    @MainActor
    private func reload() async {
        if let hid = appState.currentHouseholdId {
            await viewModel.load(householdId: hid)
        }
    }

    @MainActor
    private func saveStrategy(_ newStrategy: HouseholdStrategy) async {
        guard let hid = appState.currentHouseholdId else { return }
        do {
            _ = try await HouseholdService.shared.updateStrategy(householdId: hid, strategy: newStrategy)
            try await appState.loadHouseholds()
            Haptics.play(.success)
        } catch {
            viewModel.errorMessage = error.localizedDescription
            Haptics.play(.error)
        }
    }
}

// MARK: - Editor Sheet

struct EnvelopeEditorSheet: View {
    let existing: BudgetAllocation?
    let currency: String
    let usedCategories: Set<String>
    let onSave: (String, String, Decimal, RolloverMode) -> Void
    let onDelete: ((BudgetAllocation) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var category: String
    @State private var subcategory: String
    @State private var amountStr: String
    @State private var rolloverMode: RolloverMode

    init(existing: BudgetAllocation?, currency: String, usedCategories: Set<String>, onSave: @escaping (String, String, Decimal, RolloverMode) -> Void, onDelete: ((BudgetAllocation) -> Void)?) {
        self.existing = existing
        self.currency = currency
        self.usedCategories = usedCategories
        self.onSave = onSave
        self.onDelete = onDelete
        _category = State(initialValue: existing?.category ?? "")
        _subcategory = State(initialValue: existing?.subcategory ?? "")
        _amountStr = State(initialValue: existing.map { "\($0.allocated)" } ?? "")
        _rolloverMode = State(initialValue: existing?.rolloverMode ?? .surplus)
    }

    private var parsedAmount: Decimal? {
        guard let d = CurrencyFormatter.parse(amountStr), d > 0 else { return nil }
        return d
    }

    /// Categorías disponibles en defaults que aún no tienen envelope (para nuevo).
    private var availableCategories: [String] {
        CategoryCatalog.defaultGastos.filter { cat in
            existing?.category == cat || !usedCategories.contains(cat)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("budget.editor.category") {
                    if existing == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableCategories, id: \.self) { cat in
                                    Button {
                                        category = cat
                                        Haptics.play(.selection)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(CategoryCatalog.emoji(for: cat))
                                            Text(cat).font(.caption.weight(.bold))
                                        }
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(category == cat ? Color.brandPrimary : Color.appSurface)
                                        .foregroundStyle(category == cat ? Color.white : Color.textPrimary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        HStack {
                            Text(CategoryCatalog.emoji(for: category)).font(.title3)
                            Text(category).font(.body.weight(.bold))
                        }
                    }
                    TextField("budget.editor.subcategoryOptional", text: $subcategory)
                        .font(.caption)
                }

                Section {
                    HStack {
                        Text(currency)
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(Color.textMuted)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.appSurfaceInset)
                            .clipShape(Capsule())
                        TextField("0", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Color.brandPrimary)
                    }
                    if let amt = parsedAmount {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.brandSuccess)
                            Text("form.amount.preview \(Money.format(amt, currency: currency, style: .auto))")
                                .font(.caption.weight(.semibold))
                                .contentTransition(.numericText())
                        }
                    }
                } header: {
                    Text("budget.editor.assigned")
                } footer: {
                    Text("budget.editor.assignedHint")
                }

                Section {
                    Picker("budget.editor.rollover", selection: $rolloverMode) {
                        ForEach(RolloverMode.allCases, id: \.self) { mode in
                            Text(rolloverKey(mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(rolloverHint(rolloverMode))
                        .font(.caption2)
                        .foregroundStyle(Color.textMuted)
                } header: {
                    Text("budget.editor.rollover")
                }

                if let existing, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete(existing)
                        } label: {
                            Label("budget.editor.delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(Text(existing == nil ? "budget.editor.new" : "budget.editor.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        guard let amount = parsedAmount, !category.isEmpty else { return }
                        onSave(category, subcategory, amount, rolloverMode)
                    }
                    .fontWeight(.semibold)
                    .disabled(category.isEmpty || parsedAmount == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func rolloverKey(_ mode: RolloverMode) -> LocalizedStringKey {
        switch mode {
        case .none:    return "budget.rollover.none"
        case .surplus: return "budget.rollover.surplus"
        case .full:    return "budget.rollover.full"
        }
    }

    private func rolloverHint(_ mode: RolloverMode) -> LocalizedStringKey {
        switch mode {
        case .none:    return "budget.rollover.none.hint"
        case .surplus: return "budget.rollover.surplus.hint"
        case .full:    return "budget.rollover.full.hint"
        }
    }
}
