import { Logo } from "@/components/brand/logo";
import { ShieldCheck, Sparkles, Wallet } from "lucide-react";
import { getT } from "@/lib/i18n/server";

export default async function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const t = await getT();
  const HIGHLIGHTS = [
    {
      icon: Wallet,
      title: t("nav.highlight1Title"),
      body: t("nav.highlight1Body"),
    },
    {
      icon: Sparkles,
      title: t("nav.highlight2Title"),
      body: t("nav.highlight2Body"),
    },
    {
      icon: ShieldCheck,
      title: t("nav.highlight3Title"),
      body: t("nav.highlight3Body"),
    },
  ];
  return (
    <div className="bg-aurora relative grid min-h-dvh lg:grid-cols-[1.05fr_1fr]">
      {/* Panel de marca (solo desktop) */}
      <aside className="relative hidden flex-col justify-between overflow-hidden border-r border-border p-12 lg:flex xl:p-16">
        <Logo />

        <div className="max-w-md">
          <h1 className="font-num text-balance text-[2.75rem] leading-[1.05] text-foreground">
            {t("nav.brandHeadline")}
          </h1>
          <p className="text-text-muted mt-5 text-[15px] leading-relaxed">
            {t("nav.brandSubtitle")}
          </p>

          <ul className="mt-10 space-y-5">
            {HIGHLIGHTS.map((h) => (
              <li key={h.title} className="flex gap-4">
                <span className="bg-primary/12 text-primary flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-md)]">
                  <h.icon className="size-5" />
                </span>
                <div>
                  <p className="text-[15px] font-semibold text-foreground">
                    {h.title}
                  </p>
                  <p className="text-text-muted text-sm leading-relaxed">
                    {h.body}
                  </p>
                </div>
              </li>
            ))}
          </ul>
        </div>

        <p className="text-text-dim text-xs">
          {t("nav.footer", { year: new Date().getFullYear() })}
        </p>
      </aside>

      {/* Panel de formulario */}
      <main className="flex items-center justify-center px-6 py-12 sm:px-10">
        <div className="w-full max-w-sm">
          <div className="mb-8 flex justify-center lg:hidden">
            <Logo />
          </div>
          {children}
        </div>
      </main>
    </div>
  );
}
