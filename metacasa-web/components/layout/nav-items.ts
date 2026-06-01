import {
  LayoutDashboard,
  ArrowLeftRight,
  PiggyBank,
  Tags,
  Wallet,
  Target,
  BarChart3,
  Smartphone,
  Settings,
  FileUp,
  Landmark,
  Repeat,
  CalendarClock,
  CreditCard,
  Zap,
  type LucideIcon,
} from "lucide-react";

export interface NavItem {
  href: string;
  /** Clave i18n del namespace `nav` (la resuelve el componente con t()). */
  label: string;
  icon: LucideIcon;
}

/** Navegación principal (sidebar desktop + tab bar mobile). */
export const NAV: NavItem[] = [
  { href: "/dashboard", label: "nav.home", icon: LayoutDashboard },
  { href: "/transactions", label: "nav.transactions", icon: ArrowLeftRight },
  { href: "/budgets", label: "nav.budgets", icon: PiggyBank },
  { href: "/recurring", label: "nav.recurring", icon: Repeat },
  { href: "/bills", label: "nav.bills", icon: CalendarClock },
  { href: "/templates", label: "nav.templates", icon: Zap },
  { href: "/categories", label: "nav.categories", icon: Tags },
  { href: "/accounts", label: "nav.accounts", icon: Wallet },
  { href: "/debts", label: "nav.debts", icon: Landmark },
  { href: "/installments", label: "nav.installments", icon: CreditCard },
  { href: "/goals", label: "nav.goals", icon: Target },
  { href: "/reports", label: "nav.reports", icon: BarChart3 },
];

/** Navegación secundaria (pie del sidebar). */
export const NAV_SECONDARY: NavItem[] = [
  { href: "/import", label: "nav.import", icon: FileUp },
  { href: "/connect", label: "nav.connectApp", icon: Smartphone },
  { href: "/profile", label: "nav.profileSettings", icon: Settings },
];
