import "server-only";
import { cache } from "react";
import { createClient } from "@/lib/supabase/server";

export type AccessState = "trial" | "active" | "locked";

export interface WebAccess {
  state: AccessState;
  trial_ends_at?: string | null;
  has_subscription?: boolean;
  in_trial?: boolean;
  reason?: string;
}

/**
 * Estado de acceso web del usuario actual (server-side, fuente de verdad).
 * - trial: dentro de los 7 días.
 * - active: suscripción premium activa (RevenueCat).
 * - locked: trial vencido y sin suscripción → paywall "seguí en la app".
 *
 * Deduplicado por request con React `cache` (layout + page lo comparten).
 */
export const getAccessState = cache(async (): Promise<WebAccess> => {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("web_access_state");
  if (error || !data) return { state: "locked", reason: "rpc_error" };
  return data as unknown as WebAccess;
});

export function daysUntil(iso?: string | null): number {
  if (!iso) return 0;
  const ms = new Date(iso).getTime() - Date.now();
  return Math.max(0, Math.ceil(ms / 86_400_000));
}
