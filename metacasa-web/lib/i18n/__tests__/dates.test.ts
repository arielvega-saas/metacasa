import { afterEach, describe, expect, it, vi } from "vitest";
import { parseDayLocal, todayLocal, formatDayMonth } from "@/lib/i18n/dates";

/**
 * Fechas de calendario, no instantes.
 *
 * Toda la app es para LatAm, o sea husos negativos. Con `new Date("2026-08-10")`
 * el runtime asume medianoche UTC y al formatear en local sale el día anterior:
 * los movimientos se agrupaban bajo "Ayer" el mismo día que se cargaban, y los
 * vencimientos, metas y deudas mostraban un día menos. Estos tests fijan el
 * criterio: una fecha guardada es un día del calendario del usuario.
 */
describe("parseDayLocal", () => {
  it("da medianoche LOCAL, no UTC", () => {
    const d = parseDayLocal("2026-08-10");
    expect(d.getFullYear()).toBe(2026);
    expect(d.getMonth()).toBe(7); // agosto
    expect(d.getDate()).toBe(10);
    expect(d.getHours()).toBe(0);
  });

  it("NO retrocede un día — el bug original", () => {
    // `new Date("2026-08-10").getDate()` devuelve 9 en cualquier huso negativo.
    expect(parseDayLocal("2026-08-10").getDate()).toBe(10);
  });

  it("acepta un timestamp completo y se queda con el día", () => {
    expect(parseDayLocal("2026-08-10T12:00:00.000Z").getDate()).toBe(10);
  });

  it("el 1 de mes no se cae al mes anterior", () => {
    const d = parseDayLocal("2026-03-01");
    expect(d.getMonth()).toBe(2);
    expect(d.getDate()).toBe(1);
  });

  it("respeta el año bisiesto", () => {
    const d = parseDayLocal("2028-02-29");
    expect(d.getMonth()).toBe(1);
    expect(d.getDate()).toBe(29);
  });
});

describe("todayLocal", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("es medianoche del día local", () => {
    const t = todayLocal();
    const ahora = new Date();
    expect(t.getDate()).toBe(ahora.getDate());
    expect(t.getHours()).toBe(0);
    expect(t.getMinutes()).toBe(0);
  });

  it("de noche NO se adelanta al día siguiente", () => {
    // 23:30 del 10 de agosto, hora local. En Argentina (UTC-3) el instante UTC
    // ya es el 11: `toISOString().slice(0,10)` habría dicho "2026-08-11" y un
    // vencimiento de mañana se habría contado como de hoy.
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 7, 10, 23, 30));
    expect(todayLocal().getDate()).toBe(10);
  });
});

describe("formatDayMonth", () => {
  it("formatea el día guardado, no el anterior", () => {
    expect(formatDayMonth("2026-08-10", "es")).toContain("10");
  });
});
