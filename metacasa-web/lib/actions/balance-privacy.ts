"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import {
  BALANCE_PRIVACY_COOKIE,
  BALANCE_PRIVACY_MAX_AGE,
} from "@/lib/balance-privacy";

/**
 * Alterna el modo "ocultar saldos" y refresca el árbol para que `<html>` salga marcado.
 *
 * Recibe el valor deseado en vez de leer y negar: si dos pestañas alternan a la vez, un toggle
 * ciego puede terminar dejándolas en estados opuestos al que el usuario tocó.
 */
export async function setBalancesHidden(hidden: boolean) {
  const cookieStore = await cookies();
  cookieStore.set(BALANCE_PRIVACY_COOKIE, hidden ? "1" : "0", {
    path: "/",
    maxAge: BALANCE_PRIVACY_MAX_AGE,
    sameSite: "lax",
  });
  revalidatePath("/", "layout");
}
