import type { Client } from "@/lib/supabase/types";
import type { Json } from "@/lib/database.types";

/**
 * Estrategia Waterfall del hogar — TWIN del modelo iOS.
 *
 * FUENTE DE VERDAD (iOS):
 *   - `Models/Household.swift` → `struct HouseholdStrategy` (CodingKeys)
 *   - `Core/WaterfallCalculator.swift` → el motor de cálculo
 *   - `Core/HouseholdService.swift` → cómo se persiste el jsonb
 *
 * El jsonb guardado en `households.strategy` tiene EXACTAMENTE esta forma
 * (verificado contra la DB de producción):
 * ```json
 * {
 *   "savings_pct": 10,
 *   "investment_pct": 0,
 *   "distribution_mode": "equal",
 *   "custom_allocations": {},
 *   "include_bills_in_waterfall": true,
 *   "include_installments_in_waterfall": true,
 *   "include_debt_payments_in_waterfall": true
 * }
 * ```
 * Las claves son snake_case (las define `HouseholdStrategy.CodingKeys` en
 * Household.swift:41-49). Cualquier escritura desde la web DEBE ser
 * byte-compatible con esto para no corromper la estrategia de la app nativa.
 */

/** Modo de distribución del remanente — espeja `HouseholdStrategy.DistributionMode` (Household.swift:51). */
export type DistributionMode = "equal" | "proportional" | "custom";

export const DISTRIBUTION_MODES: readonly DistributionMode[] = [
  "equal",
  "proportional",
  "custom",
] as const;

/**
 * Forma tipada de la estrategia (camelCase en TS, snake_case en el jsonb).
 * Espeja 1:1 los campos de `HouseholdStrategy` (Household.swift:27-49).
 */
export interface HouseholdStrategy {
  /** % del sub-total pre-distribución que va a ahorro (0–100). `savings_pct`. */
  savingsPct: number;
  /** % del sub-total pre-distribución que va a inversión (0–100). `investment_pct`. */
  investmentPct: number;
  /** Modo de distribución del remanente entre cuentas personales. `distribution_mode`. */
  distributionMode: DistributionMode;
  /** Allocations custom por cuenta (UUID → monto), usado si mode == "custom". `custom_allocations`. */
  customAllocations: Record<string, number>;
  /** Incluir vencimientos del mes en la cascada. `include_bills_in_waterfall`. */
  includeBillsInWaterfall: boolean;
  /** Incluir cuotas del mes en la cascada. `include_installments_in_waterfall`. */
  includeInstallmentsInWaterfall: boolean;
  /** Incluir pagos de deuda en la cascada. `include_debt_payments_in_waterfall`. */
  includeDebtPaymentsInWaterfall: boolean;
}

/**
 * Defaults idénticos a `HouseholdStrategy.default` de iOS (Household.swift:29-39, 62):
 * 10 % ahorro, 0 % inversión, distribución equitativa, todas las deducciones ON.
 */
export const DEFAULT_STRATEGY: HouseholdStrategy = {
  savingsPct: 10,
  investmentPct: 0,
  distributionMode: "equal",
  customAllocations: {},
  includeBillsInWaterfall: true,
  includeInstallmentsInWaterfall: true,
  includeDebtPaymentsInWaterfall: true,
};

/** Clamp a [0, 100] tolerante a basura/NaN. Inversión + ahorro no deben pasar de 100 juntos. */
function clampPct(n: unknown): number {
  const v = typeof n === "number" ? n : Number(n);
  if (!Number.isFinite(v)) return 0;
  return Math.min(100, Math.max(0, v));
}

/** Normaliza un mapa de allocations custom (UUID → número finito ≥ 0). */
function parseCustomAllocations(raw: unknown): Record<string, number> {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  const out: Record<string, number> = {};
  for (const [key, val] of Object.entries(raw as Record<string, unknown>)) {
    const num = typeof val === "number" ? val : Number(val);
    if (Number.isFinite(num)) out[key] = num;
  }
  return out;
}

/**
 * Parsea el jsonb crudo de `households.strategy` a la forma tipada, con defaults
 * para cualquier clave ausente/nula. Tolerante: si el jsonb es null o inválido,
 * devuelve `DEFAULT_STRATEGY` (idéntico al fallback `.default` de iOS).
 */
export function parseStrategy(raw: unknown): HouseholdStrategy {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return { ...DEFAULT_STRATEGY, customAllocations: {} };
  }
  const o = raw as Record<string, unknown>;

  const mode = o.distribution_mode;
  const distributionMode: DistributionMode =
    mode === "proportional" || mode === "custom" || mode === "equal"
      ? mode
      : "equal";

  return {
    savingsPct: clampPct(o.savings_pct ?? DEFAULT_STRATEGY.savingsPct),
    investmentPct: clampPct(o.investment_pct ?? DEFAULT_STRATEGY.investmentPct),
    distributionMode,
    customAllocations: parseCustomAllocations(o.custom_allocations),
    includeBillsInWaterfall:
      o.include_bills_in_waterfall === undefined
        ? DEFAULT_STRATEGY.includeBillsInWaterfall
        : Boolean(o.include_bills_in_waterfall),
    includeInstallmentsInWaterfall:
      o.include_installments_in_waterfall === undefined
        ? DEFAULT_STRATEGY.includeInstallmentsInWaterfall
        : Boolean(o.include_installments_in_waterfall),
    includeDebtPaymentsInWaterfall:
      o.include_debt_payments_in_waterfall === undefined
        ? DEFAULT_STRATEGY.includeDebtPaymentsInWaterfall
        : Boolean(o.include_debt_payments_in_waterfall),
  };
}

/**
 * Serializa la forma tipada de vuelta al jsonb snake_case EXACTO que escribe iOS
 * (`HouseholdService.updateStrategy`, vía las CodingKeys). Esta es la única
 * función que produce el payload de escritura; mantenerla en sync con
 * `HouseholdStrategy.CodingKeys` (Household.swift:41-49).
 *
 * IMPORTANTE: emite exactamente las 7 claves que iOS conoce — ni más ni menos —
 * para que cambiar la estrategia desde la web no corrompa el jsonb de la app.
 */
export function serializeStrategy(s: HouseholdStrategy): Json {
  return {
    savings_pct: s.savingsPct,
    investment_pct: s.investmentPct,
    distribution_mode: s.distributionMode,
    custom_allocations: s.customAllocations,
    include_bills_in_waterfall: s.includeBillsInWaterfall,
    include_installments_in_waterfall: s.includeInstallmentsInWaterfall,
    include_debt_payments_in_waterfall: s.includeDebtPaymentsInWaterfall,
  };
}

/**
 * Lee y parsea la estrategia del hogar activo. RLS filtra a los hogares del
 * usuario. Si la fila no tiene estrategia (o no existe), devuelve los defaults.
 */
export async function getStrategy(
  supabase: Client,
  householdId: string,
): Promise<HouseholdStrategy> {
  const { data, error } = await supabase
    .from("households")
    .select("strategy")
    .eq("id", householdId)
    .maybeSingle();
  if (error) throw error;
  return parseStrategy(data?.strategy);
}

// ── Motor Waterfall — PORT 1:1 de WaterfallCalculator.swift ───────────────────

/** Una cuenta personal candidata a recibir parte del remanente. */
export interface WaterfallAccount {
  id: string;
  /** Ingreso atribuido a esta cuenta en el período (para modo proporcional). */
  income?: number;
}

/** Inputs del cálculo de la cascada. Espeja los `let` de `WaterfallCalculator` (Swift:24-32). */
export interface WaterfallInput {
  /** Ingreso total del período (suma de INGRESO). Swift `totalIncome()` (Swift:90-94). */
  income: number;
  /** Gastos fijos mensuales activos. Swift `fixedDeduction()` (Swift:96-100). */
  fixedExpenses?: number;
  /** Vencimientos pendientes del mes. Swift `billsDeduction()` (Swift:102-106). */
  bills?: number;
  /** Cuotas no pagadas del mes. Swift `installmentsDeduction()` (Swift:108-112). */
  installments?: number;
  /** Pagos de deuda mensuales de deudas activas. Swift `debtPaymentsDeduction()` (Swift:114-119). */
  debtPayments?: number;
  /** Presupuesto de categorías compartidas (allocations shared). Swift `sharedBudgetsDeduction()` (Swift:121-123). */
  sharedBudgets?: number;
  /** Cuentas personales activas para distribuir el remanente. */
  personalAccounts?: WaterfallAccount[];
}

/** Una cuenta con su parte asignada del remanente. Espeja `AccountAllocation` (Swift:49-54). */
export interface WaterfallAllocation {
  accountId: string;
  amount: number;
  /** Ingreso fuente (modo proporcional). */
  incomeSource: number;
}

/** Resultado completo de la cascada. Espeja `WaterfallCalculator.Result` (Swift:36-47). */
export interface WaterfallResult {
  totalIncome: number;
  fixedDeduction: number;
  billsDeduction: number;
  installmentsDeduction: number;
  debtPaymentsDeduction: number;
  sharedBudgetsDeduction: number;
  /** Sub-total antes de aplicar % ahorro/inversión. */
  beforePct: number;
  savingsAllocation: number;
  investmentAllocation: number;
  remainder: number;
  distribution: WaterfallAllocation[];
}

/**
 * Distribuye el remanente entre cuentas personales. PORT 1:1 de
 * `WaterfallCalculator.distribute(remainder:)` (Swift:126-162):
 *   - equal:        remanente ÷ N
 *   - proportional: remanente × ingresoCuenta / ingresoPersonalTotal
 *                   (fallback a equal si el ingreso personal total es 0, Swift:145-149)
 *   - custom:       monto fijo por cuenta desde `customAllocations` (Swift:156-160)
 */
function distribute(
  remainder: number,
  mode: DistributionMode,
  accounts: WaterfallAccount[],
  customAllocations: Record<string, number>,
): WaterfallAllocation[] {
  if (accounts.length === 0) return []; // Swift:128 guard !personal.isEmpty

  switch (mode) {
    case "equal": {
      const perAccount = remainder / accounts.length; // Swift:132
      return accounts.map((a) => ({
        accountId: a.id,
        amount: perAccount,
        incomeSource: 0,
      }));
    }
    case "proportional": {
      const totalPersonalIncome = accounts.reduce(
        (sum, a) => sum + (a.income ?? 0),
        0,
      ); // Swift:142-144
      if (totalPersonalIncome === 0) {
        // Fallback a equal si no hay ingresos por cuenta (Swift:145-149).
        const perAccount = remainder / accounts.length;
        return accounts.map((a) => ({
          accountId: a.id,
          amount: perAccount,
          incomeSource: 0,
        }));
      }
      return accounts.map((a) => {
        const accIncome = a.income ?? 0;
        return {
          accountId: a.id,
          amount: (remainder * accIncome) / totalPersonalIncome, // Swift:152
          incomeSource: accIncome,
        };
      });
    }
    case "custom": {
      return accounts.map((a) => ({
        accountId: a.id,
        amount: customAllocations[a.id] ?? 0, // Swift:158
        incomeSource: 0,
      }));
    }
  }
}

/**
 * Cascada Waterfall completa — PORT 1:1 de `WaterfallCalculator.calculate()`
 * (Swift:59-86). Misma cuenta, mismo orden, mismos flags:
 *
 *   beforePct = income − fixed − bills? − installments? − debt? − shared   (Swift:67)
 *   savings    = beforePct × savingsPct / 100                              (Swift:68)
 *   investment = beforePct × investmentPct / 100                           (Swift:69)
 *   remainder  = beforePct − savings − investment                         (Swift:70)
 *
 * Los flags `include*InWaterfall` ponen la deducción correspondiente en 0
 * cuando están apagados (Swift:62-64). No se aplica redondeo intermedio (iOS usa
 * Decimal full-precision); el formateo se hace en la capa de UI con `formatMoney`.
 */
export function computeWaterfall(
  input: WaterfallInput,
  strategy: HouseholdStrategy,
): WaterfallResult {
  const income = input.income;
  const fixed = input.fixedExpenses ?? 0;
  // Swift:62-64 — los flags apagan la deducción (la ponen en 0).
  const billsDed = strategy.includeBillsInWaterfall ? (input.bills ?? 0) : 0;
  const instDed = strategy.includeInstallmentsInWaterfall
    ? (input.installments ?? 0)
    : 0;
  const debtDed = strategy.includeDebtPaymentsInWaterfall
    ? (input.debtPayments ?? 0)
    : 0;
  const sharedDed = input.sharedBudgets ?? 0;

  const beforePct = income - fixed - billsDed - instDed - debtDed - sharedDed; // Swift:67
  const savings = (beforePct * strategy.savingsPct) / 100; // Swift:68
  const investment = (beforePct * strategy.investmentPct) / 100; // Swift:69
  const remainder = beforePct - savings - investment; // Swift:70

  const distribution = distribute(
    remainder,
    strategy.distributionMode,
    input.personalAccounts ?? [],
    strategy.customAllocations,
  );

  return {
    totalIncome: income,
    fixedDeduction: fixed,
    billsDeduction: billsDed,
    installmentsDeduction: instDed,
    debtPaymentsDeduction: debtDed,
    sharedBudgetsDeduction: sharedDed,
    beforePct,
    savingsAllocation: savings,
    investmentAllocation: investment,
    remainder,
    distribution,
  };
}
