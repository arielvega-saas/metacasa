import type { NextConfig } from "next";

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
    return [{ source: "/:path*", headers: securityHeaders }];
  },
};

export default nextConfig;
