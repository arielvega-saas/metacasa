import XCTest
@testable import Home_Finance

final class CategorySuggesterTests: XCTestCase {

    func testSupermarketKeywordSuggestsAlimentacion() {
        let s = CategorySuggester.suggest(input: "Fui al supermercado", type: .gasto)
        XCTAssertFalse(s.isEmpty)
        XCTAssertEqual(s.first?.category, "Alimentación")
        XCTAssertGreaterThanOrEqual(s.first?.confidence ?? 0, 0.6)
    }

    func testUberKeywordSuggestsTransporte() {
        let s = CategorySuggester.suggest(input: "uber al aeropuerto", type: .gasto)
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(s.contains(where: { $0.category == "Transporte" }))
    }

    func testDiacriticsInsensitive() {
        let s1 = CategorySuggester.suggest(input: "cafe con leche", type: .gasto)
        let s2 = CategorySuggester.suggest(input: "café con leche", type: .gasto)
        XCTAssertEqual(s1.first?.category, s2.first?.category)
    }

    func testCaseInsensitive() {
        let s1 = CategorySuggester.suggest(input: "NETFLIX", type: .gasto)
        let s2 = CategorySuggester.suggest(input: "netflix", type: .gasto)
        XCTAssertEqual(s1.first?.category, s2.first?.category)
        XCTAssertEqual(s1.first?.category, "Entretenimiento")
    }

    func testEmptyInputReturnsNoSuggestions() {
        let s = CategorySuggester.suggest(input: "", type: .gasto)
        XCTAssertTrue(s.isEmpty)
    }

    func testIncomeKeywordSuggestsSueldo() {
        let s = CategorySuggester.suggest(input: "sueldo del mes", type: .ingreso)
        XCTAssertFalse(s.isEmpty)
        XCTAssertEqual(s.first?.category, "Sueldo")
    }

    func testCustomCategoryGetsBoost() {
        let s = CategorySuggester.suggest(
            input: "mercado",
            type: .gasto,
            known: ["Mercado"]
        )
        XCTAssertFalse(s.isEmpty)
        XCTAssertEqual(s.first?.category, "Mercado")
    }

    func testLimitRespected() {
        let s = CategorySuggester.suggest(
            input: "supermercado pizza uber netflix farmacia",
            type: .gasto,
            limit: 3
        )
        XCTAssertLessThanOrEqual(s.count, 3)
    }
}
