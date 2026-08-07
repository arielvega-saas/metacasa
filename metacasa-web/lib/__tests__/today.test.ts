import { describe, it, expect } from "vitest";
import {
  utcToday,
  normalizeToday,
  dayInTimeZone,
  todayFromTimeZoneCookie,
  monthOf,
  resolveYm,
  splitYm,
  dayStartUtc,
  isTimeZoneShape,
} from "@/lib/today";

/** La zona del mercado principal de la app. UTC-3 todo el año (sin DST). */
const AR = "America/Argentina/Buenos_Aires";

describe("dayInTimeZone", () => {
  it("resuelve el día del calendario del usuario, no el del server", () => {
    // 2026-08-04 21:05 en Buenos Aires.
    const instante = new Date("2026-08-05T00:05:00.000Z");
    expect(utcToday(instante)).toBe("2026-08-05"); // lo que ve el server
    expect(dayInTimeZone(AR, instante)).toBe("2026-08-04"); // lo que ve el usuario
  });

  it("funciona también con husos POSITIVOS (el usuario va adelante del server)", () => {
    // 2026-08-05 09:00 en Auckland = 2026-08-04 21:00 UTC.
    const instante = new Date("2026-08-04T21:00:00.000Z");
    expect(dayInTimeZone("Pacific/Auckland", instante)).toBe("2026-08-05");
  });

  it("devuelve null (no tira) con una zona inexistente o basura", () => {
    const instante = new Date("2026-08-05T00:05:00.000Z");
    expect(dayInTimeZone("No/Existe", instante)).toBeNull();
    expect(dayInTimeZone("'; drop table --", instante)).toBeNull();
    expect(dayInTimeZone("A".repeat(500), instante)).toBeNull();
    expect(dayInTimeZone(undefined, instante)).toBeNull();
    expect(dayInTimeZone(42, instante)).toBeNull();
  });
});

describe("isTimeZoneShape", () => {
  it("acepta zonas IANA reales", () => {
    expect(isTimeZoneShape(AR)).toBe(true);
    expect(isTimeZoneShape("Europe/Madrid")).toBe(true);
    expect(isTimeZoneShape("Etc/GMT+3")).toBe(true);
    expect(isTimeZoneShape("UTC")).toBe(true);
  });

  it("rechaza lo que no puede ser una zona", () => {
    expect(isTimeZoneShape("")).toBe(false);
    expect(isTimeZoneShape("a b")).toBe(false);
    expect(isTimeZoneShape("x".repeat(65))).toBe(false);
    expect(isTimeZoneShape(null)).toBe(false);
  });
});

describe("normalizeToday (regla ÚNICA de validación, compartida con /api/assistant)", () => {
  const ahora = new Date("2026-08-05T00:05:00.000Z");

  it("acepta un día real dentro de ±2 días del UTC del server", () => {
    expect(normalizeToday("2026-08-04", ahora)).toBe("2026-08-04");
    expect(normalizeToday("2026-08-06", ahora)).toBe("2026-08-06");
    expect(normalizeToday("2026-08-07", ahora)).toBe("2026-08-07");
  });

  it("cae al UTC del server si la fecha está lejos, es irreal o está mal formada", () => {
    expect(normalizeToday("2020-01-01", ahora)).toBe("2026-08-05"); // fabricada
    expect(normalizeToday("2026-02-30", ahora)).toBe("2026-08-05"); // no existe
    expect(normalizeToday("05/08/2026", ahora)).toBe("2026-08-05"); // formato
    expect(normalizeToday(undefined, ahora)).toBe("2026-08-05");
    expect(normalizeToday(null, ahora)).toBe("2026-08-05");
    expect(normalizeToday(20260805, ahora)).toBe("2026-08-05");
  });
});

describe("todayFromTimeZoneCookie", () => {
  const instante = new Date("2026-08-05T00:05:00.000Z"); // 21:05 del 4 en AR

  it("da el día local del usuario cuando la cookie es una zona válida", () => {
    expect(todayFromTimeZoneCookie(AR, instante)).toBe("2026-08-04");
  });

  it("sin cookie cae al UTC del server (comportamiento previo: nunca rompe)", () => {
    expect(todayFromTimeZoneCookie(undefined, instante)).toBe("2026-08-05");
    expect(todayFromTimeZoneCookie("", instante)).toBe("2026-08-05");
  });

  it("con cookie forjada o inválida cae al UTC del server", () => {
    expect(todayFromTimeZoneCookie("Marte/Olympus", instante)).toBe("2026-08-05");
    expect(todayFromTimeZoneCookie({ tz: AR }, instante)).toBe("2026-08-05");
  });

  it("una zona real nunca puede correr la fecha más de un día", () => {
    // El clamp de ±2 días de `normalizeToday` cubre de UTC-12 a UTC+14.
    for (const tz of ["Etc/GMT+12", "Pacific/Kiritimati", "Europe/Madrid", "Asia/Tokyo"]) {
      const dia = todayFromTimeZoneCookie(tz, instante);
      const delta =
        Math.abs(dayStartUtc(dia).getTime() - dayStartUtc(utcToday(instante)).getTime()) /
        86_400_000;
      expect(delta).toBeLessThanOrEqual(1);
    }
  });
});

describe("resolveYm — mes por defecto el ÚLTIMO DÍA del mes a las 21:00 (UTC-3)", () => {
  // 2026-08-31 21:05 en Buenos Aires = 2026-09-01 00:05 UTC.
  // Es el caso que rompía todos los fines de mes: el usuario abría el dashboard
  // con 3 horas de agosto por delante y le mostrábamos septiembre en $0.
  const instante = new Date("2026-09-01T00:05:00.000Z");

  it("el reloj del server (UTC) ya está en el mes siguiente — el bug", () => {
    expect(monthOf(utcToday(instante))).toBe("2026-09");
  });

  it("con la zona del usuario el default sigue siendo agosto", () => {
    const hoy = todayFromTimeZoneCookie(AR, instante);
    expect(hoy).toBe("2026-08-31");
    expect(resolveYm(undefined, hoy)).toBe("2026-08");
  });

  it("mismo borde el 31 de diciembre: el AÑO tampoco se adelanta", () => {
    const nochevieja = new Date("2027-01-01T00:05:00.000Z"); // 31/12 21:05 en AR
    const hoy = todayFromTimeZoneCookie(AR, nochevieja);
    expect(hoy).toBe("2026-12-31");
    expect(resolveYm(undefined, hoy)).toBe("2026-12");
    expect(Number(hoy.slice(0, 4))).toBe(2026);
  });

  it("sin cookie mantiene el comportamiento viejo (UTC): no rompe, sólo no mejora", () => {
    expect(resolveYm(undefined, todayFromTimeZoneCookie(undefined, instante))).toBe(
      "2026-09",
    );
  });

  it("un `?ym=` válido siempre gana sobre el mes actual", () => {
    const hoy = todayFromTimeZoneCookie(AR, instante);
    expect(resolveYm("2026-03", hoy)).toBe("2026-03");
  });

  it("un `?ym=` con basura se ignora y cae al mes del usuario", () => {
    const hoy = todayFromTimeZoneCookie(AR, instante);
    expect(resolveYm("2026-3", hoy)).toBe("2026-08");
    expect(resolveYm("bla", hoy)).toBe("2026-08");
    expect(resolveYm("", hoy)).toBe("2026-08");
  });
});

describe("splitYm / dayStartUtc", () => {
  it("splitYm devuelve [año, mes 1-12] y sirve para YYYY-MM y YYYY-MM-DD", () => {
    expect(splitYm("2026-08")).toEqual([2026, 8]);
    expect(splitYm("2026-08-31")).toEqual([2026, 8]);
  });

  it("dayStartUtc ancla en la medianoche UTC del día pedido", () => {
    expect(dayStartUtc("2026-08-31").toISOString()).toBe("2026-08-31T00:00:00.000Z");
  });
});
