import type { MetadataRoute } from "next";

/**
 * PWA manifest (Next auto-detecta `app/manifest.ts`). Marca Home Finance,
 * tema Midnight Sage. Instalable en iOS y Android desde el navegador.
 */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Home Finance",
    short_name: "Home Finance",
    description:
      "Gestioná las finanzas de tu hogar: presupuestos, movimientos, metas y reportes — la misma cuenta de tu app.",
    start_url: "/dashboard",
    display: "standalone",
    background_color: "#0e1312",
    theme_color: "#0e1312",
    icons: [
      {
        src: "/icon.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "any",
      },
      // TODO: agregar un PNG 512×512 maskable dedicado (con safe-area) en
      // lugar de reutilizar /icon.png, para que Android no recorte el logo.
      {
        src: "/icon.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
  };
}
