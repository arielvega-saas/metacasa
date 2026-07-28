/// <reference lib="webworker" />
import {
  CacheFirst,
  ExpirationPlugin,
  NetworkFirst,
  NetworkOnly,
  Serwist,
  type PrecacheEntry,
  type RuntimeCaching,
  type SerwistGlobalConfig,
} from "serwist";
import {
  OFFLINE_PATH,
  isNeverCachePath,
  isSupabaseHost,
  shouldCachePage,
} from "../lib/pwa/routes";

/**
 * Service worker de Home Finance (ítem 4.8) — compilado por `@serwist/next`
 * (`swSrc: "app/sw.ts"` → `public/sw.js`).
 *
 * ── Postura de caché ─────────────────────────────────────────────────────────
 * Es una app de PLATA: mostrar saldos viejos como si fueran actuales es peor que
 * un error honesto. Por eso NO usamos `defaultCache` de `@serwist/next` (cachea
 * payloads RSC y HTML de páginas, o sea saldos) y declaramos las reglas a mano:
 *
 *  1. `/api/*`, `/auth/*` y cualquier request a Supabase → **NetworkOnly**.
 *     Nunca tocan el caché. Sin red, la app cae al fallback.
 *  2. Payloads RSC (navegación con `next/link`) → **NetworkOnly**: son los mismos
 *     datos financieros que el HTML.
 *  3. Navegaciones (documentos) → **NetworkFirst**: con red SIEMPRE gana la red,
 *     así que nunca servimos una página vieja estando online. Lo que se escribe
 *     en ese caché lo filtra `shouldCachePage` (`lib/pwa/routes.ts`): sólo
 *     páginas públicas (landing, login, registro, recuperar clave, `/~offline`)
 *     con un 200 limpio. Las rutas de la app no dejan rastro → offline caen al
 *     fallback `/~offline` en vez de mostrar saldos viejos.
 *  4. Estáticos con hash (`/_next/static/*`), imágenes, íconos y fuentes →
 *     **CacheFirst** con expiración. Son inmutables o irrelevantes para la plata.
 *
 * ── Auth ─────────────────────────────────────────────────────────────────────
 * Las navegaciones llegan con `redirect: "manual"`, así que el redirect del
 * middleware (`/dashboard` → `/login`) vuelve como `opaqueredirect` (status 0) y
 * lo reenviamos tal cual: el navegador lo sigue. `shouldCachePage` rechaza
 * explícitamente `status !== 200`, `redirected` y todo lo que no sea `basic`,
 * para no guardar NUNCA un redirect bajo la URL original (sería servir una
 * página cacheada en lugar del gate de auth).
 */

declare global {
  interface WorkerGlobalScope extends SerwistGlobalConfig {
    __SW_MANIFEST: (PrecacheEntry | string)[] | undefined;
  }
}

declare const self: ServiceWorkerGlobalScope;

const YEAR = 365 * 24 * 60 * 60;
const WEEK = 7 * 24 * 60 * 60;
const DAY = 24 * 60 * 60;

const runtimeCaching: RuntimeCaching[] = [
  // 1. Datos financieros y auth: nunca al caché.
  {
    matcher: ({ url, sameOrigin }) =>
      isSupabaseHost(url.hostname) ||
      (sameOrigin && isNeverCachePath(url.pathname)),
    handler: new NetworkOnly(),
  },

  // 2. Payloads RSC de las navegaciones client-side (`?_rsc=` / header `RSC`).
  {
    matcher: ({ request, url, sameOrigin }) =>
      sameOrigin &&
      (url.searchParams.has("_rsc") || request.headers.get("RSC") === "1"),
    handler: new NetworkOnly(),
  },

  // 3. Estáticos de Next: el nombre lleva hash de contenido → CacheFirst.
  {
    matcher: ({ url, sameOrigin }) =>
      sameOrigin && url.pathname.startsWith("/_next/static/"),
    handler: new CacheFirst({
      cacheName: "next-static",
      plugins: [new ExpirationPlugin({ maxEntries: 256, maxAgeSeconds: YEAR })],
    }),
  },

  // 4. Imágenes, íconos y fuentes (incluye `/_next/image` y `public/`).
  {
    matcher: ({ request, url, sameOrigin }) =>
      sameOrigin &&
      (request.destination === "image" ||
        request.destination === "font" ||
        url.pathname.startsWith("/_next/image")),
    handler: new CacheFirst({
      cacheName: "static-assets",
      plugins: [new ExpirationPlugin({ maxEntries: 96, maxAgeSeconds: 30 * DAY })],
    }),
  },

  // 5. Manifest PWA (sin datos del usuario).
  {
    matcher: ({ url, sameOrigin }) =>
      sameOrigin && url.pathname === "/manifest.webmanifest",
    handler: new CacheFirst({
      cacheName: "manifest",
      plugins: [new ExpirationPlugin({ maxEntries: 4, maxAgeSeconds: WEEK })],
    }),
  },

  // 6. Navegaciones: NetworkFirst, pero sólo las páginas públicas se persisten.
  {
    matcher: ({ request, sameOrigin }) =>
      sameOrigin && request.mode === "navigate",
    handler: new NetworkFirst({
      cacheName: "pages",
      networkTimeoutSeconds: 10,
      plugins: [
        {
          cacheWillUpdate: async ({ request, response }) =>
            shouldCachePage({
              pathname: new URL(request.url).pathname,
              status: response.status,
              redirected: response.redirected,
              type: response.type,
            })
              ? response
              : null,
        },
        new ExpirationPlugin({ maxEntries: 16, maxAgeSeconds: WEEK }),
      ],
    }),
  },
];

const serwist = new Serwist({
  precacheEntries: self.__SW_MANIFEST,
  precacheOptions: { cleanupOutdatedCaches: true, concurrency: 10 },
  skipWaiting: true,
  clientsClaim: true,
  navigationPreload: true,
  runtimeCaching,
  fallbacks: {
    entries: [
      {
        // `/~offline` se precachea vía `additionalPrecacheEntries` en next.config.
        url: OFFLINE_PATH,
        // Sólo para documentos: una API caída no debe devolver HTML.
        matcher: ({ request }) => request.destination === "document",
      },
    ],
  },
});

serwist.addEventListeners();
