import "server-only";
import { cookies } from "next/headers";
import { cache } from "react";
import { BALANCE_PRIVACY_COOKIE, isHidden } from "./balance-privacy";

/**
 * ¿El visitante pidió ocultar los saldos? Cacheado por request, igual patrón que `getTheme`.
 *
 * Se lee en el layout para poder marcar `<html>` desde el servidor: si esto se resolviera en el
 * cliente, la primera pintura mostraría los montos reales.
 */
export const getBalancesHidden = cache(async (): Promise<boolean> => {
  return isHidden((await cookies()).get(BALANCE_PRIVACY_COOKIE)?.value);
});
