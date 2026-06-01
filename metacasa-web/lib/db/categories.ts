import type { Client } from "@/lib/supabase/types";
import type { Json } from "@/lib/database.types";

/** Estructura del jsonb `categories.data` (espeja iOS). */
export interface CategoryData {
  gastos?: string[];
  ingresos?: string[];
  [key: string]: unknown;
}

/**
 * Categorías por defecto para hogares nuevos (la tabla arranca vacía). Sin esto,
 * un usuario recién creado no podría cargar un movimiento (no habría categorías).
 * iOS hace este merge client-side; acá lo hacemos en getCategories.
 */
export const DEFAULT_CATEGORIES: Required<Pick<CategoryData, "gastos" | "ingresos">> = {
  gastos: [
    "Supermercado",
    "Alquiler",
    "Servicios",
    "Transporte",
    "Restaurantes",
    "Salud",
    "Ocio",
    "Educación",
    "Ropa",
    "Otros",
  ],
  ingresos: ["Sueldo", "Freelance", "Inversiones", "Reintegro", "Otros"],
};

/**
 * Categorías efectivas del hogar: las guardadas, o el set por defecto si todavía
 * no cargó ninguna. Garantiza que los selectores (movimientos, presupuesto)
 * nunca queden vacíos.
 */
export async function getCategories(
  supabase: Client,
  householdId: string,
): Promise<CategoryData> {
  const { data } = await supabase
    .from("categories")
    .select("data")
    .eq("household_id", householdId)
    .maybeSingle();
  const stored = (data?.data as CategoryData) ?? {};
  return {
    gastos: stored.gastos?.length ? stored.gastos : DEFAULT_CATEGORIES.gastos,
    ingresos: stored.ingresos?.length ? stored.ingresos : DEFAULT_CATEGORIES.ingresos,
  };
}

/**
 * Guarda el jsonb completo de categorías del hogar (upsert por `household_id`,
 * que es único 1:1). `user_id` es obligatorio: usamos quién editó por último.
 */
export async function upsertCategories(
  supabase: Client,
  params: { userId: string; householdId: string; data: CategoryData },
): Promise<void> {
  const { error } = await supabase.from("categories").upsert(
    {
      user_id: params.userId,
      household_id: params.householdId,
      data: params.data as unknown as Json,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "household_id" },
  );
  if (error) throw error;
}
