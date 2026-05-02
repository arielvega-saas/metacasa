import Foundation
import WidgetKit

/// Sincroniza el snapshot financiero al App Group shared que lee el Widget
/// Home Screen.
///
/// **Uso**: desde `HomeViewModel.load(...)` tras refrescar los datos:
/// ```swift
/// await WidgetSnapshotSync.writeLatest(
///     householdName: name,
///     currency: currency,
///     balance: vm.balance,
///     ingresos: vm.totalIngresos,
///     gastos: vm.totalGastos,
///     nextBill: vm.upcomingBills.first
/// )
/// ```
///
/// Si el App Group no está configurado (ej. build actual sin Widget target
/// habilitado), la persistencia falla silenciosamente — no rompe el flujo
/// principal. Cuando se habilita el target, el widget empieza a ver datos
/// automáticamente sin cambiar código en la app.
///
/// El struct `WidgetSnapshot` vive en `MetaCasaWidgets/WidgetSnapshot.swift`
/// y está duplicado acá por ahora para evitar cross-target dependencies
/// hasta que el target esté activo. Cuando se active, mover a un shared
/// framework o copiar path include.
@MainActor
enum WidgetSnapshotSync {
    /// Formatter simple para widget — no respeta `PrivacyManager.obfuscate`
    /// a propósito (el widget siempre muestra los números).
    private static func formatAmount(_ amount: Decimal, currency: String) -> String {
        Money.format(amount, currency: currency, style: .compact)
    }

    /// Escribe el snapshot más reciente al App Group UserDefaults.
    /// Falla silenciosamente si el App Group no existe.
    static func writeLatest(
        householdName: String,
        currency: String,
        balance: Decimal,
        ingresos: Decimal,
        gastos: Decimal,
        nextBill: Bill?
    ) {
        let payload: [String: Any] = [
            "householdName": householdName,
            "currency": currency,
            "balanceMonth": formatAmount(balance, currency: currency),
            "ingresosMonth": formatAmount(ingresos, currency: currency),
            "gastosMonth": formatAmount(gastos, currency: currency),
            "nextBillTitle": nextBill?.title as Any,
            "nextBillAmount": nextBill.map { formatAmount($0.amount, currency: $0.currency) } as Any,
            "nextBillInDays": nextBill?.daysUntilDue as Any,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]

        // Intentamos escribir al App Group. Sin target de widget activo,
        // UserDefaults(suiteName:) retorna nil y skipeamos.
        if let defaults = UserDefaults(suiteName: "group.com.metacasa.shared"),
           let data = try? JSONSerialization.data(withJSONObject: payload) {
            defaults.set(data, forKey: "widget_snapshot_v1")

            // Notificar a WidgetKit que hay data nueva (no-op si no hay widgets).
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
}
