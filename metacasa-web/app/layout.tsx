import type { Metadata, Viewport } from "next";
import { Fraunces, Manrope } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/providers";
import { LocaleProvider } from "@/components/i18n/locale-provider";
import { getLocale, getT } from "@/lib/i18n/server";
import { getDictionary } from "@/lib/i18n/dictionaries";
import { getTheme } from "@/lib/theme-server";
import { getBalancesHidden } from "@/lib/balance-privacy-server";
import { BALANCE_PRIVACY_ATTR } from "@/lib/balance-privacy";
import { themeClass, themeInitScript } from "@/lib/theme";
import { SITE_URL } from "@/lib/site";

/**
 * Fuentes self-hosted vía next/font (sin requests a Google en runtime).
 * - Fraunces: serif editorial variable (saldos hero / `--font-serif-stack`).
 *   Incluye el eje `opsz` para que los tamaños grandes usen el corte display.
 * - Manrope: sans variable para UI (`--font-sans-stack`).
 * Ambas soportan dígitos tabulares (`tnum`), que `.font-num`/`.tnum` activan.
 * Se exponen como CSS variables consumidas por los stacks en globals.css, con
 * fallback a ui-serif/"New York" (Apple) y system-ui mientras cargan.
 */
const fraunces = Fraunces({
  subsets: ["latin"],
  variable: "--font-fraunces",
  display: "swap",
  axes: ["opsz"],
});

const manrope = Manrope({
  subsets: ["latin"],
  variable: "--font-manrope",
  display: "swap",
});

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return {
    metadataBase: new URL(SITE_URL),
    title: {
      default: t("meta.rootTitle"),
      template: "%s · Home Finance",
    },
    description: t("meta.rootDescription"),
    applicationName: "Home Finance",
    appleWebApp: {
      capable: true,
      statusBarStyle: "black-translucent",
      title: "Home Finance",
    },
    openGraph: {
      title: t("meta.rootTitle"),
      description: t("meta.rootDescription"),
      type: "website",
      locale: "es_AR",
      siteName: "Home Finance",
      url: "/",
    },
    twitter: {
      card: "summary_large_image",
      title: t("meta.rootTitle"),
      description: t("meta.rootDescription"),
    },
  };
}

export const viewport: Viewport = {
  // Un theme-color por esquema: la barra del navegador / status bar de la PWA
  // acompaña el tema en lugar de quedarse siempre en midnight.
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f2efe6" },
    { media: "(prefers-color-scheme: dark)", color: "#0e1312" },
  ],
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default async function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const [locale, theme, ocultarSaldos] = await Promise.all([
    getLocale(),
    getTheme(),
    getBalancesHidden(),
  ]);
  const dict = getDictionary(locale);
  // `light`/`dark` van directo desde la cookie (SSR sin flash). Con `system`
  // la clase queda vacía → `:root` de globals.css (oscuro) y el script inline
  // de <head> la corrige antes del primer paint según prefers-color-scheme.
  return (
    <html
      lang={locale}
      className={`${themeClass(theme)} ${fraunces.variable} ${manrope.variable}`}
      // El atributo se resuelve en el SERVIDOR, no al hidratar: con `localStorage` la primera
      // pintura mostraría los montos reales y recién después se ocultarían. Ese parpadeo es
      // justo lo que la función existe para evitar.
      {...(ocultarSaldos ? { [BALANCE_PRIVACY_ATTR]: "" } : {})}
      suppressHydrationWarning
    >
      <head>
        <script
          // Debe correr ANTES del <body>: es lo que evita el flash de tema.
          // El único valor interpolado es la cookie ya validada por isTheme().
          dangerouslySetInnerHTML={{ __html: themeInitScript(theme) }}
        />
      </head>
      <body className="min-h-dvh bg-background text-foreground antialiased">
        <LocaleProvider locale={locale} dict={dict}>
          <Providers theme={theme}>{children}</Providers>
        </LocaleProvider>
      </body>
    </html>
  );
}
