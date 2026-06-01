import {
  Landmark,
  PiggyBank,
  Wallet,
  CreditCard,
  TrendingUp,
  HandCoins,
  Circle,
  type LucideIcon,
} from "lucide-react";

/**
 * Mapa tipo de cuenta → ícono lucide. Espeja `ACCOUNT_TYPE_META` (que guarda el
 * nombre del ícono como string) resolviéndolo al componente concreto.
 */
export const ACCOUNT_ICON: Record<string, LucideIcon> = {
  checking: Landmark,
  savings: PiggyBank,
  cash: Wallet,
  credit_card: CreditCard,
  investment: TrendingUp,
  loan: HandCoins,
  other: Circle,
};

/** Devuelve el ícono del tipo, con fallback a un círculo neutro. */
export function iconForType(type: string): LucideIcon {
  return ACCOUNT_ICON[type] ?? Circle;
}
