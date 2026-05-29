# Auditoría de la app iOS publicada — spec de referencia para el port Flutter

> **Fuente de verdad:** `metacasa-app/metacasa-ios` (app nativa publicada, **v1.0.2 build 10**, ~36k LOC, Swift 6 / iOS 17).
> **NO tocar.** Solo referencia. (Ojo: existe un `~/Desktop/metacasa-ios` standalone OBSOLETO — ignorarlo.)
> Diseño codename **"Midnight Sage"**. App Store name: **Home Finance**. Bundle iOS `com.metacasa.app`.

## 0. Arquitectura general

- **Backend Supabase** (proyecto `rgslvrxdppphzvqgcwbx`, us-east-1) — **se reusa idéntico**, ya es multiplataforma.
- **Sin ledger / sin saldos guardados**: todo es "flujo", se computa al vuelo. Online-first, **sin offline cache, sin realtime**.
- **Estado**: un `@Observable AppState` (auth + household activo + lista de households) + servicios `actor` por entidad (repos finos sobre PostgREST). Sin cache global de datos; cada pantalla fetchea on-demand.
- **Plata = `Decimal`** en todos lados (numeric en Postgres). **En Dart: paquete `decimal`, NUNCA `double`.**

### Tablas Supabase (18)
`households`, `household_members`, `household_invitations`, `accounts`, `credit_cards`, `transactions`, `recurring_transactions`, `transaction_templates`, `bills`, `debts`, `goals`, `goal_contributions`, `installment_plans`, `installment_payments`, `budget_periods`, `budget_allocations`, `categories` (JSONB blob), `user_entitlements`. (+`subscriptions` server-side; ya tiene `play_store` en el enum → listo para Android.)

### RPCs (4)
`create_household(name,currency,timezone)`, `accept_household_invitation(token)`, `envelope_balance(period_id,category,subcategory)` → **la matemática canónica de envelopes vive en SQL, llamarla, no reimplementarla**, `has_active_entitlement(ent)`.

### Edge functions (3) — **reusar tal cual, keys server-side**
- `delete-account` — borrado de cuenta (requisito Apple/Play).
- `ai-proxy` — proxy a Anthropic Claude (key server-side), quota 1000/día 30000/mes, SSE streaming.
- `tts-proxy` — ElevenLabs/OpenAI TTS (keys server-side).

## 1. Modelo de datos (enums = wire format, respetar exacto)

| Modelo | Tabla | Notas clave |
|---|---|---|
| `Transaction` | transactions | `type` = **`GASTO`/`INGRESO`** (mayúscula). `accountId?` (nil = "del hogar"). `amount` en base; FX en `amount_original`/`currency_original`/`fx_rate_to_base`. `period_year/month` server-generated. category/subcategory = **strings, no FK**. |
| `Account` | accounts | `type`: checking/savings/cash/`credit_card`/investment/loan/other. `ownership`: personal/shared/external (driver del waterfall). `startingBalance`. |
| `CreditCardDetails` | credit_cards | 1:1 con account; limit, statementDay, dueDay, interestRateMonthly, minimumPaymentPct, network(visa/mastercard/amex/discover/other). |
| `Bill` | bills | `status`: pending/paid/skipped. `recurring` bool (sin motor). |
| `Debt` | debts | `status`: active/settled. annualRate %, monthlyPayment?, currentBalance. |
| `Goal` + `GoalContribution` | goals / goal_contributions | trigger SQL `tg_goal_contribution_apply` mantiene `current_amount`. status: active/completed/paused/canceled. |
| `InstallmentPlan` + `InstallmentPayment` | installment_plans / _payments | flat (sin interés). Al crear plan se siembran N payment rows. status: active/completed/`cancelled`. |
| `RecurringTransaction` | recurring_transactions | frequency: daily/weekly/monthly/yearly. **Sin motor de generación.** |
| `BudgetPeriod` + `BudgetAllocation` | budget_periods / budget_allocations | envelope. `rollover_mode`: none/surplus/full. upsert onConflict `(period_id,category,subcategory)`. |
| `Household` + members + invitations | households / household_members / household_invitations | `strategy` (JSONB waterfall config), `fx_rates` (JSONB, manual). roles: owner/admin/member/viewer. |
| `CategoriesBlob` | categories | **JSONB por household** (no normalizado). Keys UPPERCASE `GASTO`/`INGRESO` → `[{name,emoji,subcategories}]`. |
| `UserEntitlement` | user_entitlements | escrito por webhook RevenueCat; el cliente solo lee. |

## 2. Lógica financiera (replicar exacto — prioridad #1 correctitud)

- **Saldo de cuenta** (computado, sin guardar): `startingBalance + Σ(signed tx)`, gasto `-amount`, ingreso `+amount`. Tx con `accountId==nil` no afectan ninguna cuenta.
- **Totales del mes** (flujo): `ingresos = Σ amount(INGRESO)`, `gastos = Σ amount(GASTO)`, `balance = ingresos - gastos`.
- **Net worth**: activos (checking/savings/cash/investment/other) − pasivos (credit_card/loan con balance<0 → |balance|; + debts con currentBalance>0). `debtToAssetRatio` clamp 0..1.
- **Envelopes** (canónico en SQL `envelope_balance`): `budgeted = allocated + rollover_from_prev`; `spent = Σ GASTO.amount WHERE category+coalesce(subcategory,'') AND date BETWEEN period`; devuelve **remaining**. Umbrales UI: >0.95 danger, >0.80 warning.
- **Waterfall** (`WaterfallCalculator`): `beforePct = income − fixed − bills − installments − debtPayments − sharedAllocs`; `savings = beforePct*savingsPct/100`; `investment = beforePct*investmentPct/100`; `remainder = beforePct − savings − investment`; distribuir a cuentas personales (equal / proportional-by-income / custom).
- **Debt payoff**: simulación iterativa `balance += interés − pago` (nil si pago ≤ interés; cap 600 meses). `interésMensual = balance*annualRate/1200`.
- **Cuotas**: `monthlyAmount = total/N` (sin interés).
- **Goals ETA**: `avgMonthly = totalContribuido*30/díasDesdePrimerAporte`; `meses = remaining/avgMonthly`.
- **FX**: manual en `households.fx_rates`. `convert = amount * rate[from]`. El insert convierte a base y **pierde** `amount_original`/`fx_rate_to_base` (bug a decidir).
- **Formato plata** (`Money`): `.compact` 0 decimales (default LatAm), `.precise` 2, `.abbreviated` K/M/B/T. Símbolos custom (USD=`U$S`, ARS=`$`, BRL=`R$`...). 29 monedas. Locale es-AR default.

### 🐞 Bugs/gaps documentados (decidir: fix vs replicar)
1. Recurrentes **no se auto-generan** ni avanzan `nextDate`. Solo monthly-GASTO afectan el waterfall.
2. Bills/cuotas **no postean transacción** al marcarse pagas (no afectan saldos).
3. `rollover_from_prev` se lee pero **nunca se calcula** (sin motor de carry).
4. `ready_to_assign` columna nunca se actualiza (Home muestra 0/stale; Budget lo computa live).
5. Multi-moneda insert **descarta** original/rate.
6. Savings/Investment se muestran de 2 formas (gross en Home vs post-deducción en Waterfall).
7. AccountsView muestra `startingBalance`, no el saldo computado.
8. Categorías por **nombre** (rename rompe joins) + mismatch suggester/catalog.

## 3. Diseño — Midnight Sage (dark-first)

| Token | Light | Dark |
|---|---|---|
| appBackground | `#F5F7F4` | `#0E1312` |
| appSurface | `#FFFFFF` | `#151C1A` |
| appSurfaceInset | `#EEF0EC` | `#0B0F0E` |
| appBorder (sage glow) | `#E3E6E1` | `#B8D4C2` @12% |
| textPrimary | `#0E1312` | `#E8E4DC` |
| textMuted | `#5A6560` | `#7A8782` |
| textDim | `#B8BDB6` | `#3E4844` |
| **brandPrimary** (sage) | `#B8D4C2` | (estático) |
| **brandSecondary** (champagne) | `#D4C19C` | (estático) |
| brandSuccess (ingreso) | `#9FC4AD` | (estático) |
| brandDanger (gasto, coral) | `#E8B4A6` | (estático) |

- **Tipografía**: sans **Inter** (SF) + **serif Newsreader** (New York) reservada a montos hero. Sizes: display 36/w900, h1 24/w900, h2 20/w700, body 14/w500, caption 12/w500, label 11/w700 smallCaps; serif hero 52, display 34, title 28, amount 22 (todos w400).
- **Esquinas continuous (squircle)** en TODO → `figma_squircle`. Cards r18–24, botones r20, inputs/pills r14–16.
- **Sage glow**: borde `brandPrimary@0.45` + blur + shadow de color (no negra). Hairline normal = `appBorder`.
- **Haptics** liberales (success/warning/error/selection/impact light-med-heavy).
- → Ya portado en `lib/core/theme/` (colors, dimens, text, theme).

## 4. Navegación
5 tabs nativos: **Inicio** (house.fill) · **Movimientos** (list) · **Agregar** (centro → abre sheet, no navega) · **Presupuesto** (pie) · **Más** (ellipsis). + **FAB Asistente** (sparkles sage) abajo-derecha. `Más` agrupa: Organización (cuentas/metas/recurrentes/vencimientos/cuotas/deudas/envelopes/reportes/comparar/anual/calculadoras/heatmap), Hogar (editar/miembros/categorías), Premium, App (ayuda/ajustes).
Root: Launch → Auth → Crear/Unirse Hogar → gate de trial → app.

## 5. Monetización — **gate DURO, sin free tier por-feature**
- 7 días de trial → después **app bloqueada entera** (`LockedPaywallView` no-dismissible).
- iOS: gate por StoreKit2 directo + RevenueCat (compra) + Supabase entitlement (cache webhook).
- Productos `com.metacasa.premium.monthly` / `.annual`. Entitlement `premium`.
- **Android**: RevenueCat `purchases_flutter` + Play Billing. Anclar trial con timestamp en secure storage (no hay `AppTransaction`). Reproducir ambas paywalls.

## 6. Hogares (multi-usuario)
Roles owner/admin/member/viewer (solo `canInvite` client-side; el resto por RLS). Invitar = email + **token** (paste model, no deep link). Crear/aceptar vía RPC. **Sin realtime** (pull-only). Multi-household (switcher si >1).

## 7. IA Asistente — cascada de 3 niveles
1. Apple FoundationModels on-device (iOS 26) — **NO porta a Android**.
2. **Anthropic Claude `claude-haiku-4-5-20251001`** vía `ai-proxy` (el real). Streaming SSE; loop de tools client-side (max 10).
3. Fallback estadístico offline (intents + templates).
- **22 tools** (function-calling): read (query_transactions, get_financial_summary, get_budget_status, get_net_worth, get_financial_health_score, project_scenario, detect_spending_patterns, suggest_savings_opportunities, get_goals, get_accounts, get_bills, analyze_inflation_impact, compare_periods, categorize_transaction, validate_cfdi, validate_arca) + mutating (add/update/delete_transaction, mark_bill_paid, set_budget_envelope, transfer_between_accounts). Montos en results ISO-prefixed.
- Prompts en `AISystemPromptV2` (full / lite-voice / voice-overrides) + `AppKnowledgeBase`. `FinancialContext` se rearma por mensaje (top categorías, envelopes over/near, anomalías, etc.). Historial cap 8 (chat) / 10 (voz).
- Voz: STT Apple `SFSpeechRecognizer` → `speech_to_text` en Android. TTS: **ElevenLabs Malena** (`p7AwDmKvTdoHTBuueGvP`, `eleven_flash_v2_5`) vía `tts-proxy` + fallback `flutter_tts`.
- Multimodal: OCR (Vision → `google_mlkit_text_recognition`) + recibos vía Claude vision; PDF statements → Claude → CSV; XLSX (`CoreXLSX` → `excel`).
- **Consent sheet** obligatorio (no-dismissible) antes de usar cloud. Modo on-device-only.

## 8. Exports / Reportes / Plataforma
- **Export**: CSV (23 cols, BOM, RFC-4180, formato universal), PDF (Letter + charts), backup JSON. Import CSV/XLSX/PDF.
- **Reportes**: health score, barras 6 meses, Pareto donut, comparar meses, spending heatmap (Swift Charts → `fl_chart`).
- **Plataforma iOS** (equivalentes Android): AppIntents/Siri ×7 → App Shortcuts; Live Activities → notificación ongoing; Spotlight → AppSearch; widget → `home_widget`; notificaciones locales (bills/goals/recurring/envelope/anomaly) → `flutter_local_notifications`.

## 9. Seguridad — gaps a CORREGIR en Android (no replicar)
- Biometría es "advisory" (no bloquea) y sin toggle → implementar gate real con `local_auth` + auto-lock.
- **Sin cert pinning** (CLAUDE.md lo pide) → agregar.
- **Sin root detection** → opcional.
- Keys: anon Supabase OK público; usar `--dart-define`, no hardcodear. Keys de IA/voz **siempre server-side** (ya lo están en las edge functions).
- Account deletion: requisito Play (+ URL pública de borrado en Data Safety).
