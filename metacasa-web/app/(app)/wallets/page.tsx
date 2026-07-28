import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getAccessState } from "@/lib/access";
import { getT, getLocale } from "@/lib/i18n/server";
import { intlLocale } from "@/lib/i18n/dates";
import {
  listWallets,
  listWalletMovements,
  suggestCategories,
  walletMetadata,
} from "@/lib/db/wallets";
import { TX_TYPE } from "@/lib/constants";
import { WalletsView } from "@/components/wallets/wallets-view";
import type {
  PendingMovement,
  WalletBlockData,
} from "@/components/wallets/types";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("wallets.title") };
}

/** Cuántos movimientos pendientes mostramos por wallet (el sync trae 50). */
const PENDING_LIMIT = 50;

/**
 * Pantalla de **Wallets** (server component).
 *
 * Trae las wallets conectadas del hogar activo, sus movimientos todavía sin
 * importar y la categoría que el hogar ya aprendió para cada descripción
 * (`suggest_category`). Las fechas se formatean acá para que el componente
 * client no dependa de la zona horaria del navegador (evita mismatch de
 * hidratación) y nunca se expone ningún token: `lib/db/wallets` lista columnas
 * explícitas y jamás selecciona `access_token*`.
 */
export default async function WalletsPage({
  searchParams,
}: {
  searchParams: Promise<{ connect?: string }>;
}) {
  const supabase = await createClient();
  const t = await getT();
  const locale = await getLocale();

  // Gate Premium (el layout ya bloquea `locked`; acá va la defensa en profundidad).
  const access = await getAccessState();
  if (access.state === "locked") redirect("/locked");

  const { active } = await resolveActiveHousehold(supabase);
  if (!active) {
    return <p className="text-text-muted">{t("errors.noHousehold")}</p>;
  }

  const wallets = await listWallets(supabase, active.id);

  const dateFmt = new Intl.DateTimeFormat(intlLocale(locale), {
    day: "2-digit",
    month: "short",
  });
  const syncFmt = new Intl.DateTimeFormat(intlLocale(locale), {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });

  const blocks: WalletBlockData[] = [];

  if (wallets.length > 0) {
    const movements = await listWalletMovements(supabase, active.id, {
      limit: PENDING_LIMIT * Math.max(1, wallets.length),
    });

    const suggestions = await suggestCategories(
      supabase,
      active.id,
      movements
        .filter((m) => m.synced_tx_id == null)
        .map((m) => m.description ?? ""),
    );

    for (const wallet of wallets) {
      const pending: PendingMovement[] = movements
        .filter((m) => m.wallet_id === wallet.id && m.synced_tx_id == null)
        .slice(0, PENDING_LIMIT)
        .map((m) => {
          const note = (m.description ?? "").trim();
          const hit = suggestions.get(note);
          return {
            id: m.id,
            dateLabel: dateFmt.format(new Date(m.date)),
            description: note,
            amount: Math.abs(Number(m.amount)),
            currency: (m.currency || active.default_currency).toUpperCase(),
            type: m.type === TX_TYPE.INCOME ? TX_TYPE.INCOME : TX_TYPE.EXPENSE,
            suggestedCategory: hit?.category ?? null,
            confidence: hit ? Math.round(hit.confidence * 100) : null,
          };
        });

      const meta = walletMetadata(wallet);
      blocks.push({
        id: wallet.id,
        name: wallet.name,
        provider: wallet.provider,
        currency: (wallet.currency || active.default_currency).toUpperCase(),
        // Sólo mostramos saldo si el provider realmente lo informó (MP no lo hace).
        balance:
          wallet.balance != null && Number(wallet.balance) !== 0
            ? Number(wallet.balance)
            : null,
        lastSyncLabel: wallet.last_sync
          ? syncFmt.format(new Date(wallet.last_sync))
          : null,
        sandbox: meta.live_mode === false,
        pending,
      });
    }
  }

  const params = await searchParams;
  const connectStatus =
    params?.connect === "ok" || params?.connect === "error"
      ? params.connect
      : null;

  return <WalletsView wallets={blocks} connectStatus={connectStatus} />;
}
