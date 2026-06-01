"use server";

/**
 * Auto-ejecución de movimientos recurrentes ("recurrentes ejecutándose").
 *
 * iOS jamás materializó los recurrentes en el server (su `RecurringService` solo
 * crea/pausa/borra el template). La web agrega esa pieza: convierte cada
 * recurrente vencido (`active=true` y `next_date <= hoy`) en un movimiento REAL
 * vía el insert canónico (`createTransaction`), poniéndose al día si pasaron
 * varios períodos, y avanza `next_date` con `computeNextDate` (la MISMA
 * semántica de recurrencia que iOS: +1d/+7d/+1mes/+1año) hasta dejarla en el
 * futuro.
 *
 * IDEMPOTENCIA (clave para no doble-postear):
 *  - El "candado" es `next_date`: por cada período que generamos, lo avanzamos y
 *    al final lo PERSISTIMOS. Una segunda corrida ya no encuentra nada vencido.
 *  - El avance + el insert van acotados: si una fila quedó muy atrás (meses sin
 *    abrir la app), generamos como mucho `MAX_CATCHUP` movimientos y dejamos
 *    `next_date` en su valor avanzado (sin saltearlo) para que el resto se
 *    procese en corridas siguientes — nunca generamos un período dos veces.
 *  - Cada movimiento se fecha en el `next_date` que le corresponde (no "hoy"),
 *    así el período/mes del movimiento queda correcto para reportes.
 *
 * Respeta RLS + hogar activo. No loguea montos, categorías ni notas.
 */

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import {
  listRecurring,
  updateRecurring,
  computeNextDate,
  isFrequency,
  type RecurringTransaction,
} from "@/lib/db/recurring";
import { createTransaction } from "@/lib/db/transactions";
import { TX_TYPE, type TxType } from "@/lib/constants";

/**
 * Tope de movimientos generados por recurrente en una sola corrida. Cota de
 * seguridad ante una fila muy atrasada (p.ej. diaria sin tocar la app por meses):
 * 24 cubre 2 años de mensuales / ~24 días de diarias por pasada. El resto se
 * pone al día en corridas posteriores (sigue siendo idempotente).
 */
const MAX_CATCHUP = 24;

/** Resultado de la corrida. `created` = movimientos materializados en total. */
export interface RunDueRecurringResult {
  /** Cantidad de movimientos reales creados en esta corrida. */
  created: number;
  /** Cuántos recurrentes vencidos se procesaron (al menos uno generó). */
  processed: number;
}

/** Hoy en "YYYY-MM-DD" (UTC), misma base que `computeNextDate` y `next_date`. */
function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}

/**
 * Materializa los recurrentes vencidos del hogar activo. Idempotente: solo actúa
 * sobre los que tienen `next_date <= hoy`, y deja `next_date` por delante.
 * Devuelve cuántos movimientos creó (0 si no había nada vencido).
 */
export async function runDueRecurring(): Promise<RunDueRecurringResult> {
  const t = await getT();
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionInvalid"));
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));

  const householdId = active.id;
  const userId = user.id;
  const baseCurrency = active.default_currency;
  const today = todayISO();

  // Solo activos; `next_date` ascendente. Filtramos los vencidos en memoria
  // (la lista del hogar es chica y así no dependemos de comparaciones de fecha
  // en el servidor PostgREST con formatos mixtos).
  const recurrings = await listRecurring(supabase, householdId, { activeOnly: true });

  let created = 0;
  let processed = 0;

  for (const r of recurrings) {
    const result = await runOne(supabase, {
      recurring: r,
      userId,
      householdId,
      baseCurrency,
      today,
    });
    if (result.created > 0) processed += 1;
    created += result.created;
  }

  if (created > 0) {
    // Refrescamos las vistas que dependen de los movimientos materializados.
    revalidatePath("/dashboard");
    revalidatePath("/recurring");
    revalidatePath("/transactions");
  }

  return { created, processed };
}

/**
 * Procesa UN recurrente: genera los movimientos vencidos (acotado a
 * `MAX_CATCHUP`) y persiste el `next_date` avanzado. Si `next_date` es nulo o la
 * frecuencia es inválida, lo salta sin tocar nada. No crea movimientos más allá
 * de `end_date` (inclusive).
 */
async function runOne(
  supabase: Awaited<ReturnType<typeof createClient>>,
  args: {
    recurring: RecurringTransaction;
    userId: string;
    householdId: string;
    baseCurrency: string;
    today: string;
  },
): Promise<{ created: number }> {
  const { recurring: r, userId, householdId, baseCurrency, today } = args;

  if (!r.next_date) return { created: 0 };
  if (!isFrequency(r.frequency)) return { created: 0 };
  const frequency = r.frequency;

  // El tipo se valida contra el dominio canónico (GASTO / INGRESO).
  const type: TxType | null =
    r.type === TX_TYPE.EXPENSE
      ? TX_TYPE.EXPENSE
      : r.type === TX_TYPE.INCOME
        ? TX_TYPE.INCOME
        : null;
  if (!type) return { created: 0 };

  const amount = Number(r.amount);
  if (!Number.isFinite(amount) || amount <= 0) return { created: 0 };

  const endDate = r.end_date || null;
  let cursor = r.next_date; // "YYYY-MM-DD"
  let created = 0;

  // Genera mientras esté vencido (<= hoy), dentro del período de vigencia, y sin
  // superar el tope de catch-up. Cada iteración crea el movimiento del `cursor`
  // y avanza al siguiente período.
  while (cursor <= today && created < MAX_CATCHUP) {
    if (endDate && cursor > endDate) break; // ya terminó: no generamos más

    await createTransaction(supabase, {
      householdId,
      userId,
      type,
      amount, // ya en moneda base del hogar (igual que el resto del dashboard)
      category: r.category,
      accountId: null, // los recurrentes no fijan cuenta destino en el schema actual
      date: cursor, // se fecha en el período que corresponde, no "hoy"
      note: r.note ?? null,
      // El recurrente guarda el monto en moneda base → original == base, fx = 1.
      amountOriginal: amount,
      currencyOriginal: baseCurrency,
      fxRateToBase: 1,
    });

    created += 1;
    cursor = computeNextDate(cursor, frequency);
  }

  // Persistimos el avance solo si hubo cambios (idempotencia: el candado queda
  // por delante). Si el recurrente ya terminó su vigencia, lo pausamos.
  if (created > 0) {
    const finished = endDate != null && cursor > endDate;
    await updateRecurring(supabase, r.id, householdId, {
      next_date: cursor,
      ...(finished ? { active: false } : {}),
    });
  }

  return { created };
}
