/**
 * URL canónica del sitio, compartida por robots/sitemap/metadata OG.
 * En producción se define `NEXT_PUBLIC_SITE_URL`; el fallback es el deploy
 * de Vercel por defecto.
 */
export const SITE_URL =
  process.env.NEXT_PUBLIC_SITE_URL ?? "https://metacasa-web.vercel.app";
