import XCTest
import SwiftUI
@testable import Home_Finance

/// Verifica que las claves interpoladas **se encuentren realmente** en el catálogo.
///
/// El bug que motiva estos tests: 16 pantallas mostraban el identificador crudo —"home.streak 5"
/// en el badge de racha del Home, "installments.progress 2 12" en el detalle de cuotas— en los
/// **tres** idiomas, español incluido.
///
/// La causa no era una traducción faltante sino un desfase de clave. `Text("home.streak \(streak)")`
/// con `streak: Int` busca en tiempo de ejecución `home.streak %lld`, pero en el catálogo estaba
/// escrita `home.streak %@`. Al no encontrarla, iOS hace lo único que puede: muestra la clave.
/// Sin crash, sin warning, sin fallar el build.
///
/// Por eso estos tests parten de la **misma interpolación que usa la vista** y le sacan la clave con
/// `Mirror`, en vez de comparar contra la cadena escrita en el `.xcstrings`. Un test sobre el
/// catálogo solo habría dicho "la clave existe y está traducida" — que era cierto, y aun así el
/// usuario veía el identificador.
final class LocalizationKeyResolutionTests: XCTestCase {

    /// La clave que `LocalizedStringKey` va a buscar en tiempo de ejecución.
    private func runtimeKey(_ k: LocalizedStringKey) -> String {
        let hijo = Mirror(reflecting: k).children.first { $0.label == "key" }
        return hijo?.value as? String ?? "<sin clave>"
    }

    /// El bundle de la **app**, no el de tests: los `.lproj` compilados del catálogo viven en el
    /// `.app`, y `Bundle(for: <clase de tests>)` apunta al `.xctest`, que no tiene ninguno.
    private static let bundle = Bundle(for: PrivacyManager.self)

    /// Falla si la clave no está en el catálogo, o si su valor es la clave misma.
    private func assertResuelve(
        _ k: LocalizedStringKey,
        _ idiomas: [String] = ["es", "en", "pt-BR"],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let clave = runtimeKey(k)
        for idioma in idiomas {
            guard let ruta = Self.bundle.path(forResource: idioma, ofType: "lproj"),
                  let lproj = Bundle(path: ruta) else {
                XCTFail("falta el .lproj de \(idioma) en el bundle", file: file, line: line)
                continue
            }
            // El centinela distingue "no existe" de "existe y vale la clave".
            let valor = lproj.localizedString(forKey: clave, value: "␀", table: nil)
            XCTAssertNotEqual(valor, "␀",
                "[\(idioma)] la clave «\(clave)» no existe en el catálogo — la pantalla va a mostrar el identificador crudo",
                file: file, line: line)
            XCTAssertNotEqual(valor, clave,
                "[\(idioma)] «\(clave)» resuelve a sí misma — el usuario ve el identificador",
                file: file, line: line)
        }
    }

    // MARK: - Las 16 que estaban rotas

    /// Un `Int` interpolado produce `%lld`, no `%@`. Ésta es la trampa que rompió las 16.
    func testInterpolarUnIntProduceLLD() {
        XCTAssertEqual(runtimeKey("home.streak \(5)"), "home.streak %lld")
        XCTAssertEqual(runtimeKey("installments.progress \(2) \(12)"), "installments.progress %lld %lld")
        let periodo = "08/2026"
        XCTAssertEqual(runtimeKey("installments.detail.month \(3) \(periodo)"), "installments.detail.month %lld %@")
    }

    func testHomeStreak()            { assertResuelve("home.streak \(5)") }
    func testBillsDaysIn()           { assertResuelve("bills.days.in \(3)") }
    func testBillsDaysOverdue()      { assertResuelve("bills.days.overdue \(2)") }
    func testDebtsDaysLeft()         { assertResuelve("debts.detail.daysLeft \(9)") }
    func testDebtsRowMonths()        { assertResuelve("debts.row.months \(18)") }
    func testGoalPriority()          { assertResuelve("form.priority.format \(3)") }
    func testBackupSkipped()         { assertResuelve("backup.report.skipped \(4)") }
    func testImportCommit()          { assertResuelve("import.commit \(120)") }
    func testImportSuccessCount()    { assertResuelve("import.success.count \(120)") }
    func testInstallmentsFormCount() { assertResuelve("installments.form.count \(12)") }
    func testNotifBillsDaysBefore()  { assertResuelve("notif.bills.daysBeforeValue \(3)") }
    func testNotifGoalsDayOfMonth()  { assertResuelve("notif.goals.dayOfMonthValue \(15)") }
    func testNotifGoalsTimingHint()  { assertResuelve("notif.goals.timingHint \(15)") }
    func testInstallmentsProgress()  { assertResuelve("installments.progress \(2) \(12)") }

    func testInstallmentsDetailMonth() {
        assertResuelve("installments.detail.month \(3) \(String(format: "%02d/%d", 8, 2026))")
    }

    func testNotifBillsTimingHint() {
        assertResuelve("notif.bills.timingHint \(3) \(String(format: "%02d:00", 9))")
    }

    // MARK: - Singular y plural

    /// Las claves con `Int` llevan variaciones de plural: si alguien las reemplaza por una cadena
    /// simple, "1 días seguidos" pasa desapercibido en QA porque casi siempre se prueba con N>1.
    func testElSingularNoDiceDias() {
        guard let ruta = Self.bundle.path(forResource: "es", ofType: "lproj"),
              let es = Bundle(path: ruta) else { return XCTFail("falta es.lproj") }
        let uno = String(format: es.localizedString(forKey: "home.streak %lld", value: nil, table: nil), 1)
        let varios = String(format: es.localizedString(forKey: "home.streak %lld", value: nil, table: nil), 5)
        XCTAssertTrue(uno.contains("día seguido"), "el singular debería decir «1 día seguido», dice «\(uno)»")
        XCTAssertTrue(varios.contains("días seguidos"), "el plural debería decir «5 días seguidos», dice «\(varios)»")
    }
}
