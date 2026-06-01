import type { Locale } from "../config";
import type { Messages, LocaleModule } from "./types";
import { common } from "./common";
import { authNav } from "./auth-nav";
import { dashboardTx } from "./dashboard-tx";
import { moneyMgmt } from "./money-mgmt";
import { insights } from "./insights";
import { exportTools } from "./export-tools";
import { importTools } from "./import-tools";
import { recurringBills } from "./recurring-bills";
import { debts } from "./debts";
import { installmentsMembers } from "./installments-members";
import { templates } from "./templates";
import { reportsAdvanced } from "./reports-advanced";
import { strategy } from "./strategy";
import { dashboardExtras } from "./dashboard-extras";

const MODULES: LocaleModule[] = [
  common,
  authNav,
  dashboardTx,
  moneyMgmt,
  insights,
  exportTools,
  importTools,
  recurringBills,
  debts,
  installmentsMembers,
  templates,
  reportsAdvanced,
  strategy,
  dashboardExtras,
];

function deepMerge(target: Messages, src: Messages): void {
  for (const k of Object.keys(src)) {
    const v = src[k];
    if (v && typeof v === "object") {
      const existing = target[k];
      const next: Messages =
        existing && typeof existing === "object" ? existing : {};
      deepMerge(next, v);
      target[k] = next;
    } else {
      target[k] = v;
    }
  }
}

/** Diccionario efectivo del locale: merge de todos los módulos de área. */
export function getDictionary(locale: Locale): Messages {
  const out: Messages = {};
  for (const m of MODULES) deepMerge(out, m[locale] ?? {});
  return out;
}
