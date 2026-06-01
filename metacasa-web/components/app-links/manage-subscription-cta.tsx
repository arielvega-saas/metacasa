"use client";

import { useEffect, useState } from "react";
import { Apple, Smartphone } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useT } from "@/components/i18n/locale-provider";
import { STORE_LINKS, detectPlatform, type DetectedPlatform } from "./store-links";

function usePlatform(): DetectedPlatform {
  const [platform, setPlatform] = useState<DetectedPlatform>("other");
  useEffect(() => {
    const ua = navigator.userAgent;
    let p = detectPlatform(ua);
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
 * CTA de suscripción/billing sensible a la plataforma. La web NO cobra: el plan
 * se gestiona en la app (App Store / Google Play). Para Apple linkeamos a la
 * ficha de la App Store; para Android (prueba cerrada) y desktop mostramos un
 * estado honesto "Gestioná desde la app", sin link muerto.
 *
 * `variant`:
 *  - "manage"    → "Gestioná tu suscripción en la app"
 *  - "subscribe" → "Suscribite desde la app"
 */
export function ManageSubscriptionCTA({
  variant = "manage",
  size = "lg",
  className,
}: {
  variant?: "manage" | "subscribe";
  size?: "default" | "sm" | "lg";
  className?: string;
}) {
  const t = useT();
  const platform = usePlatform();
  const label =
    variant === "subscribe"
      ? t("storeLinks.subscribeFromApp")
      : t("storeLinks.manageInApp");

  // Apple: link directo a la ficha de la App Store.
  if (platform === "ios") {
    return (
      <Button asChild size={size} className={className ?? "w-full"}>
        <a href={STORE_LINKS.ios} target="_blank" rel="noopener noreferrer">
          <Apple /> {label}
        </a>
      </Button>
    );
  }

  // Android / desktop: estado informativo honesto (no hay billing en la web).
  return (
    <div
      className={
        className ??
        "bg-inset hairline flex items-center justify-center gap-2 rounded-[var(--radius-lg)] px-4 py-3 text-center"
      }
      role="status"
    >
      <Smartphone className="text-text-muted size-4 shrink-0" />
      <span className="text-text-muted text-[13px] font-medium leading-snug">
        {label}
      </span>
    </div>
  );
}
