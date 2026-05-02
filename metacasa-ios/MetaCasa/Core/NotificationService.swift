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

    /// Agenda una notificación N días antes del due date, a la hora configurada
    /// por el usuario (default: 1 día antes a las 9am). Si ya pasó, no agenda.
    func scheduleBillReminder(bill: Bill) async {
        let state = await authorizationState()
        guard state == .authorized || state == .provisional else { return }

        let prefs = await prefsSnapshot()

        let id = "bill-\(bill.id.uuidString)"
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
