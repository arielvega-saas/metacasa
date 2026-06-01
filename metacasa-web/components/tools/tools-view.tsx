"use client";

// Hub de Herramientas: dos calculadoras (Plazo fijo / Interés compuesto)
// conmutadas por tabs. Cliente: todo es interactivo + i18n via useT().
import { useState } from "react";
import { Banknote, LineChart } from "lucide-react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Card } from "@/components/ui/card";
import { useT } from "@/components/i18n/locale-provider";
import { FixedTermCalculator } from "./fixed-term-calculator";
import { CompoundInterestCalculator } from "./compound-interest-calculator";

export function ToolsView({ currency }: { currency: string }) {
  const t = useT();
  const [tab, setTab] = useState("fixedTerm");

  return (
    <div className="space-y-6">
      {/* Cards de descubrimiento: tocan para saltar al tab correspondiente. */}
      <div className="grid gap-3 sm:grid-cols-2">
        <ToolCard
          icon={<Banknote className="text-primary size-5" />}
          title={t("tools.fixedTermCard")}
          desc={t("tools.fixedTermCardDesc")}
          active={tab === "fixedTerm"}
          onClick={() => setTab("fixedTerm")}
        />
        <ToolCard
          icon={<LineChart className="text-primary size-5" />}
          title={t("tools.compoundCard")}
          desc={t("tools.compoundCardDesc")}
          active={tab === "compound"}
          onClick={() => setTab("compound")}
        />
      </div>

      <Tabs value={tab} onValueChange={setTab}>
        <TabsList>
          <TabsTrigger value="fixedTerm">{t("tools.tabFixedTerm")}</TabsTrigger>
          <TabsTrigger value="compound">{t("tools.tabCompound")}</TabsTrigger>
        </TabsList>
        <TabsContent value="fixedTerm">
          <FixedTermCalculator currency={currency} />
        </TabsContent>
        <TabsContent value="compound">
          <CompoundInterestCalculator currency={currency} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

function ToolCard({
  icon,
  title,
  desc,
  active,
  onClick,
}: {
  icon: React.ReactNode;
  title: string;
  desc: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button type="button" onClick={onClick} className="text-left">
      <Card
        className={`flex h-full items-start gap-3 p-4 transition-colors ${
          active ? "ring-primary/40 ring-2" : "hover:bg-white/[0.03]"
        }`}
      >
        <span className="bg-inset hairline grid size-10 shrink-0 place-items-center rounded-[var(--radius-md)]">
          {icon}
        </span>
        <span className="min-w-0">
          <span className="block font-semibold">{title}</span>
          <span className="text-text-muted mt-0.5 block text-[13px] leading-snug">{desc}</span>
        </span>
      </Card>
    </button>
  );
}
