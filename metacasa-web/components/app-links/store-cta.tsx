"use client";

import { useEffect, useState } from "react";
import { Apple, Smartphone, Clock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useT } from "@/components/i18n/locale-provider";
import { STORE_LINKS, detectPlatform, type DetectedPlatform } from "./store-links";

/** Detección de plataforma en el cliente (UA + touch para iPadOS 13+). */
function usePlatform(): DetectedPlatform {
  const [platform, setPlatform] = useState<DetectedPlatform>("other");
  useEffect(() => {
    const ua = navigator.userAgent;
    let p = detectPlatform(ua);
    // iPadOS 13+ se reporta como "Macintosh" pero tiene pantalla táctil.
    if (
      p === "other" &&
      /macintosh/i.test(ua) &&
      typeof navigator.maxTouchPoints === "number" &&
      navigator.maxTouchPoints > 1
    ) {
      p = "ios";
    }
    setPlatform(p);
  }, []);
  return platform;
}

/**
 * CTAs de descarga sensibles a la plataforma.
 * - Apple → botón "Descargar en App Store" (link real).
 * - Android → estado honesto "Próximamente en Google Play / prueba cerrada"
 *   (NO un link muerto, porque no hay ficha pública aún).
 * - Desktop/otros → muestra ambas opciones.
 */
export function StoreCTA() {
  const t = useT();
  const platform = usePlatform();

  const appStoreButton = (
    <Button asChild className="w-full" size="lg">
      <a href={STORE_LINKS.ios} target="_blank" rel="noopener noreferrer">
        <Apple /> {t("storeLinks.downloadAppStore")}
      </a>
    </Button>
  );

  const androidComingSoon = (
    <div
      className="bg-inset hairline flex items-center justify-center gap-2 rounded-[var(--radius-lg)] px-4 py-3 text-center"
      role="status"
    >
      <Clock className="text-champagne size-4 shrink-0" />
      <span className="text-text-muted text-[13px] font-medium leading-snug">
        {t("storeLinks.androidComingSoon")}
      </span>
    </div>
  );

  if (platform === "android") {
    return <div className="space-y-2.5">{androidComingSoon}</div>;
  }

  if (platform === "ios") {
    return <div className="space-y-2.5">{appStoreButton}</div>;
  }

  // Desktop / otros: ofrecemos iOS y el estado honesto de Android.
  return (
    <div className="space-y-2.5">
      {appStoreButton}
      <div
        className="bg-inset hairline flex items-center justify-center gap-2 rounded-[var(--radius-lg)] px-4 py-2.5 text-center"
        role="status"
      >
        <Smartphone className="text-text-muted size-4 shrink-0" />
        <span className="text-text-muted text-[13px] font-medium leading-snug">
          {t("storeLinks.androidComingSoon")}
        </span>
      </div>
    </div>
  );
}

/**
 * Variante compacta inline: un solo botón "outline" sensible a plataforma.
 * Apple → App Store; Android/desktop → estado informativo "próximamente".
 * Pensado para pies/CTAs donde no cabe el bloque completo.
 */
export function StoreCTACompact() {
  const t = useT();
  const platform = usePlatform();

  if (platform === "ios") {
    return (
      <Button asChild variant="outline">
        <a href={STORE_LINKS.ios} target="_blank" rel="noopener noreferrer">
          <Apple /> {t("storeLinks.downloadAppStore")}
        </a>
      </Button>
    );
  }

  return (
    <div
      className="bg-inset hairline flex items-center gap-2 rounded-[var(--radius-lg)] px-3.5 py-2"
      role="status"
    >
      <Smartphone className="text-text-muted size-4 shrink-0" />
      <span className="text-text-muted text-[13px] font-medium">
        {t("storeLinks.androidComingSoon")}
      </span>
    </div>
  );
}
