"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { ACTIVE_HOUSEHOLD_COOKIE } from "@/lib/constants";

/** Opciones de la cookie de hogar activo (httpOnly + secure en prod). */
const COOKIE_OPTS = {
  path: "/",
  maxAge: 60 * 60 * 24 * 365,
  sameSite: "lax" as const,
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
};

/** Cambia el hogar activo (cookie) y refresca el árbol. */
export async function setActiveHousehold(id: string) {
  const cookieStore = await cookies();
  cookieStore.set(ACTIVE_HOUSEHOLD_COOKIE, id, COOKIE_OPTS);
  revalidatePath("/", "layout");
}

/** Crea un hogar nuevo (onboarding) vía RPC server-side. */
export async function createHousehold(name: string, currency = "USD") {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("create_household", {
    p_name: name || "Mi Hogar",
    p_currency: currency,
  });
  if (error) throw new Error(error.message);
  if (data?.id) {
    const cookieStore = await cookies();
    cookieStore.set(ACTIVE_HOUSEHOLD_COOKIE, data.id, COOKIE_OPTS);
  }
  revalidatePath("/", "layout");
  return data;
}
