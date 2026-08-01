import XCTest
import LocalAuthentication
@testable import Home_Finance

/// Tests de la decisión de fail-open del app lock.
///
/// Esta es la única regla que separa "la app está protegida" de "la app parece protegida". Estaba
/// invertida: un `default:` abría ante cualquier error que no fuera cancelación, así que fallar la
/// autenticación a propósito ABRÍA la app. Los tests existen para que no vuelva a invertirse.
final class BiometricLockManagerTests: XCTestCase {

    /// Lo que motivó el fix: fallar la autenticación NO puede abrir la app.
    func testFallarLaAutenticacionMantieneElLock() {
        XCTAssertFalse(BiometricLockManager.shouldFailOpen(.authenticationFailed),
                       "fallar Face ID o el passcode debe dejar la app BLOQUEADA")
    }

    func testLockoutDeBiometriaMantieneElLock() {
        // Demasiados intentos fallidos. Es la señal más fuerte de que alguien está probando.
        XCTAssertFalse(BiometricLockManager.shouldFailOpen(.biometryLockout))
    }

    func testCancelacionesMantienenElLock() {
        XCTAssertFalse(BiometricLockManager.shouldFailOpen(.userCancel))
        XCTAssertFalse(BiometricLockManager.shouldFailOpen(.appCancel))
        XCTAssertFalse(BiometricLockManager.shouldFailOpen(.systemCancel))
        XCTAssertFalse(BiometricLockManager.shouldFailOpen(.userFallback))
    }

    func testContextoInvalidoMantieneElLock() {
        XCTAssertFalse(BiometricLockManager.shouldFailOpen(.invalidContext))
        XCTAssertFalse(BiometricLockManager.shouldFailOpen(.notInteractive))
    }

    /// El fail-open sigue existiendo, pero sólo donde el device no puede autenticar de ninguna
    /// forma: dejarlo cerrado ahí encerraría al dueño afuera de sus propios datos, sin salida.
    func testSinPasscodeAbre() {
        XCTAssertTrue(BiometricLockManager.shouldFailOpen(.passcodeNotSet))
    }

    func testBiometriaNoDisponibleOSinEnrolarAbre() {
        XCTAssertTrue(BiometricLockManager.shouldFailOpen(.biometryNotAvailable))
        XCTAssertTrue(BiometricLockManager.shouldFailOpen(.biometryNotEnrolled))
    }

    /// Ante un código nuevo o desconocido, el default seguro es NO abrir.
    /// Si Apple agrega un caso, que falle cerrado y no que regale acceso.
    func testCodigoDesconocidoNoAbre() {
        XCTAssertFalse(BiometricLockManager.shouldFailOpen(LAError.Code(rawValue: -99) ?? .invalidContext))
    }
}
