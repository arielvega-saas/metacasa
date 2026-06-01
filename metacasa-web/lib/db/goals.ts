import type { Client } from "@/lib/supabase/types";
import type { Tables, TablesUpdate } from "@/lib/database.types";

export type Goal = Tables<"goals">;

/** Metas del hogar (por prioridad). `activeOnly` filtra status=active. */
export async function listGoals(
  supabase: Client,
  householdId: string,
  opts: { activeOnly?: boolean; limit?: number } = {},
): Promise<Goal[]> {
  let q = supabase.from("goals").select("*").eq("household_id", householdId);
  if (opts.activeOnly) q = q.eq("status", "active");
  q = q
    .order("priority", { ascending: false })
    .order("created_at", { ascending: true });
  if (opts.limit) q = q.limit(opts.limit);

  const { data, error } = await q;
  if (error) throw error;
  return data ?? [];
}

// ── Mutaciones (agregadas para la pantalla /goals) ────────────────────────────

/**
 * Crea una meta de ahorro. `created_by` debe ser el usuario actual (lo exige RLS).
 * El `current_amount` inicial es opcional (saldo ya ahorrado al crear la meta).
 */
export async function createGoal(
  supabase: Client,
  input: {
    householdId: string;
    createdBy: string;
    name: string;
    targetAmount: number;
    currentAmount?: number;
    currency: string;
    targetDate?: string | null;
    icon?: string | null;
    category?: string | null;
  },
): Promise<Goal> {
  const { data, error } = await supabase
    .from("goals")
    .insert({
      household_id: input.householdId,
      created_by: input.createdBy,
      name: input.name,
      target_amount: input.targetAmount,
      current_amount: input.currentAmount ?? 0,
      currency: input.currency,
      target_date: input.targetDate ?? null,
      icon: input.icon ?? null,
      category: input.category ?? null,
    })
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/**
 * Actualiza campos editables de una meta (nombre, objetivo, fecha, estado, etc.).
 * OJO: no toca `current_amount` (lo maneja el trigger de contribuciones).
 */
export async function updateGoal(
  supabase: Client,
  goalId: string,
  patch: TablesUpdate<"goals">,
): Promise<Goal> {
  const { data, error } = await supabase
    .from("goals")
    .update(patch)
    .eq("id", goalId)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/**
 * Registra una contribución a una meta. El trigger `tg_goal_contribution_apply`
 * suma el monto a `goals.current_amount` y autocompleta la meta si llega al objetivo,
 * así que acá SOLO insertamos la contribución (nunca sumamos manualmente al goal).
 */
export async function addContribution(
  supabase: Client,
  input: {
    goalId: string;
    amount: number;
    contributedBy: string;
    notes?: string | null;
  },
): Promise<void> {
  const { error } = await supabase.from("goal_contributions").insert({
    goal_id: input.goalId,
    amount: input.amount,
    contributed_by: input.contributedBy,
    notes: input.notes ?? null,
  });
  if (error) throw error;
}
