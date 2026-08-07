"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { TZ_COOKIE, TZ_COOKIE_MAX_AGE, isTimeZoneShape } from "@/lib/today";

/**
 * Publica la zona horaria del navegador en la cookie `mc_tz` para que los Server
 * Components sepan qué día es HOY para el usuario.
 *
 * Por qué un componente cliente y no otra cosa:
 *  - Un Server Component no puede escribir cookies (Next 15), y el server corre
 *    con `TZ=UTC` en Netlify, así que su reloj no sirve para decidir el día.
 *  - El middleware tampoco lo sabe: la zona sólo existe en el browser.
 *  - `Intl.DateTimeFormat().resolvedOptions().timeZone` no pide permisos ni usa
 *    geo-IP; es la configuración del propio sistema del usuario.
 *
 * Se re-escribe en cada montaje para renovar el `max-age`, pero sólo pedimos un
 * `router.refresh()` cuando el server rindió con OTRA zona (o sin cookie): así la
 * primera visita se corrige sola y las siguientes no pagan un render extra.
 *
 * Sin UI: devuelve `null`.
 */
export function TimezoneCookie() {
  const router = useRouter();

  useEffect(() => {
    let tz: string | undefined;
    try {
      tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    } catch {
      return; // runtime sin ICU completo: nos quedamos con el fallback UTC
    }
    // Se valida ANTES de escribir con la misma forma que exige el lector server.
    if (!isTimeZoneShape(tz)) return;

    const previa = document.cookie
      .split("; ")
      .find((c) => c.startsWith(`${TZ_COOKIE}=`))
      ?.slice(TZ_COOKIE.length + 1);

    const secure = location.protocol === "https:" ? "; secure" : "";
    document.cookie = `${TZ_COOKIE}=${tz}; path=/; max-age=${TZ_COOKIE_MAX_AGE}; samesite=lax${secure}`;

    // El HTML que estamos viendo se armó sin esta zona → volver a pedirlo.
    if (previa !== tz) router.refresh();
  }, [router]);

  return null;
}
