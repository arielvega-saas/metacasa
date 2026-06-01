import type { Metadata } from "next";
import {
  ArrowUpRight,
  Clock,
  QrCode,
  RefreshCw,
  ShieldCheck,
  Smartphone,
  Sparkles,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/layout/page-header";
import { SectionHeader } from "@/components/finance/section-header";
import { StoreCTA, StoreCTACompact } from "@/components/app-links/store-cta";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("connect.metaTitle") };
}

/** Conectar con la app móvil: explicación del handoff (read-only). */
export default async function ConnectPage() {
  const t = await getT();

  const STEPS = [
    { title: t("connect.step1Title"), description: t("connect.step1Desc") },
    { title: t("connect.step2Title"), description: t("connect.step2Desc") },
    { title: t("connect.step3Title"), description: t("connect.step3Desc") },
  ];

  const BENEFITS = [
    {
      icon: RefreshCw,
      title: t("connect.benefitRealtimeTitle"),
      description: t("connect.benefitRealtimeDesc"),
    },
    {
      icon: ShieldCheck,
      title: t("connect.benefitSameAccountTitle"),
      description: t("connect.benefitSameAccountDesc"),
    },
    {
      icon: Sparkles,
      title: t("connect.benefitDesktopTitle"),
      description: t("connect.benefitDesktopDesc"),
    },
  ];

  return (
    <div>
      <PageHeader
        title={t("connect.title")}
        description={t("connect.description")}
      />

      <div className="grid gap-4 lg:grid-cols-[1.5fr_1fr]">
        {/* Paso a paso del handoff */}
        <Card className="p-6">
          <SectionHeader
            title={t("connect.howToTitle")}
            subtitle={t("connect.howToSubtitle")}
          />
          <ol className="space-y-5">
            {STEPS.map((step, i) => (
              <li key={step.title} className="flex gap-4">
                <span className="bg-primary/15 text-primary flex size-9 shrink-0 items-center justify-center rounded-full text-sm font-semibold">
                  {i + 1}
                </span>
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-foreground">
                    {step.title}
                  </p>
                  <p className="text-text-muted mt-0.5 text-sm leading-relaxed">
                    {step.description}
                  </p>
                </div>
              </li>
            ))}
          </ol>

          <div className="bg-inset hairline mt-6 flex items-start gap-3 rounded-[var(--radius-lg)] p-4">
            <Clock className="text-champagne mt-0.5 size-4 shrink-0" />
            <p className="text-text-muted text-xs leading-relaxed">
              {t("connect.expiryNote")}
            </p>
          </div>
        </Card>

        {/* Tarjeta visual de descarga + QR placeholder */}
        <Card glass className="sage-glow border-primary/20 flex flex-col p-6">
          <div className="flex items-center gap-2.5">
            <span className="bg-primary/15 text-primary flex size-10 items-center justify-center rounded-[var(--radius-md)]">
              <Smartphone className="size-5" />
            </span>
            <div>
              <p className="text-sm font-semibold text-foreground">
                {t("connect.noAppTitle")}
              </p>
              <p className="text-text-dim text-xs">{t("connect.noAppSubtitle")}</p>
            </div>
          </div>

          {/* Placeholder de QR (sin librerías): patrón decorativo */}
          <div className="my-6 flex justify-center">
            <div
              className="bg-inset hairline grid size-40 place-items-center rounded-[var(--radius-lg)]"
              aria-hidden="true"
            >
              <QrCode className="text-text-dim size-20" />
            </div>
          </div>
          <p className="text-text-dim mb-5 text-center text-xs leading-relaxed">
            {t("connect.qrSoon")}
          </p>

          <div className="mt-auto">
            <StoreCTA />
          </div>
        </Card>
      </div>

      {/* Beneficios del handoff */}
      <div className="mt-4 grid gap-4 sm:grid-cols-3">
        {BENEFITS.map((b) => {
          const Icon = b.icon;
          return (
            <Card key={b.title} className="p-5">
              <span className="bg-primary/10 text-primary mb-3 flex size-10 items-center justify-center rounded-[var(--radius-md)]">
                <Icon className="size-5" />
              </span>
              <p className="text-sm font-semibold text-foreground">{b.title}</p>
              <p className="text-text-muted mt-1 text-sm leading-relaxed">
                {b.description}
              </p>
            </Card>
          );
        })}
      </div>

      {/* Pie: conseguí la app (sensible a plataforma) */}
      <Card className="mt-4 flex flex-wrap items-center justify-between gap-3 p-5">
        <div className="flex items-center gap-3">
          <ArrowUpRight className="text-primary size-5" />
          <div>
            <p className="text-sm font-semibold text-foreground">
              {t("connect.learnMoreTitle")}
            </p>
            <p className="text-text-muted text-sm">
              {t("connect.learnMoreDesc")}
            </p>
          </div>
        </div>
        <StoreCTACompact />
      </Card>
    </div>
  );
}
