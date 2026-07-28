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
        sizes: "1024x1024",
        type: "image/png",
        purpose: "any",
      },
      // Maskable dedicado: logo al ~60% del canvas (safe zone) sobre #0E1312,
      // así Android no recorta el logo al aplicar la máscara.
      {
        src: "/icon-maskable-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
    shortcuts: [
      {
        name: "Nueva transacción",
        short_name: "Nueva tx",
        description: "Registrá un gasto o ingreso al instante.",
        // `?new=1` abre el diálogo de alta (soportado por transactions/page.tsx).
        url: "/transactions?new=1",
      },
      {
        name: "Dashboard",
        description: "Resumen de las finanzas de tu hogar.",
        url: "/dashboard",
      },
    ],
  };
}
