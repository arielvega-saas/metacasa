import { Card } from "@/components/ui/card";
import { Amount } from "@/components/finance/amount";
import { getT } from "@/lib/i18n/server";

/**
 * Card de Patrimonio neto. SERVER COMPONENT puro: NO hace fetch — recibe los
 * números ya calculados por props. Definición (paridad iOS
 * `AccountBalanceService.netWorth` + nuestro `lib/db/debts.debtTotals`):
 *   assets      = Σ saldos de cuenta POSITIVOS, consolidados a moneda base vía FX
 *   liabilities = Σ deudas activas + Σ |saldos de cuenta NEGATIVOS|, en base
 *   net         = assets − liabilities
 *
 * PROPS (para que el owner del dashboard lo monte): `assets`, `liabilities` y
 * `net` (números en moneda base), `currency` (ISO de la moneda base, p. ej.
 * "USD") y `hasUnconverted` opcional (true si alguna moneda quedó fuera por
 * faltar su tasa FX → muestra el aviso de aproximación).
 */
export interface NetWorthCardProps {
  /** Activos: Σ saldos positivos consolidados a moneda base. */
  assets: number;
  /** Pasivos: Σ deudas activas + Σ |saldos negativos|, en moneda base. */
  liabilities: number;
  /** Patrimonio neto = assets − liabilities, en moneda base. */
  net: number;
  /** Moneda base del hogar (ISO), para formatear los montos. */
  currency: string;
  /** `true` si faltó la tasa FX de alguna moneda y quedó fuera del total. */
  hasUnconverted?: boolean;
  /** Clases extra para el contenedor (layout del dashboard). */
  className?: string;
}

export async function NetWorthCard({
  assets,
  liabilities,
  net,
  currency,
  hasUnconverted = false,
  className,
}: NetWorthCardProps) {
  const t = await getT();

  return (
    <Card className={`sage-glow p-5 sm:p-6${className ? ` ${className}` : ""}`}>
      <p className="text-text-muted text-sm">{t("netWorth.title")}</p>
      <Amount
        value={net}
        currency={currency}
        kind="balance"
        serif
        className="mt-1.5 block text-3xl sm:text-4xl"
      />

      <div className="mt-4 grid grid-cols-2 gap-3">
        <div className="rounded-[var(--radius-md)] bg-tint-1 p-3">
          <p className="text-text-dim text-[11px] uppercase tracking-wider">
            {t("netWorth.assets")}
          </p>
          <Amount
            value={assets}
            currency={currency}
            kind="ingreso"
            className="mt-0.5 block text-base font-semibold"
          />
        </div>
        <div className="rounded-[var(--radius-md)] bg-tint-1 p-3">
          <p className="text-text-dim text-[11px] uppercase tracking-wider">
            {t("netWorth.liabilities")}
          </p>
          <Amount
            value={liabilities}
            currency={currency}
            kind="gasto"
            className="mt-0.5 block text-base font-semibold"
          />
        </div>
      </div>

      {hasUnconverted && (
        <p className="text-text-dim mt-3 text-xs">
          {t("netWorth.mixedCurrencies", { currency })}
        </p>
      )}
    </Card>
  );
}
