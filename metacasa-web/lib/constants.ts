/** Constantes de dominio compartidas. Alineadas con el schema canónico + iOS. */

export const TX_TYPE = { EXPENSE: "GASTO", INCOME: "INGRESO" } as const;
export type TxType = (typeof TX_TYPE)[keyof typeof TX_TYPE];

export const SUPPORTED_CURRENCIES = [
  { code: "USD", name: "Dólar estadounidense", symbol: "US$" },
  { code: "ARS", name: "Peso argentino", symbol: "$" },
  { code: "EUR", name: "Euro", symbol: "€" },
  { code: "BRL", name: "Real brasileño", symbol: "R$" },
  { code: "MXN", name: "Peso mexicano", symbol: "$" },
  { code: "CLP", name: "Peso chileno", symbol: "$" },
  { code: "COP", name: "Peso colombiano", symbol: "$" },
  { code: "PEN", name: "Sol peruano", symbol: "S/" },
  { code: "UYU", name: "Peso uruguayo", symbol: "$U" },
  { code: "GBP", name: "Libra esterlina", symbol: "£" },
] as const;

/** Tipos de cuenta (match con el CHECK de la tabla `accounts`). */
export const ACCOUNT_TYPE_META: Record<
  string,
  { label: string; icon: string }
> = {
  checking: { label: "Cuenta corriente", icon: "Landmark" },
  savings: { label: "Caja de ahorro", icon: "PiggyBank" },
  cash: { label: "Efectivo", icon: "Wallet" },
  credit_card: { label: "Tarjeta de crédito", icon: "CreditCard" },
  investment: { label: "Inversión", icon: "TrendingUp" },
  loan: { label: "Préstamo", icon: "HandCoins" },
  other: { label: "Otra", icon: "Circle" },
};

/** Roles del hogar (match con `household_members.role`). */
export const HOUSEHOLD_ROLE_LABEL: Record<string, string> = {
  owner: "Propietario",
  admin: "Administrador",
  member: "Miembro",
  viewer: "Solo lectura",
};

/** Entitlement premium (RevenueCat). */
export const PREMIUM_ENTITLEMENT = "premium";

/** Cookie donde guardamos el hogar activo seleccionado. */
export const ACTIVE_HOUSEHOLD_COOKIE = "mc_active_household";
