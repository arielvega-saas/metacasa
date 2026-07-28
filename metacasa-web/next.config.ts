import type { NextConfig } from "next";
import withSerwistInit from "@serwist/next";

/** Security headers (fintech). CSP estricta se evalúa aparte para no romper hidratación. */
const securityHeaders = [
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=(), payment=()",
  },
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },
];

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // Raíz de tracing correcta (hay varios lockfiles en el monorepo).
  outputFileTracingRoot: import.meta.dirname,
  // ESLint no bloquea el build de producción mientras iteramos.
  eslint: { ignoreDuringBuilds: true },
  // Los errores de TypeScript SÍ bloquean el build.
  typescript: { ignoreBuildErrors: false },
  experimental: {
    optimizePackageImports: ["lucide-react", "recharts", "date-fns"],
  },
  async headers() {
    return [
      { source: "/:path*", headers: securityHeaders },
      // El AASA (Universal Links de iOS) no tiene extensión → Next lo serviría
      // como octet-stream. Apple tolera el content-type, pero lo forzamos a
      // application/json por las dudas. assetlinks.json ya sale como JSON por su
      // extensión.
      {
        source: "/.well-known/apple-app-site-association",
        headers: [{ key: "Content-Type", value: "application/json" }],
      },
    ];
  },
};

/**
 * PWA offline (ítem 4.8) con `@serwist/next`.
 *
 * - `swSrc` → `app/sw.ts` (política de caché comentada ahí). `swDest` sale a
 *   `public/sw.js`, que va al `.gitignore` porque es artefacto de build.
 * - `globPublicPatterns: []`: NO precacheamos `public/`. `logo.png` pesa 800 KB,
 *   los HTML legales no hacen falta offline y `.well-known/*` (AASA /
 *   assetlinks) NO debe pasar por el service worker. Lo que sí se precachea es
 *   el build de Next (`/_next/static`: CSS, chunks y las fuentes self-hosted),
 *   que es todo lo que necesita la página offline para renderizar.
 * - `additionalPrecacheEntries`: mete `/~offline` en el precache — el
 *   `fallbacks` de Serwist exige que la URL ya esté precacheada. La `revision`
 *   cambia por build para que un deploy nuevo refresque esa página.
 * - `disable` en dev: el SW en `next dev` sólo agrega ruido y caché fantasma.
 */
const withSerwist = withSerwistInit({
  swSrc: "app/sw.ts",
  swDest: "public/sw.js",
  disable: process.env.NODE_ENV === "development",
  globPublicPatterns: [],
  additionalPrecacheEntries: [
    { url: "/~offline", revision: globalThis.crypto.randomUUID() },
  ],
});

export default withSerwist(nextConfig);
