import XCTest
@testable import Home_Finance

@MainActor
final class AccountBalanceServiceTests: XCTestCase {

    /// Construye una cuenta de prueba con los campos mínimos necesarios.
    private func makeAccount(
        id: UUID = UUID(),
        type: AccountType,
        startingBalance: Decimal,
        isActive: Bool = true
    ) -> Account {
        Account(
            id: id,
            householdId: UUID(),
            name: "Test \(type.rawValue)",
            type: type,
            currency: "USD",
            startingBalance: startingBalance,
            institution: nil,
            accountNumberLast4: nil,
            icon: nil,
            color: nil,
            displayOrder: 0,
            isActive: isActive,
            notes: nil,
            ownership: .personal,
            ownerUserId: nil,
            createdBy: UUID(),
            createdAt: nil,
            updatedAt: nil
        )
    }

    /// Construye una transacción mínima para testear aplicación al balance.
    private func makeTx(
        accountId: UUID?,
        type: TxType,
        amount: Decimal
    ) -> Transaction {
        Transaction(
            id: UUID(),
            householdId: UUID(),
            userId: UUID(),
            accountId: accountId,
            type: type,
            amount: amount,
            amountOriginal: nil,
            currencyOriginal: "USD",
            fxRateToBase: nil,
            fxSource: nil,
            fxStatus: nil,
            category: "Test",
            subcategory: nil,
            account: nil,
            note: nil,
            date: Date(),
            periodYear: nil,
            periodMonth: nil,
            createdAt: nil
        )
    }

    // MARK: - currentBalance

    func testCurrentBalanceNoTransactions() {
        let acc = makeAccount(type: .checking, startingBalance: 1000)
        let balance = AccountBalanceService.currentBalance(
            account: acc,
            transactions: []
        )
        XCTAssertEqual(balance, 1000)
    }

    func testCurrentBalanceExpenseDecreases() {
        let acc = makeAccount(type: .checking, startingBalance: 1000)
        let tx = makeTx(accountId: acc.id, type: .gasto, amount: 300)
        let balance = AccountBalanceService.currentBalance(
            account: acc,
            transactions: [tx]
        )
        XCTAssertEqual(balance, 700)
    }

    func testCurrentBalanceIncomeIncreases() {
        let acc = makeAccount(type: .checking, startingBalance: 1000)
        let tx = makeTx(accountId: acc.id, type: .ingreso, amount: 500)
        let balance = AccountBalanceService.currentBalance(
            account: acc,
            transactions: [tx]
        )
        XCTAssertEqual(balance, 1500)
    }

    func testTransactionForOtherAccountIgnored() {
        let acc = makeAccount(type: .checking, startingBalance: 1000)
        let tx = makeTx(accountId: UUID(), type: .gasto, amount: 500)
        let balance = AccountBalanceService.currentBalance(
            account: acc,
            transactions: [tx]
        )
        XCTAssertEqual(balance, 1000)
    }

    func testTransactionWithNilAccountIdIgnored() {
        let acc = makeAccount(type: .checking, startingBalance: 1000)
        let tx = makeTx(accountId: nil, type: .gasto, amount: 500)
        let balance = AccountBalanceService.currentBalance(
            account: acc,
            transactions: [tx]
        )
        XCTAssertEqual(balance, 1000)
    }

    // MARK: - netWorth

    func testNetWorthSimpleChecking() {
        let acc = makeAccount(type: .checking, startingBalance: 5000)
        let bd = AccountBalanceService.netWorth(
            accounts: [acc],
            transactions: [],
            debts: []
        )
        XCTAssertEqual(bd.assets, 5000)
        XCTAssertEqual(bd.liabilities, 0)
        XCTAssertEqual(bd.netWorth, 5000)
    }

    func testNetWorthCreditCardWithNegativeBalance() {
        let cc = makeAccount(type: .creditCard, startingBalance: 0)
        let txExpense = makeTx(accountId: cc.id, type: .gasto, amount: 1500)
        let bd = AccountBalanceService.netWorth(
            accounts: [cc],
            transactions: [txExpense],
            debts: []
        )
        // CC balance = 0 - 1500 = -1500 → magnitud va a liabilities.
        XCTAssertEqual(bd.assets, 0)
        XCTAssertEqual(bd.liabilities, 1500)
        XCTAssertEqual(bd.netWorth, -1500)
    }

    func testNetWorthInactiveAccountsIgnored() {
        let active = makeAccount(type: .checking, startingBalance: 1000)
        let inactive = makeAccount(type: .checking, startingBalance: 9999, isActive: false)
        let bd = AccountBalanceService.netWorth(
            accounts: [active, inactive],
            transactions: [],
            debts: []
        )
        XCTAssertEqual(bd.assets, 1000)
    }

    func testDebtToAssetRatioHealthy() {
        let acc = makeAccount(type: .savings, startingBalance: 10000)
        let cc = makeAccount(type: .creditCard, startingBalance: 0)
        let ccExp = makeTx(accountId: cc.id, type: .gasto, amount: 1000)
        let bd = AccountBalanceService.netWorth(
            accounts: [acc, cc],
            transactions: [ccExp],
            debts: []
        )
        // assets=10000, liab=1000 → ratio=0.091 (healthy <0.3)
        XCTAssertLessThan(bd.debtToAssetRatio, 0.3)
    }
}
