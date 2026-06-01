import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";

/** Cliente Supabase tipado con nuestro schema. */
export type Client = SupabaseClient<Database>;
