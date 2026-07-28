"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { WalletCards, ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/layout/page-header";
import { useT } from "@/components/i18n/locale-provider";
import { startMercadoPagoOAuth } from "@/lib/actions/wallets";
import { WalletCard } from "@/components/wallets/wallet-card";
import type { WalletBlockData } from "@/components/wallets/types";

export interface WalletsViewProps {
  wallets: WalletBlockData[];
  /** Resultado del callback OAuth ("ok" | "error"), para el toast de vuelta. */
  connectStatus: "ok" | "error" | null;
}

/**
 * Pantalla de Wallets: conexión OAuth con Mercado Pago, estado de cada wallet
 * y bandeja de movimientos para importar. El token nunca pasa por acá — la
 * server action devuelve sólo la URL de autorización.
 */
export function WalletsView({ wallets, connectStatus }: WalletsViewProps) {
  const t = useT();
  const router = useRouter();
  const [connecting, setConnecting] = React.useState(false);

  // Toast del regreso de Mercado Pago + limpieza del query param (una sola vez).
  const handled = React.useRef(false);
  React.useEffect(() => {
    if (!connectStatus || handled.current) return;
    handled.current = true;
    if (connectStatus === "ok") toast.success(t("wallets.toast.connected"));
    else toast.error(t("wallets.toast.connectError"));
    router.replace("/wallets");
    // `t` cambia de identidad en cada render (closure sobre el diccionario):
    // el efecto depende sólo del estado que realmente importa.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [connectStatus]);

  const connect = async () => {
    setConnecting(true);
    try {
      const { url } = await startMercadoPagoOAuth();
      window.location.href = url;
    } catch (e) {
      setConnecting(false);
      toast.error(
        e instanceof Error ? e.message : t("wallets.toast.connectError"),
      );
    }
  };

  const connectButton = (
    <Button onClick={connect} disabled={connecting}>
      <WalletCards />
      {connecting ? t("wallets.connecting") : t("wallets.connectMP")}
    </Button>
  );

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("wallets.title")}
        description={t("wallets.description")}
        action={wallets.length > 0 ? connectButton : undefined}
      />

      {wallets.length === 0 ? (
        <>
          <EmptyState
            icon={WalletCards}
            title={t("wallets.emptyTitle")}
            description={t("wallets.emptyDescription")}
            action={connectButton}
          />
          <p className="text-text-dim text-center text-xs">
            {t("wallets.comingSoon")}
          </p>
        </>
      ) : (
        <div className="space-y-5">
          {wallets.map((wallet) => (
            <WalletCard key={wallet.id} wallet={wallet} />
          ))}
        </div>
      )}

      <div className="text-text-dim flex items-start gap-2 rounded-[var(--radius-lg)] border border-dashed border-border px-4 py-3 text-xs">
        <ShieldCheck className="mt-0.5 size-4 shrink-0" />
        <p>{t("wallets.securityNote")}</p>
      </div>
    </div>
  );
}
