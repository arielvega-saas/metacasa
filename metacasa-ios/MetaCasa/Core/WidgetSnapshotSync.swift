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
        // Usamos el MISMO modelo Codable que lee la extension
        // (`MetaCasaWidgets/WidgetSnapshot.swift`, compilado en ambos targets).
        //
        // Antes se armaba un `[String: Any]` a mano: cuando NO había próximo
        // vencimiento, los `Optional.none as Any` hacían fallar a
        // `JSONSerialization` y el widget se quedaba sin datos para siempre.
        let snapshot = WidgetSnapshot(
            householdName: householdName,
            currency: currency,
            balanceMonth: formatAmount(balance, currency: currency),
            ingresosMonth: formatAmount(ingresos, currency: currency),
            gastosMonth: formatAmount(gastos, currency: currency),
            nextBillTitle: nextBill?.title,
            nextBillAmount: nextBill.map { formatAmount($0.amount, currency: $0.currency) },
            nextBillInDays: nextBill?.daysUntilDue
        )
        snapshot.persist()

        // Notificar a WidgetKit que hay data nueva (no-op si no hay widgets).
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
