"use client";

import { useState, useTransition } from "react";
import { Monitor, Moon, Sun, type LucideIcon } from "lucide-react";
import { toast } from "sonner";
import { useT } from "@/components/i18n/locale-provider";
import { setTheme } from "@/lib/actions/theme";
import { THEMES, resolveTheme, type Theme } from "@/lib/theme";
import { cn } from "@/lib/utils";

const OPTION: Record<Theme, { icon: LucideIcon; labelKey: string }> = {
  system: { icon: Monitor, labelKey: "profile.themeSystem" },
  light: { icon: Sun, labelKey: "profile.themeLight" },
  dark: { icon: Moon, labelKey: "profile.themeDark" },
};

/**
 * Aplica el tema en el DOM al instante, sin esperar el round-trip de la server
 * action. Misma lógica que el script inline de `<head>` (lib/theme.ts): la
 * cookie es la fuente de verdad, esto sólo evita el parpadeo de espera.
 */
function applyThemeClass(theme: Theme) {
  if (typeof document === "undefined") return;
  const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  const resolved = resolveTheme(theme, prefersDark);
  const root = document.documentElement;
  root.classList.toggle("dark", resolved === "dark");
  root.classList.toggle("light", resolved === "light");
}

/**
 * Segmented control de tema: Sistema / Claro / Oscuro.
 * La preferencia se persiste en cookie (`mc_theme`) vía server action, así el
 * layout server ya renderiza la clase correcta en la próxima navegación.
 */
export function ThemeToggle({ value }: { value: Theme }) {
  const t = useT();
  const [selected, setSelected] = useState<Theme>(value);
  const [pending, startTransition] = useTransition();

  function choose(next: Theme) {
    if (next === selected) return;
    setSelected(next);
    applyThemeClass(next);
    startTransition(async () => {
      await setTheme(next);
      toast.success(t("profile.themeChanged"));
    });
  }

  return (
    <div
      role="radiogroup"
      aria-label={t("profile.themeLabel")}
      className="bg-inset hairline inline-flex shrink-0 items-center gap-1 rounded-[var(--radius-lg)] p-1"
    >
      {THEMES.map((theme) => {
        const { icon: Icon, labelKey } = OPTION[theme];
        const active = selected === theme;
        return (
          <button
            key={theme}
            type="button"
            role="radio"
            aria-checked={active}
            disabled={pending}
            onClick={() => choose(theme)}
            className={cn(
              "inline-flex min-h-9 items-center gap-1.5 rounded-[var(--radius-md)] px-2.5 py-1.5 text-[13px] font-medium transition-colors outline-none",
              "focus-visible:ring-2 focus-visible:ring-ring/40 disabled:opacity-50",
              active
                ? "segment-on text-foreground"
                : "text-text-muted hover:bg-tint-1 hover:text-foreground",
            )}
          >
            <Icon className="size-4 shrink-0" />
            <span className="hidden sm:inline">{t(labelKey)}</span>
            <span className="sr-only sm:hidden">{t(labelKey)}</span>
          </button>
        );
      })}
    </div>
  );
}
