// MetaCasa — servicio de conversión de monedas (FX).
// Cache in-memory por día/par.
// TODO Fase 2+: delegar a `public.latest_fx_rate(base, quote)` en Supabase
// o a edge function que consulte Open Exchange Rates.

const _fxCache = {};

/**
 * Obtiene la tasa de cambio desde `from` a ARS.
 * - `from === 'ARS'` → { rate: 1, ... }
 * - `manualRate > 0` → usa la tasa manual del usuario.
 * - Fallback: { rate: 0, status: 'ESTIMATED' }.
 * @param {string} from - Código ISO (USD, EUR, etc.)
 * @param {string} dateStr - YYYY-MM-DD
 * @param {number} manualRate - Tasa manual configurada por el usuario.
 */
export async function fxGetRate(from, dateStr, manualRate) {
  if (from === 'ARS') return { rate: 1, source: 'MANUAL', status: 'FINAL' };

  const cacheKey = `${from}:ARS:${dateStr}`;
  if (_fxCache[cacheKey]) return _fxCache[cacheKey];

  if (manualRate && manualRate > 0) {
    const result = { rate: manualRate, source: 'MANUAL', status: 'FINAL' };
    _fxCache[cacheKey] = result;
    return result;
  }

  return { rate: 0, source: 'MANUAL', status: 'ESTIMATED' };
}
