# BUILD CONTRACT — Home Finance Web (leer ANTES de escribir código)

App Next.js 15 (App Router, React 19, TS, Tailwind v4) en `metacasa-app/metacasa-web/`.
Backend Supabase compartido con la app nativa (schema canónico). Design system dual:
"Midnight Sage" (oscuro) / "Daylight Sage" (claro), elegido por cookie `mc_theme`.
Idioma de toda la UI: **español rioplatense** ("vos", "tenés"). Tono fintech premium, claro.

## Reglas de oro
- **NO** edites archivos compartidos: `app/globals.css`, `app/layout.tsx`, `app/(app)/layout.tsx`, `middleware.ts`, `lib/supabase/*`, `lib/money.ts`, `lib/constants.ts`, `lib/access.ts`, `lib/household.ts`, `lib/theme.ts`, ni componentes/primitivos existentes ni nada fuera de los archivos que se te asignan.
- **NO** instales dependencias ni toques `package.json`. Si creés que falta una, avisá en tu reporte (no la instales).
- **NO** levantes dev servers ni corras `next build`. Podés correr `npx tsc --noEmit` para chequear, pero ignorá errores en archivos que no son tuyos (otros agentes trabajan en paralelo).
- Seguridad: confiá en RLS. **Siempre** filtrá queries por `household_id`. Nunca loguees tokens/emails/balances. Nada de service_role en el cliente.
- Server Components para fetch; `"use client"` solo para interactividad. Mutaciones vía Server Actions (`"use server"`) + `revalidatePath`.
- Sin estilos inline salvo anchos dinámicos (`style={{ width: \`${pct}%\` }}`). Todo lo demás con clases Tailwind del tema.
- Copy de errores/éxito con `toast` de `sonner`.

## Design tokens (clases Tailwind ya configuradas)
> **La app tiene tema claro y oscuro.** Todo color va por token: **prohibido**
> `bg-white/[0.06]`, `border-white/10`, `bg-black/60`, `shadow-black/50` y hex
> sueltos — rompen en claro. Paletas y ratios de contraste en `app/globals.css`.

- Fondos: `bg-background`, `bg-card`, `bg-surface`, `bg-surface-2`, `bg-inset`. Vidrio: clase `glass`. Glow: `sage-glow`.
- Texto: `text-foreground` (crema en oscuro / verde-carbón en claro), `text-text-muted`, `text-text-dim`.
- Marca/acentos: `text-primary`/`bg-primary` (sage; texto encima usa `text-primary-foreground`), `text-champagne`, `text-income` (ingresos/positivo), `text-expense` (gastos/negativo). Versiones `/12`, `/15` para fondos suaves (verificadas AA).
- Velos (hover, fila activa, chips): `bg-tint-1` (sutil) … `bg-tint-4` (fuerte). Funcionan con variantes: `hover:bg-tint-2`, `focus:bg-tint-2`.
- Otros: `bg-scrim` (overlay de diálogos), `shadow-elevation` (color de sombra), `bg-switch-track`, `segment-on` (segmento/tab activo).
- Charts: importá `CHART` de `@/components/reports/chart-tokens` y `colorForIndex` de `@/components/reports/palette` — ya son CSS vars y cambian con el tema. Para opacidad usá `color-mix(...)`, nunca `${color}2e`.
- Bordes: clase `hairline` (1px tenue) o `border border-border`.
- Radios: `rounded-[var(--radius-md)]` (botón/input), `rounded-[var(--radius-lg)]`, `rounded-[var(--radius-xl)]` (cards), `rounded-full`.
- Números/montos: clase `tnum` (tabular) y `font-num` (serif editorial para saldos grandes).

## Componentes disponibles (importá, NO recrear)
- `@/components/ui/button` → `Button` (variants: default|secondary|outline|ghost|destructive|link; sizes: default|sm|lg|icon; prop `asChild`).
- `@/components/ui/card` → `Card` (prop `glass`), `CardHeader`, `CardTitle`, `CardDescription`, `CardContent`, `CardFooter`.
- `@/components/ui/input` → `Input`. `@/components/ui/label` → `Label`.
- `@/components/ui/badge` → `Badge` (variants: default|neutral|income|expense|warning|outline).
- `@/components/ui/skeleton` → `Skeleton`. `@/components/ui/separator` → `Separator`.
- `@/components/ui/dialog` → `Dialog`, `DialogTrigger`, `DialogContent`, `DialogHeader`, `DialogFooter`, `DialogTitle`, `DialogDescription`, `DialogClose`.
- `@/components/ui/select` → `Select`, `SelectTrigger`, `SelectValue`, `SelectContent`, `SelectItem`, `SelectGroup`, `SelectLabel`.
- `@/components/ui/tabs` → `Tabs`, `TabsList`, `TabsTrigger`, `TabsContent`.
- `@/components/ui/switch` → `Switch`. `@/components/ui/progress` → `Progress` (props `value` 0-100, `indicatorClassName`).
- `@/components/ui/popover` → `Popover`, `PopoverTrigger`, `PopoverContent`.
- `@/components/ui/dropdown-menu` → `DropdownMenu`, `DropdownMenuTrigger`, `DropdownMenuContent`, `DropdownMenuItem` (prop `destructive`), `DropdownMenuLabel`, `DropdownMenuSeparator`, `DropdownMenuGroup`.
- `@/components/ui/empty-state` → `EmptyState` ({ icon?, title, description?, action? }).
- `@/components/layout/page-header` → `PageHeader` ({ title, description?, action? }).
- `@/components/finance/section-header` → `SectionHeader` ({ title, subtitle?, action? }).
- `@/components/finance/amount` → `Amount` ({ value, currency?, kind?: 'gasto'|'ingreso'|'balance'|'neutral', serif?, style?, showSign?, className? }).
- `@/components/finance/transaction-row` → `TransactionRow` ({ tx: Tables<'transactions'>, currency, className? }).
- `@/components/dashboard/flows-chart` → `FlowsChart` ({ data: {month:'YYYY-MM',income,expense}[], currency }) — patrón Recharts a imitar para otros charts.
- Iconos: `lucide-react`. Toasts: `sonner` (`import { toast } from "sonner"`).

## Dinero (`@/lib/money`)
`formatMoney(amount, currency='USD', style?: 'auto'|'precise'|'compact'|'abbreviated')`, `parseMoney(str)`, `formatNumber(n, frac?)`, `symbolFor(cur)`, `currencyLocale(cur)`.

## Constantes (`@/lib/constants`)
`TX_TYPE` ({ EXPENSE:'GASTO', INCOME:'INGRESO' }), `SUPPORTED_CURRENCIES` ([{code,name,symbol}]), `ACCOUNT_TYPE_META` (record type→{label,icon}), `HOUSEHOLD_ROLE_LABEL`, `PREMIUM_ENTITLEMENT`, `ACTIVE_HOUSEHOLD_COOKIE`.

## Supabase + datos
- Server client: `import { createClient } from "@/lib/supabase/server"` → `const supabase = await createClient()` (async!).
- Browser client (en "use client"): `import { createClient } from "@/lib/supabase/client"` → `const supabase = createClient()`.
- Tipo cliente: `import type { Client } from "@/lib/supabase/types"`.
- Tipos de fila: `import type { Tables, TablesInsert, TablesUpdate } from "@/lib/database.types"` → `Tables<'transactions'>`, etc.
- Hogar activo en una page server: `import { resolveActiveHousehold } from "@/lib/household"` → `const { active } = await resolveActiveHousehold(supabase)`; usá `active.id` y `active.default_currency`.

### Módulos de datos existentes (read) — patrón a seguir para tus mutaciones
- `@/lib/db/accounts`: `listAccounts(supabase, householdId)`, `listAccountsWithBalance(...)` → Account & {balance}.
- `@/lib/db/transactions`: `listTransactions(supabase, filters)` → {rows,count}; `getMonthSummary`, `getMonthlyFlows`, `getCategoryBreakdown`.
- `@/lib/db/bills`: `upcomingBills(supabase, householdId, limit?)`.
- `@/lib/db/goals`: `listGoals(supabase, householdId, {activeOnly?,limit?})`.
- `@/lib/db/budget`: `getCurrentPeriod`, `listAllocations`, `envelopeBalance(supabase, periodId, category, subcategory?)`.
- `@/lib/db/categories`: `getCategories(supabase, householdId)` → { gastos?:string[], ingresos?:string[] }.

### Server Action de ejemplo (patrón)
```ts
"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
export async function createX(input: {...}) {
  const supabase = await createClient();
  const { error } = await supabase.from("tabla").insert({ ...input }); // RLS valida
  if (error) throw new Error(error.message);
  revalidatePath("/ruta");
}
```
Nota multi-moneda en transactions: `amount` = monto en moneda BASE del hogar; si la moneda de la tx == base, `fx_rate_to_base=1`, `amount_original=amount`, `currency_original=base`. Si difieren, pedí tasa manual (default 1) y guardá `amount_original`/`currency_original`/`fx_rate_to_base` (amount = amount_original * fx_rate_to_base). `type` ∈ 'GASTO'|'INGRESO'. `date` ISO. `user_id` = (await supabase.auth.getUser()).data.user.id. `household_id` = el hogar activo.

## Rutas: cada pantalla va en `app/(app)/<ruta>/page.tsx` (ya protegida por el layout y con sidebar/topbar). El sidebar ya linkea a todas. Server component hace fetch; abrí diálogos/forms con componentes client.
