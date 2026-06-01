/**
 * Calculadoras financieras — matemática pura, sin estado ni I/O.
 *
 * Port FIEL de los cálculos de iOS:
 *   - `Features/Tools/FixedTermCalculatorView.swift`
 *   - `Features/Tools/CompoundInterestCalculatorView.swift`
 *
 * Nota de paridad: la PWA vieja (`src/App.jsx` → `PlazoFijoCalc`) descuenta un
 * 7 % de retención AFIP (específico de Argentina) y muestra una "TNA efectiva
 * neta". La app iOS — fuente de verdad y target US/global — NO aplica retención
 * y reporta interés bruto + TEA por composición. Espejamos iOS.
 */

// ─────────────────────────────────────────────────────────────────────────────
// Plazo fijo (Fixed-Term)
// ─────────────────────────────────────────────────────────────────────────────

export type TermUnit = "days" | "months";

export interface FixedTermInput {
  /** Capital invertido. */
  capital: number;
  /** Tasa Nominal Anual en porcentaje (ej. 120 = 120 %). */
  tnaPct: number;
  /** Magnitud del plazo, interpretada según `unit`. */
  term: number;
  unit: TermUnit;
}

export interface FixedTermResult {
  /** Días totales de la inversión (meses × 30 si la unidad es meses). */
  totalDays: number;
  /** Interés ganado: `capital × tna/100 × días/365`. */
  interest: number;
  /** Capital + interés. */
  total: number;
  /** Tasa Efectiva Anual en porcentaje, por composición del plazo. */
  teaPct: number;
  /** Ganancia equivalente a 30 días (para comparar con ingresos). */
  monthlyEquivalent: number;
  /** Ganancia diaria promedio. */
  dailyEquivalent: number;
}

/**
 * Espeja `FixedTermCalculatorView.swift`:
 *   - totalDays:        L46-51  (.months ⇒ days × 30)
 *   - interest:         L53-59  capital × (tna/100) × (días/365)
 *   - total:            L61-63  capital + interest
 *   - tea:              L65-73  (1 + interest/capital)^(365/días) − 1, en %
 *   - monthlyEquivalent:L75-80  interest × (30 / días)
 *   - dailyEquivalent:  L273    interest / días
 */
export function computeFixedTerm(input: FixedTermInput): FixedTermResult {
  const { capital, tnaPct, unit } = input;
  // Swift hace `Int(days)` en el slider; replicamos el redondeo del plazo.
  const term = Math.floor(input.term);
  const totalDays = unit === "days" ? term : term * 30;

  const zero: FixedTermResult = {
    totalDays,
    interest: 0,
    total: capital > 0 ? capital : 0,
    teaPct: 0,
    monthlyEquivalent: 0,
    dailyEquivalent: 0,
  };

  // Mismas guardas que iOS (capital > 0 && tna > 0 && días > 0).
  if (!(capital > 0) || !(tnaPct > 0) || !(totalDays > 0)) return zero;

  const factor = (tnaPct / 100) * (totalDays / 365);
  const interest = capital * factor;
  const total = capital + interest;

  const ratio = interest / capital;
  const teaPct = (Math.pow(1 + ratio, 365 / totalDays) - 1) * 100;

  const monthlyEquivalent = interest * (30 / totalDays);
  const dailyEquivalent = interest / totalDays;

  return { totalDays, interest, total, teaPct, monthlyEquivalent, dailyEquivalent };
}

// ─────────────────────────────────────────────────────────────────────────────
// Interés compuesto (Compound Interest)
// ─────────────────────────────────────────────────────────────────────────────

export interface CompoundInput {
  /** Capital inicial. */
  principal: number;
  /** Aporte mensual. */
  monthlyContribution: number;
  /** Horizonte en años. */
  years: number;
  /** Tasa anual (TEA) en porcentaje (ej. 8 = 8 %). */
  annualRatePct: number;
}

export interface MonthlyPoint {
  /** Índice de mes (0 = momento inicial). */
  month: number;
  /** Balance tras componer interés y sumar el aporte de ese mes. */
  balance: number;
  /** Capital + aportes acumulados hasta ese mes (sin interés). */
  contributed: number;
}

export interface CompoundResult {
  /** Serie mes a mes [0..months]. */
  projection: MonthlyPoint[];
  /** Balance al final del horizonte. */
  finalBalance: number;
  /** Total aportado (capital inicial + todos los aportes). */
  totalContributed: number;
  /** Interés ganado = finalBalance − totalContributed. */
  interestEarned: number;
  /** Cantidad de meses simulados (años × 12). */
  months: number;
}

/**
 * Espeja `CompoundInterestCalculatorView.swift`:
 *   - months:        L38  years × 12
 *   - monthlyRate:   L39  annualRatePct / 100 / 12
 *   - projection:    L44-62  iteración mensual
 *         balance[t+1] = balance[t] × (1 + r/12) + aporte
 *         contributed += aporte
 *     con el punto 0 = (principal, principal).
 *   - finalBalance / totalContributed / interestEarned: L64-74
 *
 * Caso borde (igual que iOS L45): con `months == 0` la serie es un único punto
 * en el principal y no se aplica interés.
 */
export function computeCompound(input: CompoundInput): CompoundResult {
  const { principal, monthlyContribution, annualRatePct } = input;
  const years = Math.max(0, Math.floor(input.years));
  const months = years * 12;
  const monthlyRate = annualRatePct / 100 / 12;

  if (months <= 0) {
    const point: MonthlyPoint = { month: 0, balance: principal, contributed: principal };
    return {
      projection: [point],
      finalBalance: principal,
      totalContributed: principal,
      interestEarned: 0,
      months: 0,
    };
  }

  const projection: MonthlyPoint[] = [];
  let balance = principal;
  let contributed = principal;
  projection.push({ month: 0, balance, contributed });

  for (let month = 1; month <= months; month++) {
    balance = balance * (1 + monthlyRate) + monthlyContribution;
    contributed += monthlyContribution;
    projection.push({ month, balance, contributed });
  }

  const finalBalance = projection[projection.length - 1].balance;
  const totalContributed = projection[projection.length - 1].contributed;
  const interestEarned = finalBalance - totalContributed;

  return { projection, finalBalance, totalContributed, interestEarned, months };
}

/**
 * Hitos por año para la tabla resumen. Espeja la lógica de iOS
 * `milestonePoints` (L317-331): a 20+ años marca [1,5,10,15,20,final];
 * 10+ → [1,5,10,final]; 5+ → [1,3,5,final]; 2+ → [1,final]; si no → [final].
 * Devuelve los `MonthlyPoint` correspondientes (mes = año × 12), deduplicados.
 */
export function milestonePoints(result: CompoundResult, years: number): MonthlyPoint[] {
  let yearMarks: number[];
  if (years >= 20) yearMarks = [1, 5, 10, 15, 20, years];
  else if (years >= 10) yearMarks = [1, 5, 10, years];
  else if (years >= 5) yearMarks = [1, 3, 5, years];
  else if (years >= 2) yearMarks = [1, years];
  else yearMarks = [years];

  const seen = new Set<number>();
  const out: MonthlyPoint[] = [];
  for (const y of yearMarks) {
    if (seen.has(y)) continue;
    seen.add(y);
    const idx = y * 12;
    const point = result.projection.find((p) => p.month === idx);
    if (point) out.push(point);
  }
  return out;
}
