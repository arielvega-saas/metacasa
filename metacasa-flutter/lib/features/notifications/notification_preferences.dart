import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de notificaciones locales, persistidas en `shared_preferences`.
///
/// Espejo 1:1 de `NotificationPreferences` del iOS
/// (`Core/NotificationService.swift`): mismos toggles, mismos timings y, sobre
/// todo, **las mismas claves** que usa el iOS en `UserDefaults` para no divergir
/// la semántica entre plataformas (aunque cada SO tenga su propio almacén):
///
///   notif_bills        Bool  (default true)
///   notif_goals        Bool  (default true)
///   notif_recurring    Bool  (default true)
///   notif_envelope     Bool  (default true)
///   notif_anomalies    Bool  (default true)
///   notif_bills_days   Int   (default 1, clamp 1–7)
///   notif_bills_hour   Int   (default 9, clamp 0–23)
///   notif_goals_day    Int   (default 1, clamp 1–28)
///
/// Patrón calcado de `ai_consent_provider.dart` / `settings_providers.dart`: el
/// `build()` devuelve los defaults sincrónicamente y dispara una restauración
/// diferida desde disco; las escrituras son fire-and-forget. Es **defensivo**
/// ante `flutter test` sin binding del plugin (no tumba el árbol: se queda en
/// los defaults y descarta la persistencia).

/// Claves de `shared_preferences` — idénticas a las de `UserDefaults` del iOS.
abstract final class NotifKeys {
  static const String bills = 'notif_bills';
  static const String goals = 'notif_goals';
  static const String recurring = 'notif_recurring';
  static const String envelopeOverspend = 'notif_envelope';
  static const String anomalies = 'notif_anomalies';
  static const String billsDaysBefore = 'notif_bills_days';
  static const String billsHour = 'notif_bills_hour';
  static const String goalsMonthlyDay = 'notif_goals_day';
}

/// Estado inmutable de las preferencias de notificaciones. Clase plana (sin
/// freezed/codegen, por requerimiento del equipo) con `copyWith` manual.
class NotificationPreferences {
  const NotificationPreferences({
    this.bills = true,
    this.goals = true,
    this.recurring = true,
    this.envelopeOverspend = true,
    this.anomalies = true,
    this.billsDaysBefore = 1,
    this.billsHour = 9,
    this.goalsMonthlyDay = 1,
  });

  // ── Toggles master por tipo (default true, igual que iOS) ──

  /// Recordatorios de vencimientos (pre / día / overdue).
  final bool bills;

  /// Recordatorio mensual de "contribuí a tu meta".
  final bool goals;

  /// Heads-up el día de un movimiento recurrente.
  final bool recurring;

  /// Alerta cuando un envelope supera 80 % / 100 % / 120 % del presupuesto.
  final bool envelopeOverspend;

  /// Alertas de movimientos atípicos (duplicados, montos inusuales, etc.).
  final bool anomalies;

  // ── Timing configurable (con los rangos del iOS) ──

  /// Cuántos días antes del vencimiento notificar (1–7).
  final int billsDaysBefore;

  /// Hora del día para los recordatorios de bills (0–23).
  final int billsHour;

  /// Día del mes para el recordatorio mensual de metas (1–28).
  final int goalsMonthlyDay;

  NotificationPreferences copyWith({
    bool? bills,
    bool? goals,
    bool? recurring,
    bool? envelopeOverspend,
    bool? anomalies,
    int? billsDaysBefore,
    int? billsHour,
    int? goalsMonthlyDay,
  }) {
    return NotificationPreferences(
      bills: bills ?? this.bills,
      goals: goals ?? this.goals,
      recurring: recurring ?? this.recurring,
      envelopeOverspend: envelopeOverspend ?? this.envelopeOverspend,
      anomalies: anomalies ?? this.anomalies,
      billsDaysBefore: billsDaysBefore ?? this.billsDaysBefore,
      billsHour: billsHour ?? this.billsHour,
      goalsMonthlyDay: goalsMonthlyDay ?? this.goalsMonthlyDay,
    );
  }
}

/// `Notifier` de las preferencias de notificaciones. Defaults idénticos al iOS;
/// restaura desde disco en `build()` y persiste en cada setter.
class NotificationPreferencesNotifier
    extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() {
    _restore();
    return const NotificationPreferences();
  }

  /// Lee los valores persistidos y, si difieren del default, actualiza el
  /// estado. Defensivo: si el plugin no está disponible (p. ej. `flutter test`)
  /// o falla la lectura, conserva los defaults.
  Future<void> _restore() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      state = NotificationPreferences(
        bills: sp.getBool(NotifKeys.bills) ?? true,
        goals: sp.getBool(NotifKeys.goals) ?? true,
        recurring: sp.getBool(NotifKeys.recurring) ?? true,
        envelopeOverspend: sp.getBool(NotifKeys.envelopeOverspend) ?? true,
        anomalies: sp.getBool(NotifKeys.anomalies) ?? true,
        billsDaysBefore:
            _clamp(sp.getInt(NotifKeys.billsDaysBefore) ?? 1, 1, 7),
        billsHour: _clamp(sp.getInt(NotifKeys.billsHour) ?? 9, 0, 23),
        goalsMonthlyDay:
            _clamp(sp.getInt(NotifKeys.goalsMonthlyDay) ?? 1, 1, 28),
      );
    } catch (_) {
      // Sin persistencia: nos quedamos en los defaults.
    }
  }

  // ── Setters (actualizan estado + persisten, fire-and-forget) ──

  void setBills(bool value) => _setBool(NotifKeys.bills, value,
      (NotificationPreferences p) => p.copyWith(bills: value));

  void setGoals(bool value) => _setBool(NotifKeys.goals, value,
      (NotificationPreferences p) => p.copyWith(goals: value));

  void setRecurring(bool value) => _setBool(NotifKeys.recurring, value,
      (NotificationPreferences p) => p.copyWith(recurring: value));

  void setEnvelopeOverspend(bool value) => _setBool(
      NotifKeys.envelopeOverspend,
      value,
      (NotificationPreferences p) => p.copyWith(envelopeOverspend: value));

  void setAnomalies(bool value) => _setBool(NotifKeys.anomalies, value,
      (NotificationPreferences p) => p.copyWith(anomalies: value));

  void setBillsDaysBefore(int value) {
    final int v = _clamp(value, 1, 7);
    _setInt(NotifKeys.billsDaysBefore, v,
        (NotificationPreferences p) => p.copyWith(billsDaysBefore: v));
  }

  void setBillsHour(int value) {
    final int v = _clamp(value, 0, 23);
    _setInt(NotifKeys.billsHour, v,
        (NotificationPreferences p) => p.copyWith(billsHour: v));
  }

  void setGoalsMonthlyDay(int value) {
    final int v = _clamp(value, 1, 28);
    _setInt(NotifKeys.goalsMonthlyDay, v,
        (NotificationPreferences p) => p.copyWith(goalsMonthlyDay: v));
  }

  void _setBool(String key, bool value,
      NotificationPreferences Function(NotificationPreferences) apply) {
    state = apply(state);
    _persistBool(key, value);
  }

  void _setInt(String key, int value,
      NotificationPreferences Function(NotificationPreferences) apply) {
    state = apply(state);
    _persistInt(key, value);
  }

  Future<void> _persistBool(String key, bool value) async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.setBool(key, value);
    } catch (_) {
      // En memoria queda aplicado para esta sesión.
    }
  }

  Future<void> _persistInt(String key, int value) async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.setInt(key, value);
    } catch (_) {
      // En memoria queda aplicado para esta sesión.
    }
  }

  static int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
}

/// Provider de las preferencias de notificaciones.
final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);
