import { redirect } from "next/navigation";

/**
 * `/privacy` → `/privacy.html`.
 *
 * La política vive como HTML estático en `public/`. Sin esta ruta, la forma sin extensión
 * dependía de que el CDN resolviera "pretty URLs" sobre el archivo estático — y eso cambió al
 * pasar de deploys manuales a builds desde el repo: el mismo commit servía 200 por CLI y 307
 * (rebote al login) desde el CI, porque con `@netlify/plugin-nextjs` los estáticos pasan por el
 * runtime de Next y el middleware corre primero.
 *
 * Una redirección explícita no depende de cómo se haya construido el sitio.
 */
export function GET() {
  redirect("/privacy.html");
}
