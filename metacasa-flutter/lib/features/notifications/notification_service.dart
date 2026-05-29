import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../models/models.dart';
import 'notification_preferences.dart';

/// Estado de autorización de notificaciones (puente del `AuthorizationState` de
/// iOS al modelo de permisos de Android). En Android no existe `provisional`/
/// `ephemeral`; mapeamos lo que el sistema reporta:
///
///   - [authorized]    → notificaciones habilitadas (POST_NOTIFICATIONS OK).
///   - [denied]        → el usuario las apagó / negó el permiso runtime.
///   - [notDetermined] → todavía no se pidió (Android 13+ pre-prompt), o no se
///     puede determinar (Android <13 sin permiso runtime → se asume permitido,
///     ver [NotificationService.authorizationState]).
enum NotificationAuthStatus { notDetermined, authorized, denied }

/// Notificaciones locales (bills / metas / recurrentes / envelope-overspend).
/// Port del `NotificationService` de iOS (`Core/NotificationService.swift`)
/// sobre `flutter_local_notifications`.
///
/// Alcance: bills (ola 1) + metas, recurrentes y envelope-overspend (ola 2).
/// `notifyAnomaly` existe como espejo del de iOS, pero **no tiene caller**: no
/// hay `AnomalyDetector` porteado todavía, así que ningún controller lo dispara
/// (queda listo para cuando se porte el detector). Todos los toggles ya existen
/// en [NotificationPreferences].
///
/// Identifiers (espejo de iOS, prefix por entidad para cancelar en batch):
///   `bill-<uuid>-pre`      → N días antes del due date, a la hora configurada.
///   `bill-<uuid>-day`      → el día del vencimiento a las 18:00.
///   `bill-<uuid>-overdue`  → 1 día después del vencimiento a las 10:00.
///   `goal-<uuid>`          → recordatorio MENSUAL el día `goalsMonthlyDay` @10:00.
///   `recurring-<uuid>`     → heads-up el día de `nextDate` @09:00.
///   `envelope-<cat>-<yyyy-MM>-t<thr>` → inmediata al cruzar 80/100/120 %.
///   `anomaly-<id>`         → inmediata (sin caller; ver arriba).
///
/// Como `flutter_local_notifications` agenda por **id entero** (no String),
/// derivamos un int estable y positivo del identifier vía [_stableId] (hash
/// FNV-1a truncado a 31 bits). Mismo string ⇒ mismo int ⇒ re-agendar pisa la
/// anterior y cancelar usa el mismo id. La probabilidad de colisión entre los
/// pocos cientos de recordatorios vivos de un hogar es despreciable.
///
/// **Seguridad de ejecución en tests / desktop**: cada llamada al plugin está
/// guardada. `init()` atrapa cualquier excepción (incluida
/// `MissingPluginException` en `flutter test`, donde no hay binding nativo) y
/// deja el servicio en estado no-inicializado; el resto de los métodos no-opean
/// si no se inicializó. Así el provider se puede construir y el árbol bombear sin
/// tocar canales de plataforma.
class NotificationService {
  NotificationService();

  /// Plugin subyacente. Lazily-instanciado; sus métodos solo se invocan tras un
  /// [init] exitoso.
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _initInFlight = false;

  /// `true` cuando el plugin se inicializó y la zona horaria quedó cargada.
  bool get isReady => _initialized;

  // ── Canales (Android) ──────────────────────────────────────────────────

  /// Canal único de recordatorios de vencimientos. Importancia alta para que
  /// aparezca como heads-up (equivalente práctico del peso que iOS le da a la
  /// alerta de overdue). El lead debe declarar los receivers en el manifest
  /// (ver MANIFIESTO); el canal lo crea el plugin en runtime.
  static const String billsChannelId = 'bills_reminders';
  static const String _billsChannelName = 'Vencimientos';
  static const String _billsChannelDescription =
      'Recordatorios de vencimientos próximos, del día y vencidos.';

  /// Canal de recordatorios programados de baja urgencia: aporte mensual a metas
  /// y heads-up de movimientos recurrentes. Importancia `defaultImportance` (no
  /// heads-up): son gentiles, a diferencia del overdue de un vencimiento.
  static const String remindersChannelId = 'planning_reminders';
  static const String _remindersChannelName = 'Metas y recurrentes';
  static const String _remindersChannelDescription =
      'Recordatorio mensual de aporte a metas y avisos de movimientos recurrentes.';

  /// Canal de alertas inmediatas de presupuesto: un envelope cruzó 80/100/120 %.
  /// Importancia alta para que aparezca como heads-up el día en que pasa (espejo
  /// de la notif inmediata de iOS).
  static const String budgetChannelId = 'budget_alerts';
  static const String _budgetChannelName = 'Alertas de presupuesto';
  static const String _budgetChannelDescription =
      'Avisos cuando una categoría se acerca o supera su presupuesto del mes.';

  // ── Init ───────────────────────────────────────────────────────────────

  /// Inicializa el plugin, la base de zonas horarias (`timezone`) y el canal de
  /// Android. **Idempotente**: si ya corrió, retorna de inmediato. Pensado para
  /// llamarse perezosamente la primera vez que se necesita (desde el provider /
  /// el controller de bills), sin tocar `main.dart`.
  ///
  /// No lanza: ante cualquier error (incl. entorno de test sin plugin) deja
  /// `isReady == false` y los schedules posteriores no-opean.
  Future<void> init() async {
    if (_initialized || _initInFlight) return;
    _initInFlight = true;
    try {
      // 1) Zona horaria del device → `tz.local`, para que `zonedSchedule`
      //    dispare a la hora de pared correcta (DST incluido).
      tzdata.initializeTimeZones();
      try {
        final String name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        // Si no se puede leer la zona del SO, dejamos el default de la lib
        // (UTC). Mejor agendar en UTC que crashear.
      }

      // 2) Plugin. Sin icono custom: usamos el launcher icon del app
      //    (`@mipmap/ic_launcher`), presente en cualquier proyecto Flutter.
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings settings =
          InitializationSettings(android: androidInit);
      await _plugin.initialize(settings);

      // 3) Canal de bills (Android 8+). Crear un canal existente es no-op.
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          billsChannelId,
          _billsChannelName,
          description: _billsChannelDescription,
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          remindersChannelId,
          _remindersChannelName,
          description: _remindersChannelDescription,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          budgetChannelId,
          _budgetChannelName,
          description: _budgetChannelDescription,
          importance: Importance.high,
        ),
      );

      _initialized = true;
    } catch (_) {
      // Entorno sin soporte (tests/desktop) o fallo de init: quedamos no listos.
      _initialized = false;
    } finally {
      _initInFlight = false;
    }
  }

  // ── Permisos ─────────────────────────────────────────────────────────────

  /// Estado actual de autorización. En Android 13+ usa
  /// `areNotificationsEnabled()`; en versiones previas (sin permiso runtime) el
  /// plugin reporta habilitado salvo que el usuario las haya apagado.
  ///
  /// Devuelve [NotificationAuthStatus.notDetermined] si el servicio no está
  /// listo (no se puede consultar el sistema) — el caller mostrará el botón
  /// "Permitir", cuyo tap corre [init] + [requestPermission].
  Future<NotificationAuthStatus> authorizationState() async {
    if (!_initialized) return NotificationAuthStatus.notDetermined;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) {
        // No-Android (improbable en esta app, pero defensivo).
        return NotificationAuthStatus.authorized;
      }
      final bool? enabled = await android.areNotificationsEnabled();
      // `areNotificationsEnabled` no distingue "nunca pedido" de "negado" en
      // Android 13+. Tratamos `false` como denied y `true`/`null` como
      // authorized; el flujo de [requestPermission] cubre el primer prompt.
      return (enabled ?? true)
          ? NotificationAuthStatus.authorized
          : NotificationAuthStatus.denied;
    } catch (_) {
      return NotificationAuthStatus.notDetermined;
    }
  }

  /// Pide los permisos necesarios en Android 13+: `POST_NOTIFICATIONS` (runtime)
  /// y, para que `exactAllowWhileIdle` dispare puntual, `SCHEDULE_EXACT_ALARM`
  /// (en Android 14+ requiere consentimiento explícito).
  ///
  /// Idempotente y seguro: corre [init] si hace falta. Retorna `true` si las
  /// notificaciones quedaron habilitadas.
  Future<bool> requestPermission() async {
    await init();
    if (!_initialized) return false;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true;

      final bool granted =
          await android.requestNotificationsPermission() ?? false;
      // Pedimos exact-alarm aunque POST_NOTIFICATIONS falle: en algunos OEM el
      // permiso runtime ya está concedido y solo falta el de alarmas exactas.
      // Es best-effort; si el usuario lo niega, igual agendamos (el modo
      // `exactAllowWhileIdle` degrada a inexacto cuando no hay permiso).
      await android.requestExactAlarmsPermission();
      return granted;
    } catch (_) {
      return false;
    }
  }

  // ── Bills ──────────────────────────────────────────────────────────────

  /// Agenda los 3 recordatorios de un vencimiento (pre / día / overdue),
  /// respetando los toggles y timings de [NotificationPreferences]. Cancela los
  /// previos del mismo bill antes de re-agendar (idempotente al editar).
  ///
  /// No-opea silenciosamente si:
  ///   - el servicio no está listo (no inicializado / entorno de test),
  ///   - las notificaciones no están autorizadas,
  ///   - el toggle `bills` está apagado,
  ///   - el bill no está pendiente (pagado/saltado no necesitan recordatorio).
  ///
  /// Cada alerta individual además se saltea si su fecha de disparo ya pasó.
  Future<void> scheduleBillReminders(
    Bill bill,
    NotificationPreferences prefs,
  ) async {
    if (!_initialized) return;
    if (!prefs.bills) return;
    if (bill.status != BillStatus.pending) return;

    final NotificationAuthStatus status = await authorizationState();
    if (status != NotificationAuthStatus.authorized) return;

    // Re-agendar = pisar; cancelamos primero por las dudas (cambio de fecha/hora).
    await cancelBillReminders(bill.id);

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final String money = Money.format(bill.amount, currencyCode: bill.currency);

    // 1) Pre-vencimiento: N días antes, a la hora configurada.
    final tz.TZDateTime preDate = _atHour(
      _addDays(_dayOf(bill.dueDate), -prefs.billsDaysBefore),
      prefs.billsHour,
    );
    if (preDate.isAfter(now)) {
      final String daysText = prefs.billsDaysBefore == 1
          ? 'Vence mañana'
          : 'Vence en ${prefs.billsDaysBefore} días';
      await _schedule(
        id: _stableId(_preId(bill.id)),
        title: 'Vencimiento próximo',
        body: '${bill.title} · $daysText · $money',
        when: preDate,
      );
    }

    // 2) Día del vencimiento: 18:00.
    final tz.TZDateTime dayDate = _atHour(_dayOf(bill.dueDate), 18);
    if (dayDate.isAfter(now)) {
      await _schedule(
        id: _stableId(_dayId(bill.id)),
        title: 'Hoy vence: ${bill.title}',
        body: '$money · Marcalo como pagado si ya lo abonaste.',
        when: dayDate,
      );
    }

    // 3) Overdue: 1 día después, 10:00.
    final tz.TZDateTime overdueDate =
        _atHour(_addDays(_dayOf(bill.dueDate), 1), 10);
    if (overdueDate.isAfter(now)) {
      await _schedule(
        id: _stableId(_overdueId(bill.id)),
        title: '${bill.title} venció',
        body:
            'El vencimiento de $money figura sin pagar. Si ya lo pagaste, marcalo en la app.',
        when: overdueDate,
      );
    }
  }

  /// Cancela los 3 recordatorios asociados a un bill (pre + día + overdue). Se
  /// llama al marcar como pagado o al eliminar. Seguro si no hay nada agendado.
  Future<void> cancelBillReminders(String billId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_stableId(_preId(billId)));
      await _plugin.cancel(_stableId(_dayId(billId)));
      await _plugin.cancel(_stableId(_overdueId(billId)));
    } catch (_) {
      // no-op
    }
  }

  // ── Metas ────────────────────────────────────────────────────────────────

  /// Agenda el recordatorio MENSUAL de "contribuí a tu meta" el día
  /// `goalsMonthlyDay` a las 10:00 (id `goal-<id>`). Espejo del
  /// `scheduleGoalReminder` de iOS, que usa un `UNCalendarNotificationTrigger`
  /// repetido por `day`+`hour`; acá lo replicamos con `zonedSchedule` +
  /// [DateTimeComponents.dayOfMonthAndTime] (re-dispara el mismo día cada mes).
  ///
  /// Cancela el previo antes de re-agendar (idempotente al editar la meta) y
  /// no-opea para metas no-activas (completada / pausada / cancelada): no tiene
  /// sentido pedir aportes a una meta que ya no está en curso.
  ///
  /// No-opea silenciosamente si el servicio no está listo, las notificaciones no
  /// están autorizadas o el toggle `goals` está apagado.
  Future<void> scheduleGoalReminder(
    Goal goal,
    NotificationPreferences prefs,
  ) async {
    if (!_initialized) return;
    if (!prefs.goals) return;
    if (goal.status != GoalStatus.active) {
      // No-activa: cancelamos por si venía agendada de antes y salimos.
      await cancelGoalReminder(goal.id);
      return;
    }

    final NotificationAuthStatus status = await authorizationState();
    if (status != NotificationAuthStatus.authorized) return;

    await cancelGoalReminder(goal.id);

    // Próxima ocurrencia del día configurado @10:00: este mes si todavía no
    // pasó, el mes que viene si ya pasó. El `matchDateTimeComponents` se encarga
    // de las repeticiones siguientes (mismo día/hora cada mes).
    final tz.TZDateTime when = _nextMonthlyDayAtHour(prefs.goalsMonthlyDay, 10);

    final int pct = (goal.progress * 100).round();
    final String icon =
        (goal.icon != null && goal.icon!.isNotEmpty) ? goal.icon! : '🎯';
    await _schedule(
      id: _stableId(_goalId(goal.id)),
      title: 'Sumá a tu meta',
      body: '$icon ${goal.name} · $pct%',
      when: when,
      channelId: remindersChannelId,
      channelName: _remindersChannelName,
      channelDescription: _remindersChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      payload: 'goal',
      matchComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  /// Cancela el recordatorio mensual de una meta (id `goal-<id>`). Se llama al
  /// eliminar la meta o al desactivarla. Seguro si no había nada agendado.
  Future<void> cancelGoalReminder(String goalId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_stableId(_goalId(goalId)));
    } catch (_) {
      // no-op
    }
  }

  // ── Recurrentes ────────────────────────────────────────────────────────────

  /// Agenda un heads-up el día de `nextDate` a las 09:00 (id `recurring-<id>`):
  /// "acordate de confirmar este movimiento". Espejo del
  /// `scheduleRecurringReminder` de iOS. El ejecutor real de la recurrente vive
  /// en la DB; esto es solo el aviso.
  ///
  /// Cancela el previo antes de re-agendar (idempotente). No-opea si el servicio
  /// no está listo, las notificaciones no están autorizadas, el toggle
  /// `recurring` está apagado, la recurrente está inactiva, o `nextDate` es nulo
  /// o ya pasó.
  ///
  /// `currencyCode` viene del hogar (la recurrente no guarda moneda propia, igual
  /// que en iOS, donde `scheduleRecurringReminder` recibe `currency`); default
  /// `USD` por si el caller no lo resuelve.
  Future<void> scheduleRecurringHeadsUp(
    RecurringTransaction recurring,
    NotificationPreferences prefs, {
    String currencyCode = 'USD',
  }) async {
    if (!_initialized) return;
    if (!prefs.recurring) return;
    if (!recurring.active) {
      await cancelRecurringHeadsUp(recurring.id);
      return;
    }

    final NotificationAuthStatus status = await authorizationState();
    if (status != NotificationAuthStatus.authorized) return;

    await cancelRecurringHeadsUp(recurring.id);

    final DateTime? next = recurring.nextDate;
    if (next == null) return;

    final tz.TZDateTime when = _atHour(_dayOf(next), 9);
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    if (!when.isAfter(now)) return;

    final String money =
        Money.format(recurring.amount, currencyCode: currencyCode);
    final String sub =
        (recurring.subcategory != null && recurring.subcategory!.isNotEmpty)
            ? '${recurring.category} > ${recurring.subcategory}'
            : recurring.category;
    await _schedule(
      id: _stableId(_recurringId(recurring.id)),
      title: recurring.type == TxType.gasto
          ? 'Gasto recurrente hoy'
          : 'Ingreso recurrente hoy',
      body: '$sub · $money',
      when: when,
      channelId: remindersChannelId,
      channelName: _remindersChannelName,
      channelDescription: _remindersChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      payload: 'recurring',
    );
  }

  /// Cancela el heads-up de una recurrente (id `recurring-<id>`). Se llama al
  /// desactivarla o eliminarla. Seguro si no había nada agendado.
  Future<void> cancelRecurringHeadsUp(String recurringId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_stableId(_recurringId(recurringId)));
    } catch (_) {
      // no-op
    }
  }

  // ── Envelope overspend ─────────────────────────────────────────────────────

  /// Dispara una notif **inmediata** cuando un envelope cruza un umbral del
  /// presupuesto del mes (80 % warning / 100 % over / 120 % severe). Espejo del
  /// `notifyEnvelopeThreshold` de iOS.
  ///
  /// Deduplicación: el id es `envelope-<cat>-<yyyy-MM>-t<thr>`, así una misma
  /// categoría no recibe dos veces el aviso del mismo umbral en el mismo mes. En
  /// iOS alcanza con que el sistema rechace identifiers duplicados *pendientes*;
  /// acá la notif se entrega casi de inmediato (no queda "pendiente"), así que
  /// la dedupe la sostenemos nosotros con un set persistido en
  /// `shared_preferences` ([_overspendKey]). El controller puede invocar esto en
  /// cada build sin spamear.
  ///
  /// No-opea si el servicio no está listo, las notificaciones no están
  /// autorizadas, el toggle `envelopeOverspend` está apagado, `percentUsed` está
  /// por debajo de 0.80, o el aviso de ese (categoría, mes, umbral) ya se mandó.
  Future<void> notifyEnvelopeOverspend({
    required String category,
    required DateTime period,
    required double percentUsed,
    String? subcategory,
    Decimal? allocated,
    Decimal? spent,
    String currencyCode = 'USD',
    NotificationPreferences? prefs,
  }) async {
    if (!_initialized) return;
    if (prefs != null && !prefs.envelopeOverspend) return;

    // Umbral cruzado (el más alto aplicable). Por debajo de 80 %: nada.
    final int threshold;
    if (percentUsed >= 1.20) {
      threshold = 120;
    } else if (percentUsed >= 1.0) {
      threshold = 100;
    } else if (percentUsed >= 0.80) {
      threshold = 80;
    } else {
      return;
    }

    final NotificationAuthStatus status = await authorizationState();
    if (status != NotificationAuthStatus.authorized) return;

    final String label = (subcategory != null && subcategory.isNotEmpty)
        ? '$category > $subcategory'
        : category;
    final String monthKey = _monthKey(period);
    final String safeLabel = label.replaceAll(' ', '_').toLowerCase();
    final String id = 'envelope-$safeLabel-$monthKey-t$threshold';

    // Dedupe persistente: si ya disparamos este (cat, mes, umbral), salimos.
    if (await _overspendAlreadyFired(id)) return;

    final int pct = (percentUsed * 100).round();
    final String title;
    final String body;
    final String spentTxt = allocated != null && spent != null
        ? Money.format(spent, currencyCode: currencyCode)
        : '';
    final String allocTxt = allocated != null
        ? Money.format(allocated, currencyCode: currencyCode)
        : '';
    if (threshold == 120) {
      title = 'Categoría muy excedida: $label';
      body = allocated != null && spent != null
          ? 'Gastaste $spentTxt de $allocTxt asignados ($pct%). Considerá reasignar desde otra categoría.'
          : 'Vas $pct% del presupuesto. Considerá reasignar desde otra categoría.';
    } else if (threshold == 100) {
      title = 'Categoría excedida: $label';
      body = allocated != null && spent != null
          ? 'Pasaste del 100% del presupuesto: $spentTxt de $allocTxt asignados.'
          : 'Pasaste del 100% del presupuesto de esta categoría.';
    } else {
      title = '$label cerca del límite';
      final String remainingTxt = allocated != null && spent != null
          ? Money.format(allocated - spent, currencyCode: currencyCode)
          : '';
      body = allocated != null && spent != null
          ? 'Llevás $pct% del presupuesto ($spentTxt). Te quedan $remainingTxt para fin de mes.'
          : 'Llevás $pct% del presupuesto de esta categoría.';
    }

    // Inmediata: agendamos a ~5s (igual que iOS) para que el sistema la entregue
    // como notificación real y no como banner inline.
    final tz.TZDateTime when =
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    await _schedule(
      id: _stableId(id),
      title: title,
      body: body,
      when: when,
      channelId: budgetChannelId,
      channelName: _budgetChannelName,
      channelDescription: _budgetChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      payload: 'envelope',
    );
    // Marcamos como disparado SOLO si el schedule no tiró (best-effort): si el
    // plugin falló, `_schedule` ya tragó el error; igualmente persistimos para
    // no reintentar en loop en cada build (el costo de perder un aviso aislado
    // es menor que spamear si algo del plugin viene fallando).
    await _markOverspendFired(id);
  }

  // ── Anomalías ──────────────────────────────────────────────────────────────

  /// Dispara una notif inmediata para una anomalía ya formateada (id
  /// `anomaly-<id>`). Espejo del `notifyAnomaly` de iOS.
  ///
  /// SIN CALLER por ahora: no hay `AnomalyDetector` porteado a Flutter, así que
  /// ningún controller lo invoca. Queda implementado para mantener la paridad de
  /// API y el toggle `anomalies`, listo para cuando se porte el detector.
  Future<void> notifyAnomaly({
    required String anomalyId,
    required String title,
    required String body,
    NotificationPreferences? prefs,
  }) async {
    if (!_initialized) return;
    if (prefs != null && !prefs.anomalies) return;

    final NotificationAuthStatus status = await authorizationState();
    if (status != NotificationAuthStatus.authorized) return;

    final tz.TZDateTime when =
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    await _schedule(
      id: _stableId('anomaly-$anomalyId'),
      title: title,
      body: body,
      when: when,
      channelId: budgetChannelId,
      channelName: _budgetChannelName,
      channelDescription: _budgetChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      payload: 'anomaly',
    );
  }

  // ── Internos ─────────────────────────────────────────────────────────────

  /// Agenda una notificación con `exactAllowWhileIdle` (dispara aun en Doze).
  /// Atrapa errores para que un fallo de una alerta no aborte el resto.
  ///
  /// Parametrizado por canal/importancia/payload para servir a las cuatro
  /// familias (bills, metas, recurrentes, envelope/anomalía). Defaults = canal de
  /// bills, así el call site original no cambia. `matchComponents` habilita la
  /// recurrencia (mensual para metas).
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    String channelId = billsChannelId,
    String channelName = _billsChannelName,
    String channelDescription = _billsChannelDescription,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    String payload = 'bill',
    DateTimeComponents? matchComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: importance,
            priority: priority,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
        matchDateTimeComponents: matchComponents,
      );
    } catch (_) {
      // no-op (entorno sin soporte o error puntual)
    }
  }

  static String _preId(String billId) => 'bill-$billId-pre';
  static String _dayId(String billId) => 'bill-$billId-day';
  static String _overdueId(String billId) => 'bill-$billId-overdue';
  static String _goalId(String goalId) => 'goal-$goalId';
  static String _recurringId(String recurringId) => 'recurring-$recurringId';

  /// `DateTime` → inicio del día (medianoche) en la zona local de `timezone`.
  static tz.TZDateTime _dayOf(DateTime d) =>
      tz.TZDateTime(tz.local, d.year, d.month, d.day);

  static tz.TZDateTime _addDays(tz.TZDateTime d, int days) =>
      d.add(Duration(days: days));

  /// Fija la hora (minuto/segundo en 0) sobre una fecha local.
  static tz.TZDateTime _atHour(tz.TZDateTime d, int hour) =>
      tz.TZDateTime(tz.local, d.year, d.month, d.day, hour);

  /// Próxima ocurrencia del día [day] del mes a las [hour]:00 en zona local.
  /// Si ese instante de ESTE mes ya pasó, devuelve el del mes siguiente. Clampea
  /// el día al último día del mes destino (p. ej. día 31 en un mes de 30 → 30),
  /// defensivo aunque `goalsMonthlyDay` ya viene 1–28.
  static tz.TZDateTime _nextMonthlyDayAtHour(int day, int hour) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final int dThis = _clampDayToMonth(now.year, now.month, day);
    final tz.TZDateTime candidate =
        tz.TZDateTime(tz.local, now.year, now.month, dThis, hour);
    if (candidate.isAfter(now)) return candidate;
    final int nextYear = now.month == 12 ? now.year + 1 : now.year;
    final int nextMonth = now.month == 12 ? 1 : now.month + 1;
    final int dNext = _clampDayToMonth(nextYear, nextMonth, day);
    return tz.TZDateTime(tz.local, nextYear, nextMonth, dNext, hour);
  }

  /// Acota [day] al rango de días válido del mes (año/mes dados).
  static int _clampDayToMonth(int year, int month, int day) {
    // Día 0 del mes siguiente = último día del mes actual.
    final int lastDay = DateTime(year, month + 1, 0).day;
    if (day < 1) return 1;
    return day > lastDay ? lastDay : day;
  }

  /// "2026-05" — clave de mes para deduplicar los avisos de envelope.
  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  // ── Dedupe persistente de envelope-overspend ──────────────────────────────
  //
  // Guardamos el set de ids ya disparados en `shared_preferences`. Es chico
  // (unos pocos por mes) y prunear las claves de meses viejos no es crítico, así
  // que lo dejamos crecer: dominado por el número de categorías × 3 umbrales ×
  // meses, despreciable. La lectura/escritura es defensiva (no rompe en test).

  static const String _overspendKey = 'notif_envelope_fired';

  Future<bool> _overspendAlreadyFired(String id) async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      final List<String> fired =
          sp.getStringList(_overspendKey) ?? const <String>[];
      return fired.contains(id);
    } catch (_) {
      // Sin persistencia (test/desktop): tratamos como "no disparado" para no
      // bloquear; el flujo igual está guardado aguas arriba.
      return false;
    }
  }

  Future<void> _markOverspendFired(String id) async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      final List<String> fired =
          List<String>.of(sp.getStringList(_overspendKey) ?? const <String>[]);
      if (!fired.contains(id)) {
        fired.add(id);
        await sp.setStringList(_overspendKey, fired);
      }
    } catch (_) {
      // no-op
    }
  }

  /// Hash estable y positivo (31 bits) de un identifier String → id int del
  /// plugin. FNV-1a 32-bit truncado, así el MISMO string siempre da el MISMO
  /// id (necesario para cancelar/reemplazar). Aritmética acotada a 32 bits con
  /// máscaras para ser determinista en VM y Web.
  @visibleForTesting
  static int stableIdForTest(String s) => _stableId(s);

  static int _stableId(String s) {
    const int prime = 0x01000193; // 16777619
    int hash = 0x811c9dc5; // 2166136261
    for (int i = 0; i < s.length; i++) {
      hash ^= s.codeUnitAt(i) & 0xff;
      hash = (hash * prime) & 0xffffffff;
    }
    // A 31 bits positivos (los ids del plugin deben caber en un int32 con signo).
    return hash & 0x7fffffff;
  }
}

/// Provider del [NotificationService]. **Singleton de app** (no autoDispose): el
/// estado de inicialización del plugin debe sobrevivir a la reconstrucción de
/// pantallas. El servicio se construye barato; `init()` se invoca de forma
/// perezosa (no en el provider) para no tocar canales nativos al armar el árbol
/// — clave para que `flutter test` no rompa.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
