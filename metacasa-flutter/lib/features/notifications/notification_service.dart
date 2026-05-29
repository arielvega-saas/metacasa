import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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

/// Notificaciones locales para vencimientos (bills). Port del `NotificationService`
/// de iOS (`Core/NotificationService.swift`) sobre `flutter_local_notifications`.
///
/// Alcance de esta entrega: **solo bills** (metas / recurrentes / envelope /
/// anomalías quedan para olas siguientes; los toggles ya existen en
/// [NotificationPreferences] para no romper la paridad de UI).
///
/// Identifiers (espejo de iOS, prefix por entidad para cancelar en batch):
///   `bill-<uuid>-pre`      → N días antes del due date, a la hora configurada.
///   `bill-<uuid>-day`      → el día del vencimiento a las 18:00.
///   `bill-<uuid>-overdue`  → 1 día después del vencimiento a las 10:00.
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

  // ── Internos ─────────────────────────────────────────────────────────────

  /// Agenda una notificación puntual con `exactAllowWhileIdle` (dispara aun en
  /// Doze). Atrapa errores para que un fallo de una alerta no aborte el resto.
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            billsChannelId,
            _billsChannelName,
            channelDescription: _billsChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'bill',
      );
    } catch (_) {
      // no-op (entorno sin soporte o error puntual)
    }
  }

  static String _preId(String billId) => 'bill-$billId-pre';
  static String _dayId(String billId) => 'bill-$billId-day';
  static String _overdueId(String billId) => 'bill-$billId-overdue';

  /// `DateTime` → inicio del día (medianoche) en la zona local de `timezone`.
  static tz.TZDateTime _dayOf(DateTime d) =>
      tz.TZDateTime(tz.local, d.year, d.month, d.day);

  static tz.TZDateTime _addDays(tz.TZDateTime d, int days) =>
      d.add(Duration(days: days));

  /// Fija la hora (minuto/segundo en 0) sobre una fecha local.
  static tz.TZDateTime _atHour(tz.TZDateTime d, int hour) =>
      tz.TZDateTime(tz.local, d.year, d.month, d.day, hour);

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
