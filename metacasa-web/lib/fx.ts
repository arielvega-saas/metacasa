/**
 * Conversión multi-moneda — puerto directo de iOS `Core/FXService.swift`
 * (`FXRate`, `FXRateMap`, `FXConverter`).
 *
 * Fuente de la verdad: la columna JSONB `households.fx_rates`. NO usamos la
 * tabla `fx_rates` (existe en el schema pero la app iOS no la consume; mantener
 * paridad significa leer el mismo JSONB que lee iOS).
 *
 * Forma del JSONB (igual que iOS):
 *   { "USD": { "rate": 1000, "updated_at": "2026-05-30T…", "source": "manual" }, … }
 *
 * Convención (idéntica a iOS `FXConverter.convert`): la `rate` dice "cuántas
 * unidades de la moneda BASE del hogar equivalen a 1 unidad de ESTA moneda".
 * Conversión multiplicativa: `montoBase = amount * rate`. Si `from === base`
 * devuelve el monto tal cual. Si falta la tasa, devuelve `null` (igual que iOS,
 * que devuelve `nil`) para que el caller decida cómo manejar el dato faltante.
 */

/** Una tasa puntual tal como vive en el JSONB (mismas claves que iOS). */
export interface FXRate {
  rate: number;
  updated_at?: string;
  source?: string;
}

/** Mapa de tasas del hogar. Clave = código ISO en MAYÚSCULAS (USD, EUR, BRL…). */
export type FXRateMap = Record<string, FXRate>;

/**
 * Normaliza el JSONB crudo de `households.fx_rates` a un `FXRateMap` tipado.
 * Tolera:
 *  - valores numéricos directos `{ "USD": 1000 }` (forma simplificada),
 *  - objetos `{ "USD": { rate: 1000, … } }` (forma canónica iOS),
 *  - basura/no-objetos → se ignoran.
 * Las claves se llevan a mayúsculas para hacer el lookup case-insensitive.
 */
export function parseFxRates(raw: unknown): FXRateMap {
  if (!raw || typeof raw !== "object") return {};
  const out: FXRateMap = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    const code = key.toUpperCase();
    if (typeof value === "number" && Number.isFinite(value)) {
      out[code] = { rate: value };
    } else if (value && typeof value === "object") {
      const r = (value as { rate?: unknown }).rate;
      const rate = typeof r === "number" ? r : Number(r);
      if (Number.isFinite(rate)) {
        out[code] = {
          rate,
          updated_at: (value as { updated_at?: string }).updated_at,
          source: (value as { source?: string }).source,
        };
      }
    }
  }
  return out;
}

/**
 * Convierte `amount` desde `from` a la moneda `base` usando el mapa del hogar.
 * Puerto 1:1 de iOS `FXConverter.convert`:
 *  - `from === base` → `amount` (sin conversión).
 *  - tasa disponible → `amount * rate` (convención multiplicativa).
 *  - tasa ausente → `null`.
 */
export function convertToBase(
  amount: number,
  from: string,
  base: string,
  rates: FXRateMap,
): number | null {
  const f = (from || "").toUpperCase();
  const b = (base || "").toUpperCase();
  if (f === b) return amount;
  const r = rates[f];
  if (!r || !Number.isFinite(r.rate)) return null;
  return amount * r.rate;
}

/** `true` si toda moneda en `currencies` puede convertirse a `base` (o ya es base). */
export function canConvertAll(
  currencies: Iterable<string>,
  base: string,
  rates: FXRateMap,
): boolean {
  const b = (base || "").toUpperCase();
  for (const c of currencies) {
    const code = (c || "").toUpperCase();
    if (code === b) continue;
    if (!rates[code]) return false;
  }
  return true;
}
