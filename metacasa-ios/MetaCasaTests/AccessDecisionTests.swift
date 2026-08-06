import XCTest
@testable import Home_Finance

/// La regla de acceso.
///
/// Existen porque el gate miraba **sólo** el trial local y StoreKit. StoreKit conoce
/// únicamente las compras hechas en ESE Apple ID, así que una suscripción comprada
/// desde la web o desde Android no aparecía y la app bloqueaba igual: cobrar y no dar
/// acceso. Se descubrió con la cuenta del propio dueño, que tenía `premium` activo en
/// `user_entitlements` desde hacía dos meses y aun así veía el paywall.
@MainActor
final class AccessDecisionTests: XCTestCase {

    private func decidir(trial: Bool = false, storeKit: Bool = false, servidor: Bool = false)
        -> AccessController.State
    {
        AccessController.decide(
            inTrial: trial, storeKitSubscribed: storeKit, serverEntitled: servidor
        )
    }

    func testSinNingunaViaSeBloquea() {
        XCTAssertEqual(decidir(), .locked)
    }

    func testElTrialVigenteAlcanza() {
        XCTAssertEqual(decidir(trial: true), .granted)
    }

    func testLaCompraEnStoreKitAlcanza() {
        XCTAssertEqual(decidir(storeKit: true), .granted)
    }

    /// El caso que motivó el arreglo: compró en la web o en Android.
    func testElEntitlementDelServidorSoloAlcanza() {
        XCTAssertEqual(decidir(servidor: true), .granted)
    }

    /// Ninguna vía puede CERRAR lo que otra abrió. Si StoreKit no contesta —sin red, o
    /// Apple throttleando— el suscriptor de la web tiene que seguir entrando.
    func testUnaViaEnFalseNoPisaALasQueDicenSi() {
        XCTAssertEqual(decidir(trial: true, storeKit: false, servidor: false), .granted)
        XCTAssertEqual(decidir(trial: false, storeKit: true, servidor: false), .granted)
        XCTAssertEqual(decidir(trial: false, storeKit: false, servidor: true), .granted)
    }

    func testTodasLasViasJuntasSigueSiendoGranted() {
        XCTAssertEqual(decidir(trial: true, storeKit: true, servidor: true), .granted)
    }
}
