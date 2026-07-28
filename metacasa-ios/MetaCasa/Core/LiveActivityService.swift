import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Live Activity para mostrar el próximo vencimiento (bill) en la Lock Screen
/// y la Dynamic Island mientras esté activo.
///
/// Requiere:
/// - iOS 16.1+ (ActivityKit disponible).
/// - `NSSupportsLiveActivities = true` en Info.plist (agregado automáticamente
///   al compilar con el target correcto).
/// - Un Widget Extension target con un `ActivityConfiguration` (deferido —
///   requiere Apple Developer Team ID para App Group real).
///
/// Este archivo expone el **attributes + control API** que la app puede
/// invocar. Cuando el Widget target esté enabled, el Widget extension
/// define el `ActivityConfiguration<BillReminderAttributes>` que renderiza
/// en la Lock Screen y Dynamic Island. Hasta tanto, start/update/end son
/// no-ops silenciosos.
///
/// Integración: `BillService.scheduleBillReminder` o el post-insert de
/// AddBillView pueden llamar `LiveActivityService.startNextBillActivity()`
/// al crear/editar una bill con due date <= 48h.
enum LiveActivityService {

    #if canImport(ActivityKit)
    /// Inicia Live Activity para el próximo bill si hay uno dentro de 48h.
    /// Si ya hay una activa, la actualiza en lugar de crear otra.
    @available(iOS 16.1, *)
    static func startOrUpdateNextBillActivity(bills: [Bill], currency: String) async {
        // No tocar liveactivitiesd si el sistema/usuario no tiene Live
        // Activities habilitadas (iPad en modo compatibilidad, ajustes off).
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        guard let next = bills
            .filter({ $0.status == .pending })
            .sorted(by: { $0.dueDate < $1.dueDate })
            .first,
            next.dueDate.timeIntervalSinceNow < 48 * 3600,
            next.dueDate.timeIntervalSinceNow > -3600
        else {
            // Sin bill cercana → terminar todas las activities activas.
            await endAll()
            return
        }

        let attributes = BillReminderAttributes(billId: next.id.uuidString)
        let state = BillReminderAttributes.ContentState(
            title: next.title,
            amount: next.amount,
            currency: currency,
            dueDate: next.dueDate
        )

        // Si ya hay activity para esta bill, update. Si no, start.
        let existing = Activity<BillReminderAttributes>.activities.first(where: { $0.attributes.billId == attributes.billId })
        if let existing {
            let content = ActivityContent(state: state, staleDate: next.dueDate.addingTimeInterval(3600))
            await existing.update(content)
        } else {
            do {
                let content = ActivityContent(state: state, staleDate: next.dueDate.addingTimeInterval(3600))
                _ = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                // Silent — puede fallar si el user deshabilitó Live Activities
                // en Ajustes o si el Widget target no está linkeado.
                #if DEBUG
                print("[LiveActivity] Failed to start activity: \(error.localizedDescription)")
                #endif
            }
        }
    }

    @available(iOS 16.1, *)
    static func endAll() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for activity in Activity<BillReminderAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
    #else
    /// Fallback para iOS <16.1 o builds sin ActivityKit. No-op.
    static func startOrUpdateNextBillActivity(bills: [Bill], currency: String) async {}
    static func endAll() async {}
    #endif
}

// MARK: - Attributes
//
// `BillReminderAttributes` vive en `MetaCasaWidgets/BillReminderAttributes.swift`
// y se compila en AMBOS targets (app + widget extension). ActivityKit matchea
// la activity con su UI por identidad de tipo, así que la definición tiene que
// ser una sola y compartida. La UI (lock screen + Dynamic Island) está en
// `MetaCasaWidgets/BillReminderLiveActivity.swift`.
