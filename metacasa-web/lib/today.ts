/**
 * "Hoy" según el calendario del USUARIO, no el del servidor.
 *
 * El problema que resuelve este módulo: en Netlify el server corre con `TZ=UTC`,
 * así que `new Date()` en un Server Component NO es el día del usuario. Para
 * alguien en Argentina (UTC-3) eso rompía todos los días, entre las 21:00 y la
 * medianoche:
 *  - la racha del dashboard arrancaba el cursor en el día UTC (que ya es mañana)
 *    y mostraba 0 aunque acabara de cargar un movimiento;
 *  - el 31 a las 21:05 el dashboard, reportes y presupuesto abrían en el MES
 *    SIGUIENTE: ingresos $0, gastos $0, delta -100%, y el CTA ofrecía crear el
 *    período del mes que viene cuando todavía quedaban 3 horas del actual.
 *
 * Cómo viaja la fecha del cliente al server: un componente cliente diminuto
 * (`components/layout/timezone-cookie.tsx`) escribe la zona IANA del navegador
 * en la cookie `mc_tz` (`Intl…resolvedOptions().timeZone`; sin geo-IP y sin
 * pedir permisos). Los Server Components la leen con `lib/today-server.ts`.
 *
 * Módulo PURO (sin `next/headers`, sin "use client"), mismo patrón que
 * `lib/theme.ts`: lo importan el lector server, el componente cliente, la lógica
 * de salud financiera y los tests.
 *
 * REGLA ÚNICA DE VALIDACIÓN: `normalizeToday` — la misma que ya usaba
 * `/api/assistant` para el `today` que manda el browser. Vive acá y la usan los
 * dos caminos (body del asistente y cookie de zona horaria). Si aparece un
 * tercer camino, tiene que pasar por esta función y no por una copia.
 */

/** Cookie con la zona horaria IANA del navegador (p.ej. `America/Argentina/Buenos_Aires`). */
export const TZ_COOKIE = "mc_tz";

/** Un año: la zona horaria de alguien no cambia entre sesiones (igual que `mc_theme`). */
export const TZ_COOKIE_MAX_AGE = 60 * 60 * 24 * 365;

/**
 * Tope de largo del valor de la cookie. Es input del cliente: ninguna zona IANA
 * real pasa de ~40 caracteres, y así `Intl` nunca recibe una bomba de texto.
 */
const MAX_TZ_LENGTH = 64;

/** Caracteres válidos de una zona IANA (`America/Argentina/Buenos_Aires`, `Etc/GMT+3`). */
const TZ_SHAPE = /^[A-Za-z0-9_+\-/]+$/;

const ISO_DAY = /^\d{4}-\d{2}-\d{2}$/;
const ISO_MONTH = /^\d{4}-\d{2}$/;

/** El día UTC del server, `YYYY-MM-DD`. Es el fallback de todo este módulo. */
export function utcToday(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10);
}

/**
 * Valida un `YYYY-MM-DD` que dice ser el "hoy" del usuario.
 *
 * Viene del cliente, así que se trata como input no confiable: sólo pasa si es
 * una fecha real y está dentro de ±2 días del UTC del server. Ese margen cubre
 * cualquier huso del mundo (UTC-12 a UTC+14) sin dejar que alguien fabrique
 * movimientos con fecha arbitraria pidiéndole al asistente que los cargue "hoy".
 *
 * `now` es inyectable sólo para testear; en producción siempre es el reloj real.
 */
export function normalizeToday(raw: unknown, now: Date = new Date()): string {
  const utcHoy = utcToday(now);
  if (typeof raw !== "string" || !ISO_DAY.test(raw)) return utcHoy;
  const [y, m, d] = raw.split("-").map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  const esFechaReal =
    dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d;
  if (!esFechaReal) return utcHoy;
  const dias = Math.abs(dt.getTime() - Date.parse(`${utcHoy}T00:00:00Z`)) / 86_400_000;
  return dias <= 2 ? raw : utcHoy;
}

/**
 * `true` si `tz` tiene forma de zona IANA plausible. Filtro barato ANTES de
 * pasarle el valor a `Intl` (que además valida de verdad).
 */
export function isTimeZoneShape(tz: unknown): tz is string {
  return (
    typeof tz === "string" &&
    tz.length > 0 &&
    tz.length <= MAX_TZ_LENGTH &&
    TZ_SHAPE.test(tz)
  );
}

/**
 * El día de calendario (`YYYY-MM-DD`) que es `now` en la zona `timeZone`.
 * Devuelve `null` si la zona no existe o el runtime no la conoce — nunca tira.
 */
export function dayInTimeZone(timeZone: unknown, now: Date = new Date()): string | null {
  if (!isTimeZoneShape(timeZone)) return null;
  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat("en-US", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(now);
  } catch {
    // `RangeError: Invalid time zone specified` — cookie basura o zona que este
    // runtime no tiene en su ICU.
    return null;
  }
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  const iso = `${get("year")}-${get("month")}-${get("day")}`;
  return ISO_DAY.test(iso) ? iso : null;
}

/**
 * El "hoy" del usuario a partir del valor CRUDO de la cookie `mc_tz`.
 *
 * Cookie ausente, con basura, o zona que el runtime no conoce → el día UTC del
 * server (exactamente el comportamiento anterior al fix: nunca rompe).
 * El resultado pasa siempre por `normalizeToday`, así que una cookie forjada no
 * puede correr la fecha más de ±2 días.
 */
export function todayFromTimeZoneCookie(raw: unknown, now: Date = new Date()): string {
  return normalizeToday(dayInTimeZone(raw, now), now);
}

/** `YYYY-MM` de un día `YYYY-MM-DD`. */
export function monthOf(day: string): string {
  return day.slice(0, 7);
}

/**
 * Mes a mostrar en dashboard / reportes / presupuesto: el `?ym=` de la URL si es
 * válido, y si no el mes del calendario del USUARIO (no el del server).
 */
export function resolveYm(raw: string | undefined, today: string): string {
  return raw && ISO_MONTH.test(raw) ? raw : monthOf(today);
}

/** `[año, mes]` (mes 1-12) de un `YYYY-MM` o `YYYY-MM-DD`. */
export function splitYm(ym: string): [number, number] {
  const [y, m] = ym.split("-").map(Number);
  return [y, m];
}

/**
 * Medianoche UTC del día `YYYY-MM-DD`. Es el ancla del cursor de la racha: las
 * claves de días activos son slices UTC de `transactions.date` (que se guarda a
 * mediodía UTC vía `toStableDate`), así que iterar en UTC sobre un día YA
 * resuelto en la zona del usuario es lo correcto.
 */
export function dayStartUtc(day: string): Date {
  return new Date(`${day}T00:00:00.000Z`);
}

/** `true` si el string tiene forma `YYYY-MM-DD`. */
export function isIsoDay(v: unknown): v is string {
  return typeof v === "string" && ISO_DAY.test(v);
}
