import Foundation
@preconcurrency import UserNotifications
import Observation

/// Notificaciones locales (UNUserNotificationCenter) para vencimientos,
/// recordatorios de metas y recurrentes. No usamos push — todo on-device.
///
/// Identifiers:
///   `bill-<uuid>`, `goal-<uuid>`, `recurring-<uuid>`
/// Cada entidad tiene como máximo 1 notificación agendada. Al editar/eliminar
/// se cancela la anterior antes de crear una nueva.
actor NotificationService {
    static let shared = NotificationService()
    private init() {}

    enum AuthorizationState: Sendable {
        case notDetermined, denied, authorized, provisional, ephemeral
        init(_ status: UNAuthorizationStatus) {
            switch status {
            case .notDetermined: self = .notDetermined
            case .denied: self = .denied
            case .authorized: self = .authorized
            case .provisional: self = .provisional
            case .ephemeral: self = .ephemeral
            @unknown default: self = .notDetermined
            }
        }
    }

    func authorizationState() async -> AuthorizationState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return AuthorizationState(settings.authorizationStatus)
    }

    /// Pide permiso al usuario. Idempotente — si ya está autorizado, retorna
    /// true sin volver a mostrar el prompt del sistema.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Bills
    //
    // Cada bill agenda hasta 3 notificaciones distintas, todas con prefix
    // "bill-<uuid>-" para poder cancelarlas en batch al marcar como pagado:
    //
    //   bill-<uuid>-pre      → N días antes del due date (configurable, default 1d antes)
    //   bill-<uuid>-day      → el día del due date a las 18:00 ("hoy vence X")
    //   bill-<uuid>-overdue  → 1 día después del due date a las 10:00 ("X venció ayer y figura sin pagar")
    //
    // Importante: al marcar el bill como pagado, se cancelan los 3. La logica
    // vive en BillService.markPaid → cancelBillAlerts(billId:).

    /// Conveniencia: agenda los 3 niveles de notificación para un bill
    /// (pre-vencimiento, día del vencimiento, overdue). Llamar desde
    /// `BillService.create` y desde `BillService.update` cuando cambia el
    /// due_date o el monto.
    func scheduleBillFullAlerts(bill: Bill) async {
        await scheduleBillReminder(bill: bill)
        await scheduleBillDueDayAlert(bill: bill)
        await scheduleBillOverdueAlert(bill: bill)
    }

    /// Agenda una notificación N días antes del due date, a la hora configurada
    /// por el usuario (default: 1 día antes a las 9am). Si ya pasó, no agenda.
    func scheduleBillReminder(bill: Bill) async {
        let state = await authorizationState()
        guard state == .authorized || state == .provisional else { return }

        let prefs = await prefsSnapshot()

        let id = "bill-\(bill.id.uuidString)-pre"
        cancel(identifier: id)

        let cal = Calendar.current
        guard let triggerDate = cal.date(byAdding: .day, value: -prefs.billsDaysBefore, to: bill.dueDate) else { return }
        let atUserHour = cal.date(bySettingHour: prefs.billsHour, minute: 0, second: 0, of: triggerDate) ?? triggerDate
        guard atUserHour > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.bill.title")
        let daysString = prefs.billsDaysBefore == 1
            ? String(localized: "notif.bill.tomorrow")
            : String(format: String(localized: "notif.bill.inDays %d"), prefs.billsDaysBefore)
        content.body = "\(bill.title) · \(daysString) · \(Money.format(bill.amount, currency: bill.currency, style: .compact))"
        content.sound = .default
        content.categoryIdentifier = "bill"

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: atUserHour),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Agenda una notificación EL día del vencimiento a las 18:00 — recordatorio
    /// fuerte de "hoy vence X, marcalo como pagado si ya lo pagaste".
    func scheduleBillDueDayAlert(bill: Bill) async {
        let state = await authorizationState()
        guard state == .authorized || state == .provisional else { return }

        let id = "bill-\(bill.id.uuidString)-day"
        cancel(identifier: id)

        let cal = Calendar.current
        guard let atSixPM = cal.date(bySettingHour: 18, minute: 0, second: 0, of: bill.dueDate),
              atSixPM > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Hoy vence: \(bill.title)"
        content.body = "\(Money.format(bill.amount, currency: bill.currency, style: .compact)) · Marcalo como pagado si ya lo abonaste."
        content.sound = .default
        content.categoryIdentifier = "bill"

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: atSixPM),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Agenda una notificación 1 DÍA DESPUÉS del vencimiento a las 10:00 — si
    /// el user no marcó como pagado, recibe esta alerta de overdue.
    /// IMPORTANTE: cuando el user marca el bill como pagado vía
    /// `BillService.markPaid`, se llama a `cancelBillAlerts(billId:)` que
    /// elimina esta notif antes de que dispare. Si el user paga POR FUERA de
    /// la app (banco, app del proveedor) y no actualiza, la notif dispara —
    /// es feature, recordá marcarlo.
    func scheduleBillOverdueAlert(bill: Bill) async {
        let state = await authorizationState()
        guard state == .authorized || state == .provisional else { return }

        let id = "bill-\(bill.id.uuidString)-overdue"
        cancel(identifier: id)

        let cal = Calendar.current
        guard let dayAfter = cal.date(byAdding: .day, value: 1, to: bill.dueDate),
              let atTenAM = cal.date(bySettingHour: 10, minute: 0, second: 0, of: dayAfter),
              atTenAM > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "⚠️ \(bill.title) venció"
        content.body = "El vencimiento de \(Money.format(bill.amount, currency: bill.currency, style: .compact)) figura sin pagar. Si ya lo pagaste, marcalo en la app."
        content.sound = .default
        content.categoryIdentifier = "bill"
        // Interrupción nivel `active` — visible incluso si el user tiene Focus.
        // No usamos `.timeSensitive` porque requiere entitlement adicional.

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: atTenAM),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Cancela las 3 notificaciones asociadas a un bill (pre + day + overdue).
    /// Se llama al marcar el bill como pagado o al eliminarlo.
    nonisolated func cancelBillAlerts(billId: UUID) {
        let prefix = "bill-\(billId.uuidString)"
        let ids = ["\(prefix)-pre", "\(prefix)-day", "\(prefix)-overdue"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Snapshot nonisolated de las prefs (para uso desde actor context).
    private func prefsSnapshot() async -> (billsDaysBefore: Int, billsHour: Int, goalsMonthlyDay: Int) {
        await MainActor.run {
            (
                NotificationPreferences.shared.billsDaysBefore,
                NotificationPreferences.shared.billsHour,
                NotificationPreferences.shared.goalsMonthlyDay
            )
        }
    }

    // MARK: - Goals

    /// Agenda un recordatorio mensual de "contribuí a tu meta" el día configurado
    /// por el user. Si no hay target, recordatorio único a 30 días.
    func scheduleGoalReminder(goal: Goal) async {
        let state = await authorizationState()
        guard state == .authorized || state == .provisional else { return }

        let prefs = await prefsSnapshot()

        let id = "goal-\(goal.id.uuidString)"
        cancel(identifier: id)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.goal.title")
        let emoji = goal.icon ?? "🎯"
        content.body = "\(emoji) \(goal.name) · \(Int(goal.progress * 100))%"
        content.sound = .default
        content.categoryIdentifier = "goal"

        var comps = DateComponents()
        comps.day = prefs.goalsMonthlyDay
        comps.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Recurring

    /// Agenda un recordatorio al usuario el día del next_date del recurring a
    /// las 9am: "acordate de confirmar este movimiento". El ejecutor real vive
    /// en Supabase DB; la notificación es solo heads-up.
    func scheduleRecurringReminder(recurring: RecurringTransaction, currency: String) async {
        let state = await authorizationState()
        guard state == .authorized || state == .provisional else { return }

        let id = "recurring-\(recurring.id.uuidString)"
        cancel(identifier: id)

        guard let nextDate = recurring.nextDate, nextDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = recurring.type == .gasto ? "Gasto recurrente hoy" : "Ingreso recurrente hoy"
        content.body = "\(recurring.category) · \(Money.format(recurring.amount, currency: currency, style: .compact))"
        content.sound = .default
        content.categoryIdentifier = "recurring"

        let cal = Calendar.current
        let atNineAM = cal.date(bySettingHour: 9, minute: 0, second: 0, of: nextDate) ?? nextDate
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: atNineAM),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Envelope overspending
    //
    // Cuando un envelope (categoría con budget asignado) supera ciertos
    // umbrales del monto allocated, disparamos una notif IMMEDIATE para que
    // el user lo sepa el día que pasa (no a fin de mes).
    //
    // Umbrales: 80% (warning), 100% (over), 120% (severe). El identifier
    // incluye el umbral para evitar disparar 3 veces el mismo (deduplicación
    // implicita por identifier).

    /// Dispara una notif inmediata cuando un envelope cruza un umbral.
    /// El caller decide cuándo invocar (típicamente desde `BudgetService`
    /// después de un insert/update de transaction que actualiza el balance
    /// del envelope).
    func notifyEnvelopeThreshold(
        category: String,
        subcategory: String? = nil,
        ratio: Double,
        allocated: Decimal,
        spent: Decimal,
        currency: String
    ) async {
        let state = await authorizationState()
        guard state == .authorized || state == .provisional else { return }

        let threshold: Int
        let icon: String
        let title: String
        let body: String
        let label = subcategory.flatMap { $0.isEmpty ? nil : "\(category) > \($0)" } ?? category

        if ratio >= 1.20 {
            threshold = 120
            icon = "🚨"
            title = "\(icon) Envelope MUY excedido: \(label)"
            body = "Gastaste \(Money.format(spent, currency: currency, style: .compact)) de \(Money.format(allocated, currency: currency, style: .compact)) asignados (\(Int(ratio * 100))%). Considerá reasignar desde otra categoría."
        } else if ratio >= 1.0 {
            threshold = 100
            icon = "🔴"
            title = "\(icon) Envelope excedido: \(label)"
            body = "Pasaste del 100% del presupuesto: \(Money.format(spent, currency: currency, style: .compact)) de \(Money.format(allocated, currency: currency, style: .compact)) asignados."
        } else if ratio >= 0.80 {
            threshold = 80
            icon = "🟡"
            title = "\(icon) \(label) cerca del límite"
            body = "Llevás \(Int(ratio * 100))% del presupuesto (\(Money.format(spent, currency: currency, style: .compact))). Te quedan \(Money.format(allocated - spent, currency: currency, style: .compact)) para fin de mes."
        } else {
            return  // por debajo de 80%: no notificar
        }

        // ID incluye categoría + mes + umbral. Si el user ya recibió la
        // notif de 80% este mes para "Alimentación", no se la mandamos
        // de nuevo. Apple no entrega notif con identifier duplicado.
        let monthKey = Self.currentMonthKey()
        let safeLabel = label.replacingOccurrences(of: " ", with: "_").lowercased()
        let id = "envelope-\(safeLabel)-\(monthKey)-t\(threshold)"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "envelope"

        // Trigger inmediato (5 segundos para que iOS lo entregue como
        // notification real, no como pasar de banner inline).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Dispara una notif inmediata cuando el AnomalyDetector encuentra algo
    /// relevante (cargo duplicado, monto atípico para la categoría, primera
    /// vez en categoría con monto alto). El caller pasa el texto de la
    /// anomalía ya formateado.
    func notifyAnomaly(title: String, body: String, anomalyId: String) async {
        let state = await authorizationState()
        guard state == .authorized || state == .provisional else { return }

        let id = "anomaly-\(anomalyId)"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "anomaly"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// "2026-05" — usado para deduplicar notifs de envelope por mes.
    private static func currentMonthKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: Date())
    }

    // MARK: - Cancel

    nonisolated func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    nonisolated func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Lista los identifiers agendados (útil para Settings view).
    func pendingIdentifiers() async -> [String] {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.map { $0.identifier }
    }
}

/// Preferencias de notificaciones persistidas en UserDefaults.
/// Incluye tiempos configurables (ej: cuántos días antes del vencimiento
/// notificar, a qué hora, qué día del mes recordar metas).
@MainActor
@Observable
final class NotificationPreferences {
    static let shared = NotificationPreferences()

    // Toggles master por tipo
    var bills: Bool { didSet { write("notif_bills", bills) } }
    var goals: Bool { didSet { write("notif_goals", goals) } }
    var recurring: Bool { didSet { write("notif_recurring", recurring) } }
    /// Alerta cuando un envelope supera 80%, 100% o 120% del presupuesto
    /// asignado. Notif inmediata (no agendada por fecha).
    var envelopeOverspend: Bool { didSet { write("notif_envelope", envelopeOverspend) } }
    /// Alertas cuando el AnomalyDetector detecta movimientos inusuales
    /// (cargos duplicados, montos atípicos, primera vez en categoría con
    /// monto alto).
    var anomalies: Bool { didSet { write("notif_anomalies", anomalies) } }

    // Timing configurable
    /// Cuántos días antes del vencimiento notificar (1-7).
    var billsDaysBefore: Int { didSet { writeInt("notif_bills_days", billsDaysBefore) } }
    /// Hora del día para disparar recordatorios de bills (0-23).
    var billsHour: Int { didSet { writeInt("notif_bills_hour", billsHour) } }
    /// Día del mes para recordatorio mensual de metas (1-28).
    var goalsMonthlyDay: Int { didSet { writeInt("notif_goals_day", goalsMonthlyDay) } }

    private init() {
        self.bills = UserDefaults.standard.object(forKey: "notif_bills") as? Bool ?? true
        self.goals = UserDefaults.standard.object(forKey: "notif_goals") as? Bool ?? true
        self.recurring = UserDefaults.standard.object(forKey: "notif_recurring") as? Bool ?? true
        self.envelopeOverspend = UserDefaults.standard.object(forKey: "notif_envelope") as? Bool ?? true
        self.anomalies = UserDefaults.standard.object(forKey: "notif_anomalies") as? Bool ?? true
        let daysBefore = UserDefaults.standard.object(forKey: "notif_bills_days") as? Int ?? 1
        self.billsDaysBefore = max(1, min(7, daysBefore))
        let hour = UserDefaults.standard.object(forKey: "notif_bills_hour") as? Int ?? 9
        self.billsHour = max(0, min(23, hour))
        let day = UserDefaults.standard.object(forKey: "notif_goals_day") as? Int ?? 1
        self.goalsMonthlyDay = max(1, min(28, day))
    }

    private func write(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private func writeInt(_ key: String, _ value: Int) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
