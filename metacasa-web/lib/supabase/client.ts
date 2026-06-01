import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "@/lib/database.types";

/**
 * Cliente Supabase para componentes de cliente ("use client").
 * Usa la publishable key (segura en el browser). Misma sesión por cookies
 * que el cliente de servidor (gracias a @supabase/ssr).
 */
export function createClient() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
