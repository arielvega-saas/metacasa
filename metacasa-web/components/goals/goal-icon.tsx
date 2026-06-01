import {
  Target,
  Plane,
  Home,
  Car,
  GraduationCap,
  Gift,
  Heart,
  Umbrella,
  Smartphone,
  PiggyBank,
  type LucideIcon,
} from "lucide-react";

/** Catálogo de íconos disponibles para una meta (clave guardada en `goals.icon`). */
export const GOAL_ICONS = {
  target: Target,
  plane: Plane,
  home: Home,
  car: Car,
  education: GraduationCap,
  gift: Gift,
  heart: Heart,
  umbrella: Umbrella,
  phone: Smartphone,
  savings: PiggyBank,
} as const;

export type GoalIconKey = keyof typeof GOAL_ICONS;

/** Resuelve el ícono de una meta; cae en Target si la clave no existe. */
export function goalIconFor(key: string | null | undefined): LucideIcon {
  if (key && key in GOAL_ICONS) return GOAL_ICONS[key as GoalIconKey];
  return Target;
}
