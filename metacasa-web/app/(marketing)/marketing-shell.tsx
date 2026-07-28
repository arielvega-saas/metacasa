import Link from "next/link";
import { Logo } from "@/components/brand/logo";
import { Button } from "@/components/ui/button";
import { APP_STORE_URL, SUPPORT_EMAIL } from "./constants";

/**
 * Cascarón de la landing de marketing: navbar sticky de vidrio + footer.
 *
 * Nota estructural: NO es un `layout.tsx` de ruta porque la landing vive en
 * `app/page.tsx` (la raíz `/` necesita el gate de sesión ahí, y Next no admite
 * `app/page.tsx` + `app/(marketing)/page.tsx` en paralelo). Este archivo y sus
 * hermanos son componentes de colocación del grupo `(marketing)`.
 */

const NAV_LINKS = [
  { href: "#funciones", label: "Funciones" },
  { href: "#como-funciona", label: "Cómo funciona" },
  { href: "#precios", label: "Precios" },
  { href: "#faq", label: "Preguntas" },
];

export function MarketingShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="bg-aurora relative min-h-dvh overflow-x-clip">
      {/* ===== Navbar sticky glass ===== */}
      <header className="glass sticky top-0 z-50 border-b border-border">
        <div className="mx-auto flex h-16 max-w-6xl items-center gap-6 px-5 sm:px-8">
          <Link href="/" aria-label="Home Finance — inicio" className="shrink-0">
            <Logo />
          </Link>

          <nav
            aria-label="Secciones de la página"
            className="hidden items-center gap-6 md:flex"
          >
            {NAV_LINKS.map((l) => (
              <a
                key={l.href}
                href={l.href}
                className="text-text-muted hover:text-foreground text-sm font-medium transition-colors"
              >
                {l.label}
              </a>
            ))}
          </nav>

          <div className="ml-auto flex items-center gap-2">
            <Button asChild variant="ghost" size="sm">
              <Link href="/login">Iniciar sesión</Link>
            </Button>
            <Button asChild size="sm" className="hidden sm:inline-flex">
              <Link href="/login">Probar gratis</Link>
            </Button>
          </div>
        </div>
      </header>

      <main className="relative">{children}</main>

      {/* ===== Footer ===== */}
      <footer className="relative border-t border-border">
        <div className="mx-auto max-w-6xl px-5 py-12 sm:px-8">
          <div className="flex flex-col gap-8 sm:flex-row sm:items-start sm:justify-between">
            <div className="max-w-xs space-y-3">
              <Logo />
              <p className="text-text-muted text-sm leading-relaxed">
                Finanzas del hogar, claras. Presupuesto familiar con IA,
                multi-moneda y privacidad — para toda la familia.
              </p>
            </div>

            <nav
              aria-label="Enlaces legales y de soporte"
              className="flex flex-wrap items-center gap-x-6 gap-y-3 text-sm"
            >
              {/* Páginas estáticas reales en public/ (ya públicas en el middleware) */}
              <a
                href="/privacy.html"
                className="text-text-muted hover:text-foreground transition-colors"
              >
                Privacidad
              </a>
              <a
                href="/terms.html"
                className="text-text-muted hover:text-foreground transition-colors"
              >
                Términos
              </a>
              <a
                href={`mailto:${SUPPORT_EMAIL}`}
                className="text-text-muted hover:text-foreground transition-colors"
              >
                Soporte
              </a>
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="text-text-muted hover:text-foreground transition-colors"
              >
                App Store
              </a>
            </nav>
          </div>

          <div className="text-text-dim mt-10 flex flex-col gap-2 border-t border-border pt-6 text-xs sm:flex-row sm:items-center sm:justify-between">
            <span>© {new Date().getFullYear()} Home Finance</span>
            {/* Sin /80: en tema claro el champagne translúcido caía a 3.6:1. */}
            <span className="font-num text-champagne italic">
              Tu plata más clara, tu casa más tranquila.
            </span>
          </div>
        </div>
      </footer>
    </div>
  );
}
