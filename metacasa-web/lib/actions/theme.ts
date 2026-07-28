"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { THEME_COOKIE, THEME_COOKIE_MAX_AGE, isTheme } from "@/lib/theme";

/**
 * Persiste la preferencia de tema (system | light | dark) en cookie y refresca
 * el árbol para que `<html>` se re-renderice con la clase correcta.
 *
 * Cookie (no localStorage) a propósito: el layout es Server Component y tiene
 * que poder decidir la clase ANTES de mandar el HTML — así no hay flash.
 */
export async function setTheme(theme: string) {
  if (!isTheme(theme)) return;
  const cookieStore = await cookies();
  cookieStore.set(THEME_COOKIE, theme, {
    path: "/",
    maxAge: THEME_COOKIE_MAX_AGE,
    sameSite: "lax",
  });
  revalidatePath("/", "layout");
}
