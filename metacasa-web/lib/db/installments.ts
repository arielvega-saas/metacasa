import type { Client } from "@/lib/supabase/types";
import type { Tables, TablesInsert } from "@/lib/database.types";

export type InstallmentPlan = Tables<"installment_plans">;
export type InstallmentPayment = Tables<"installment_payments">;

/**
 * Plan de cuotas con el progreso ya calculado a partir de sus
 * `installment_payments`. Espeja la semántica de iOS (`InstallmentService` +
 * `InstallmentPlan`): el progreso surge del ledger de pagos, no de campos
 * denormalizados. `monthlyAmount` = total / cuotas (reparto parejo, idéntico a
 * `InstallmentPlan.monthlyAmount` en Swift).
 */
export interface PlanWithProgress extends InstallmentPlan {
  /** Cuotas marcadas como pagadas. */
  paidCount: number;
  /** Suma de los montos de las cuotas pagadas (moneda del plan). */
  paidAmount: number;
  /** Total − pagado (nunca negativo). */
  remainingAmount: number;
  /** 0–100, redondeado, sobre la cantidad de cuotas. */
  progressPct: number;
  /** Monto por cuota (reparto parejo). */
  monthlyAmount: number;
  /** Próxima cuota impaga (year/month/number) o null si está saldado. */
  nextDue: { year: number; month: number; number: number } | null;
}

/**
 * Planes del hogar con su progreso. Trae los planes y, en una sola query, todos
 * los pagos de esos planes; agrega en memoria (mismo patrón que
 * `listAccountsWithBalance`). Ordena por `created_at` desc, igual que iOS
 * (`fetchPlans` → order created_at descending).
 */
export async function listPlans(
  supabase: Client,
  householdId: string,
): Promise<PlanWithProgress[]> {
  const { data: plans, error } = await supabase
    .from("installment_plans")
    .select("*")
    .eq("household_id", householdId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  const list = plans ?? [];
  if (list.length === 0) return [];

  const planIds = list.map((p) => p.id);
  const { data: payments, error: payErr } = await supabase
    .from("installment_payments")
    .select("plan_id, installment_number, period_year, period_month, amount, paid")
    .in("plan_id", planIds);
  if (payErr) throw payErr;

  const byPlan = new Map<string, InstallmentPaymentLite[]>();
  for (const p of payments ?? []) {
    const arr = byPlan.get(p.plan_id) ?? [];
    arr.push(p);
    byPlan.set(p.plan_id, arr);
  }

  return list.map((plan) => {
    const rows = byPlan.get(plan.id) ?? [];
    const total = Number(plan.total_amount);
    const count = Math.max(1, plan.total_installments);
    const monthlyAmount = total / count;

    let paidCount = 0;
    let paidAmount = 0;
    for (const r of rows) {
      if (r.paid) {
        paidCount += 1;
        paidAmount += Number(r.amount);
      }
    }

    // Próxima cuota impaga = la de menor installment_number sin pagar.
    const nextRow = rows
      .filter((r) => !r.paid)
      .sort((a, b) => a.installment_number - b.installment_number)[0];

    return {
      ...plan,
      paidCount,
      paidAmount,
      remainingAmount: Math.max(0, total - paidAmount),
      progressPct: Math.min(100, Math.round((paidCount / count) * 100)),
      monthlyAmount,
      nextDue: nextRow
        ? {
            year: nextRow.period_year,
            month: nextRow.period_month,
            number: nextRow.installment_number,
          }
        : null,
    };
  });
}

/** Subconjunto de columnas de pago que usamos para agregar el progreso. */
type InstallmentPaymentLite = Pick<
  InstallmentPayment,
  "plan_id" | "installment_number" | "period_year" | "period_month" | "amount" | "paid"
>;

/**
 * Cronograma completo de pagos de un plan, ordenado por número de cuota
 * (idéntico a iOS `fetchPayments` → order installment_number asc).
 */
export async function listPayments(
  supabase: Client,
  planId: string,
): Promise<InstallmentPayment[]> {
  const { data, error } = await supabase
    .from("installment_payments")
    .select("*")
    .eq("plan_id", planId)
    .order("installment_number", { ascending: true });
  if (error) throw error;
  return data ?? [];
}

/**
 * Inserta el plan. Los campos los arma la server action (household_id,
 * created_by, currency, etc.). Devuelve el plan creado para sembrar sus pagos.
 */
export async function createPlanRow(
  supabase: Client,
  input: TablesInsert<"installment_plans">,
): Promise<InstallmentPlan> {
  const { data, error } = await supabase
    .from("installment_plans")
    .insert(input)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/**
 * Siembra las N filas de `installment_payments` de un plan. Reparto parejo del
 * total entre las cuotas y períodos consecutivos a partir de start_year/month,
 * EXACTAMENTE como iOS (`seedPayments` + `periodFor(installment:)`):
 *   periodFor(n) = start + (n - 1) meses.
 * Inserta en una sola llamada (un array). RLS valida pertenencia por fila.
 */
export async function seedPayments(
  supabase: Client,
  plan: InstallmentPlan,
): Promise<void> {
  const count = Math.max(1, plan.total_installments);
  const total = Number(plan.total_amount);
  const monthly = total / count;

  const rows: TablesInsert<"installment_payments">[] = [];
  for (let n = 1; n <= count; n++) {
    const { year, month } = periodFor(plan.start_year, plan.start_month, n);
    rows.push({
      plan_id: plan.id,
      period_year: year,
      period_month: month,
      installment_number: n,
      amount: monthly,
    });
  }

  const { error } = await supabase.from("installment_payments").insert(rows);
  if (error) throw error;
}

/**
 * Período (año, mes) de la cuota `n` (1-indexed) a partir del inicio del plan.
 * Aritmética por meses, idéntica a `InstallmentPlan.periodFor` en Swift.
 */
function periodFor(
  startYear: number,
  startMonth: number,
  n: number,
): { year: number; month: number } {
  const offset = n - 1;
  let y = startYear;
  let m = startMonth + offset;
  while (m > 12) {
    m -= 12;
    y += 1;
  }
  while (m < 1) {
    m += 12;
    y -= 1;
  }
  return { year: y, month: m };
}

/** Marca/desmarca una cuota como pagada. RLS valida pertenencia (vía plan). */
export async function setPaymentPaid(
  supabase: Client,
  paymentId: string,
  paid: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("installment_payments")
    .update({
      paid,
      // iOS escribe paid_at al marcar; lo limpiamos al desmarcar.
      paid_at: paid ? new Date().toISOString() : null,
    })
    .eq("id", paymentId);
  if (error) throw error;
}

/** Elimina un plan. ON DELETE CASCADE borra sus pagos (igual que iOS). */
export async function deletePlanRow(
  supabase: Client,
  planId: string,
): Promise<void> {
  const { error } = await supabase
    .from("installment_plans")
    .delete()
    .eq("id", planId);
  if (error) throw error;
}
