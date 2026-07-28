/**
 * Política de caché del service worker (ítem 4.8), como lógica PURA.
 *
 * Vive en `lib/` y no en `app/sw.ts` para poder testearla con vitest: es la
 * parte del PWA donde un error se paga caro (mostrar saldos viejos como si
 * fueran actuales, o servir una página cacheada en lugar del redirect al login).
 *
 * Regla de oro de esta app: **nunca** persistimos una respuesta que contenga
 * plata. Offline preferimos la página `/~offline` antes que números viejos sin
 * aviso.
 */

/** Ruta del fallback offline (también es el `url` del `fallbacks` de Serwist). */
export const OFFLINE_PATH = "/~offline";

/**
 * Prefijos que NUNCA se cachean, ni siquiera como último recurso:
 * - `/api/*`  → export/import/asistente: datos financieros crudos.
 * - `/auth/*` → callbacks, handoff y confirm: dependen de cookies y de redirects
 *   frescos; una respuesta cacheada acá rompe el login.
 */
export const NEVER_CACHE_PREFIXES = ["/api", "/auth"] as const;

/**
 * Páginas SIN datos financieros. Son las únicas que pueden quedar guardadas en
 * el caché de navegación. Todo lo demás (dashboard, movimientos, cuentas,
 * presupuestos, reportes, metas, deudas…) queda fuera a propósito.
 */
export const CACHEABLE_PAGES = new Set<string>([
  "/", // landing de marketing
  "/login",
  "/register",
  "/forgot-password",
  "/reset-password",
  OFFLINE_PATH,
]);

/** Normaliza el pathname: sin querystring y sin barra final (salvo la raíz). */
function normalize(pathname: string): string {
  const clean = pathname.split("?")[0].split("#")[0];
  if (clean.length > 1 && clean.endsWith("/")) return clean.slice(0, -1);
  return clean || "/";
}

/** `true` si la request no debe tocar el caché bajo ninguna circunstancia. */
export function isNeverCachePath(pathname: string): boolean {
  const p = normalize(pathname);
  return NEVER_CACHE_PREFIXES.some((pre) => p === pre || p.startsWith(pre + "/"));
}

/**
 * `true` si esa navegación puede quedar guardada. Sólo las páginas públicas
 * listadas arriba: las rutas de la app llevan saldos renderizados en el HTML.
 */
export function isCacheablePage(pathname: string): boolean {
  const p = normalize(pathname);
  if (isNeverCachePath(p)) return false;
  return CACHEABLE_PAGES.has(p);
}

/** `true` si el host es de Supabase (API de datos financieros: jamás al caché). */
export function isSupabaseHost(hostname: string): boolean {
  const h = hostname.toLowerCase();
  return h.endsWith(".supabase.co") || h.endsWith(".supabase.in");
}

/**
 * Guarda final antes de escribir una navegación en el caché (`cacheWillUpdate`).
 *
 * Rechaza:
 * - rutas con plata o de auth/api (ver arriba);
 * - cualquier cosa que no sea un 200 limpio y de nuestro origen — en particular
 *   los `opaqueredirect` (status 0) que produce el middleware cuando manda al
 *   login: si guardáramos eso bajo la URL original, el SW serviría una página
 *   en lugar del redirect y el gate de auth quedaría roto;
 * - respuestas que siguieron un redirect (`redirected`), por el mismo motivo.
 */
export function shouldCachePage(input: {
  pathname: string;
  status: number;
  redirected: boolean;
  /** `Response.type`: sólo aceptamos `basic` (mismo origen, sin redirect). */
  type?: string;
}): boolean {
  if (!isCacheablePage(input.pathname)) return false;
  if (input.status !== 200) return false;
  if (input.redirected) return false;
  if (input.type !== undefined && input.type !== "basic") return false;
  return true;
}
