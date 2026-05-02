import Foundation

/// Motor de cálculo del presupuesto **Waterfall** (cascada) multi-persona.
///
/// Port de la lógica del web (App.jsx:6245-6307):
///
/// ```
/// Ingresos del hogar (suma de INGRESO de todas las cuentas)
///   −  Gastos fijos mensuales (recurring_transactions tipo GASTO frequency=monthly)
///   −  Vencimientos (bills pendientes del mes) [opcional]
///   −  Cuotas (installment_payments del mes) [opcional]
///   −  Pagos de deuda (debts.monthly_payment de deudas activas) [opcional]
///   −  Presupuesto de categorías compartidas (allocations en shared accounts)
///   −  % Ahorro (sobre el sub-total pre-distribución)
///   −  % Inversión (sobre el sub-total pre-distribución)
///   = Remanente
///
/// Remanente → distribuido entre cuentas PERSONALES según `distributionMode`:
///   - equal: remanente ÷ N cuentas personales
///   - proportional: cada cuenta recibe según su proporción de ingreso
///   - custom: cada cuenta recibe el monto definido manualmente
/// ```
struct WaterfallCalculator {
    // Inputs
    let transactions: [Transaction]           // txs del período
    let accounts: [Account]
    let fixedExpenses: [RecurringTransaction] // recurring monthly GASTO activos
    let bills: [Bill]                         // vencimientos del mes
    let installmentPayments: [(plan: InstallmentPlan, payment: InstallmentPayment)]
    let debts: [Debt]
    let sharedAllocations: [BudgetAllocation] // allocations de cuentas shared
    let strategy: HouseholdStrategy

    // MARK: - Result

    struct Result {
        let totalIncome: Decimal
        let fixedDeduction: Decimal
        let billsDeduction: Decimal
        let installmentsDeduction: Decimal
        let debtPaymentsDeduction: Decimal
        let sharedBudgetsDeduction: Decimal
        let savingsAllocation: Decimal
        let investmentAllocation: Decimal
        let remainder: Decimal
        let distribution: [AccountAllocation]
    }

    struct AccountAllocation: Identifiable {
        let id: UUID              // accountId
        let account: Account
        let amount: Decimal
        let incomeSource: Decimal // si modo proporcional, el ingreso desde esa cuenta
    }

    // MARK: - Computation

    /// Ejecuta la cascada completa y devuelve el resultado.
    func calculate() -> Result {
        let income = totalIncome()
        let fixed = fixedDeduction()
        let billsDed = strategy.includeBillsInWaterfall ? billsDeduction() : 0
        let instDed = strategy.includeInstallmentsInWaterfall ? installmentsDeduction() : 0
        let debtDed = strategy.includeDebtPaymentsInWaterfall ? debtPaymentsDeduction() : 0
        let sharedDed = sharedBudgetsDeduction()

        let beforePct = income - fixed - billsDed - instDed - debtDed - sharedDed
        let savings = beforePct * strategy.savingsPct / 100
        let investment = beforePct * strategy.investmentPct / 100
        let remainder = beforePct - savings - investment

        let dist = distribute(remainder: remainder)

        return Result(
            totalIncome: income,
            fixedDeduction: fixed,
            billsDeduction: billsDed,
            installmentsDeduction: instDed,
            debtPaymentsDeduction: debtDed,
            sharedBudgetsDeduction: sharedDed,
            savingsAllocation: savings,
            investmentAllocation: investment,
            remainder: remainder,
            distribution: dist
        )
    }

    // MARK: - Individual computations

    private func totalIncome() -> Decimal {
        transactions
            .filter { $0.type == .ingreso }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func fixedDeduction() -> Decimal {
        fixedExpenses
            .filter { $0.active && $0.type == .gasto && $0.frequency == .monthly }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func billsDeduction() -> Decimal {
        bills
            .filter { $0.status == .pending }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func installmentsDeduction() -> Decimal {
        installmentPayments
            .filter { !$0.payment.paid }
            .reduce(Decimal(0)) { $0 + $1.payment.amount }
    }

    private func debtPaymentsDeduction() -> Decimal {
        debts
            .filter { $0.status == .active }
            .compactMap { $0.monthlyPayment }
            .reduce(Decimal(0), +)
    }

    private func sharedBudgetsDeduction() -> Decimal {
        sharedAllocations.reduce(Decimal(0)) { $0 + $1.allocated }
    }

    /// Distribuye el remanente entre las cuentas personales según `distributionMode`.
    private func distribute(remainder: Decimal) -> [AccountAllocation] {
        let personal = accounts.filter { $0.ownership == .personal && $0.isActive }
        guard !personal.isEmpty else { return [] }

        switch strategy.distributionMode {
        case .equal:
            let perAccount = remainder / Decimal(personal.count)
            return personal.map { AccountAllocation(id: $0.id, account: $0, amount: perAccount, incomeSource: 0) }

        case .proportional:
            // Calcular ingreso desde cada cuenta personal
            var incomeByAccount: [UUID: Decimal] = [:]
            for tx in transactions where tx.type == .ingreso {
                guard let aid = tx.accountId else { continue }
                incomeByAccount[aid, default: 0] += tx.amount
            }
            let totalPersonalIncome = personal.reduce(Decimal(0)) { sum, acc in
                sum + (incomeByAccount[acc.id] ?? 0)
            }
            if totalPersonalIncome == 0 {
                // Fallback a equal si no hay ingresos identificados por cuenta
                let perAccount = remainder / Decimal(personal.count)
                return personal.map { AccountAllocation(id: $0.id, account: $0, amount: perAccount, incomeSource: 0) }
            }
            return personal.map { acc in
                let accIncome = incomeByAccount[acc.id] ?? 0
                let share = remainder * accIncome / totalPersonalIncome
                return AccountAllocation(id: acc.id, account: acc, amount: share, incomeSource: accIncome)
            }

        case .custom:
            return personal.map { acc in
                let custom = strategy.customAllocations[acc.id.uuidString] ?? 0
                return AccountAllocation(id: acc.id, account: acc, amount: custom, incomeSource: 0)
            }
        }
    }
}
