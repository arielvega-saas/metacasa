import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Providers } from "@/components/providers";
import { LocaleProvider } from "@/components/i18n/locale-provider";
import { getLocale, getT } from "@/lib/i18n/server";
import { getDictionary } from "@/lib/i18n/dictionaries";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return {
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
  };
}

export const viewport: Viewport = {
  themeColor: "#0e1312",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default async function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const locale = await getLocale();
  const dict = getDictionary(locale);
  return (
    <html lang={locale} className="dark" suppressHydrationWarning>
      <body className="min-h-dvh bg-background text-foreground antialiased">
        <LocaleProvider locale={locale} dict={dict}>
          <Providers>{children}</Providers>
        </LocaleProvider>
      </body>
    </html>
  );
}
