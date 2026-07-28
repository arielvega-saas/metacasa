import type { Metadata } from "next";
import { WifiOff, RefreshCw } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("offline.metaTitle"), robots: { index: false } };
}

/**
 * Fallback offline del PWA (ítem 4.8). El service worker precachea esta ruta
 * (`additionalPrecacheEntries` en `next.config.ts`) y la sirve cuando una
 * navegación no puede resolverse por red.
 *
 * Deliberadamente NO muestra ningún dato del hogar: el criterio de la app es que
 * sin red es mejor decir "no hay conexión" que pintar saldos viejos sin aviso.
 * Tampoco depende de imágenes de `public/` (que podrían no estar cacheadas):
 * sólo tipografía, tokens del design system e íconos de lucide, que viajan en
 * los estáticos precacheados.
 */
export default async function OfflinePage() {
  const t = await getT();
  return (
    <div className="bg-aurora flex min-h-dvh items-center justify-center px-6 py-12">
      <Card glass className="sage-glow w-full max-w-md p-8">
        <span className="bg-champagne/15 text-champagne mb-5 inline-flex size-12 items-center justify-center rounded-2xl">
          <WifiOff className="size-6" aria-hidden="true" />
        </span>

        <h1 className="text-2xl font-semibold tracking-tight">
          {t("offline.title")}
        </h1>
        <p className="text-text-muted mt-2 text-sm leading-relaxed">
          {t("offline.body")}
        </p>
        <p className="text-text-dim mt-3 text-xs leading-relaxed">
          {t("offline.hint")}
        </p>

        <div className="mt-7 space-y-2.5">
          {/*
            `<a>` y no `<Link>`: queremos una navegación DURA. Un Link haría un
            fetch RSC (que el SW manda por NetworkOnly y falla sin red); una
            navegación real vuelve a pasar por el SW y, si sigue sin haber
            conexión, cae otra vez acá. Cero JS de cliente.
          */}
          <Button asChild size="lg" className="w-full">
            <a href="/dashboard">
              <RefreshCw className="size-4" /> {t("offline.retry")}
            </a>
          </Button>
          <Button asChild variant="secondary" size="lg" className="w-full">
            <a href="/">{t("offline.goHome")}</a>
          </Button>
        </div>
      </Card>
    </div>
  );
}
