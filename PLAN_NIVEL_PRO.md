# PLAN NIVEL PRO — Home Finance (iOS + Web + Backend)

> Generado 2026-07-27 a partir de 4 auditorías expertas en paralelo: research de mercado fintech 2026,
> auditoría de diseño iOS (162 archivos Swift), auditoría web (metacasa-web + PWA legacy) y auditoría
> de backend (Supabase vivo: advisors, RLS, funciones, edge functions).
> Este archivo es la hoja de ruta ejecutable. Al completar un ítem, marcarlo y anotar fecha.

---

## Diagnóstico en una línea por frente

- **iOS**: 7/10 — la base visual (Midnight Sage + AmountLabel + dashboard editable) ya es diferencial; **no hay que rediseñar, hay que cerrar loops**: widgets que no compilan, Face ID decorativo, sin cache offline, 2 bugs visibles.
- **Web**: `metacasa-web` (Next.js 15, 17 rutas) está al **80% de nivel premium**; el 20% que falta es percepción (motion, loading states, fuentes, landing), no estructura. **La PWA legacy se retira** (es fuente de features, no producto).
- **Backend**: por encima del promedio (RLS completo, tokens cifrados, sin fugas), pero con **drift de migraciones repo↔prod**, sin scheduling (`pg_cron`), y borrado de cuenta que deja PII huérfana.
- **Mercado**: la app ya tiene varios de los top-patterns 2026 (dashboard customizable, privacy mode, número héroe serif, dark design system propio). Los gaps: widgets de sistema, motion/interactividad, IA embebida, paywall estructural.

---

## FASE 1 — Riesgos y bugs (esta semana, orden estricto)

> **Estado 2026-07-27**: 1.1 ✅ · 1.2 ✅ (delete-account v2 deployada) · 1.3 ✅ · 1.4 ✅ · 1.5 ✅ · 1.6 ✅ · 1.7 ✅ · 1.8 **BLOQUEADO EN VERCEL (acción de Ariel)**.
>
> **RESOLUCIÓN 1.8 (2026-07-28)**: diagnóstico confirmado en el dashboard — el **Pro Plan venció** (período 22-jul → 22-ago 2026), la tarjeta **prepaga MasterCard ••••1819** no se pudo cobrar y el team quedó **Suspended** → `DEPLOYMENT_DISABLED` (402). Ariel **no puede pagar ahora**, así que se decidió **migrar a Netlify (plan gratis, que SÍ permite uso comercial)**. Se descartó el Hobby de Vercel: es gratis pero su ToS lo limita a proyectos no comerciales y Home Finance cobra suscripciones — serviría de puente pero puede volver a caerse.
>
> **Bueno saber**: el dominio NO corre riesgo (`usehomefinance.com` renueva 1-jun-2027, `mimundial2026.app` 23-may-2027) y **la PWA legacy de Firebase sigue online** (verificado HTTP 200), así que ningún usuario quedó sin servicio. NO tocar "Reactivate Plan": reintenta el cobro.
>
> **Mitigación aplicada YA (sin release de iOS)**: el banner de handoff de la app mandaba a `usehomefinance.com` → página de error 402. Se comprobó que el iOS abre la URL que **devuelve la edge function** (no la del Info.plist), así que se cambió el fallback de `web-handoff` a la PWA de Firebase. Además, como esa PWA es un SPA sin la ruta `/auth/handoff`, la función ahora **detecta destinos sin soporte de handoff y devuelve la URL pelada** en vez de quemar un magic link que nadie consume — el usuario llega a una web que funciona y se loguea a mano. Verificado en prod: devuelve la URL de Firebase y responde 200. **Revertir a `usehomefinance.com` (o setear el secret `WEB_APP_URL`) cuando Netlify esté sirviendo el dominio.**
>
> **Hallazgo 1.8 (2026-07-27 noche)**: la web YA estaba deployada en prod con `usehomefinance.com` + `www` conectados (deploys por CLI desde fines de mayo), **pero hoy el dominio devuelve HTTP 402 `DEPLOYMENT_DISABLED`** — el team de Vercel (`arielvega-saas-projects`) está pausado por facturación (trial Pro vencido o límite alcanzado). **La web está CAÍDA para usuarios y el banner de handoff de la app iOS abre una página muerta.** Para destrabar: (1) Ariel entra a vercel.com → Settings → Billing del team y resuelve el plan/método de pago; (2) `vercel login` en esta Mac (el token local expiró); (3) desde `metacasa-web/`: `vercel --prod`. Instancia nueva de la lección `leccion-servicios-selfhosted-supervision` — falta healthcheck del dominio.
>
> **Hallazgo adicional durante 1.3 (grave, resuelto)**: la tabla `bills` en prod conservaba el esquema legacy de la PWA y NUNCA tuvo las columnas que el port iOS asumió (`description`, `paid_at`, `account_id`, `note`, `recurring`, `created_by`, `updated_at`) → **el módulo Bills de la app iOS publicada estaba roto contra prod** (decode con campos no-opcionales ausentes + insert con `user_id` NOT NULL sin default). Fix DB-side aditivo en `supabase/migrations/20260727100000_align_bills_schema_ios_and_strict_policies.sql`: columnas agregadas + backfill + `user_id`/`created_by DEFAULT auth.uid()` → la app publicada quedó funcional SIN release nuevo. `database.types.ts` de la web regenerado. Moraleja: sumar al backlog un smoke test E2E por módulo contra prod (la lección `leccion-drift-migraciones-supabase` del harness).

| # | Frente | Qué | Evidencia |
|---|--------|-----|-----------|
| 1.1 | Backend | **Reconciliar ledger de migraciones + aplicar las 2 pendientes.** `20260601100000` (entitlements) está aplicada fuera de registro → `migration repair`; `20260601120000` (envelope_balance multi-moneda) y `20260601120001` (advisor_fixes) **NO están aplicadas** → aplicarlas. De acá en más: todo cambio por CLI/branching, nada por dashboard. | `supabase/migrations/`, ledger vivo termina en `20260531120144` |
| 1.2 | Backend | **Fix delete-account**: borra el user pero deja el hogar entero + transacciones huérfanas (el "job nocturno" del comentario no existe). Borrar households solo-owned antes de `deleteUser`. Riesgo GDPR + App Store 5.1.1(v). | `supabase/functions/delete-account/index.ts` |
| 1.3 | Backend | **Consolidar policies duplicadas** en `bills`/`transaction_templates`: las permissive dobles diluyen el check `user_id = auth.uid()` (un miembro puede insertar bills a nombre de otro). Verificar primero que la app publicada no dependa de la laxa. | pg_policies: `bills_insert` vs `bills_insert_household` |
| 1.4 | iOS | **Fuga del modo privacidad**: con saldos ocultos, `BalanceBreakdownView` y partes de `NetWorthCard` muestran todo (usan `Text(Money.format())` directo). Reemplazar 6 call sites por `MoneyText`. | `HomeView.swift:2019,2042,2064,2145,1841,1917` |
| 1.5 | iOS | **`#if DEBUG` en `notConfiguredCard` del paywall**: hoy puede renderizar "Agregá tu REVENUECAT_API_KEY al Info.plist" en producción (lección `leccion-monetizacion-release`). | `PaywallView.swift:207-218` |
| 1.6 | iOS | **AccountsView muestra `startingBalance`** (saldo inicial, no corriente) — dato incorrecto al usuario. Usar `AccountBalanceService` que ya existe y tiene tests. | `AccountsView.swift:78` |
| 1.7 | Web | **`loading.tsx` + `error.tsx` globales** en `app/(app)/` (hoy: cero). La mejora de percepción de velocidad más barata disponible; `Skeleton` ya existe sin usar. | `metacasa-web/app/(app)/` |
| 1.8 | Web | **Deploy real a Vercel + dominio propio.** Todo el trabajo ya está en `DEPLOY.md`; es ejecutarlo. Actualizar Site URL / redirect URLs en Supabase Auth. | `.vercel/project.json` ya linkeado |

## FASE 2 — Quick wins de percepción (días)

> **Estado 2026-07-27**: 2.1 ✅ · 2.2 ✅ · 2.3 ✅ (barrido i18n por agente) · 2.4 ✅ (glassEffect real con fallback iOS 17-25) · 2.5 ✅ · 2.6 ✅ · 2.7 ✅ (6 charts migrados a tokens + ChartTooltip compartido) · 2.8 ✅ (tsbuildinfo a .gitignore; framer-motion y zod se conservan para Fase 3) · 2.9 ✅ · 2.10 ✅ (allowlist en delete-account/web-handoff/wallet-proxy/ai-proxy; **excepción documentada**: tts-proxy queda con `*` porque solo lo llama la app nativa sin header Origin) · 2.11 ✅ (event_id + unique + upsert ignoreDuplicates, webhook v6) · 2.12 ✅ · 2.13 ✅ (helpers en `app_hidden`, smoke test RLS con impersonación OK) · 2.14 ✅ (wallet-proxy/ai-proxy/web-handoff versionadas + `_shared/cors.ts` como fuente canónica del allowlist).
>
> Pendientes menores anotados por el agente web: tooltip local en `compound-interest-calculator.tsx` y `SPARK_*` en `dashboard-view.tsx` — candidatos a migrar a tokens en otra pasada.

**iOS**
- 2.1 `scrollTargetBehavior(.viewAligned)` + `scrollTransition` en los 3 carruseles (bills, goals, shortcuts) y cards del dashboard — ~20 líneas, "se siente iOS 26 al instante" (`HomeView.swift:1286,1364,1499`).
- 2.2 Skeletons: `.redacted(reason: .placeholder)` en la primera carga del Home (hoy no hay ninguno).
- 2.3 Barrido i18n: ~80 strings hardcodeados en español en HomeView, BalanceBreakdown y **PaywallView completo** → String Catalog. Grep: `grep -rn 'Text("[A-ZÁÉÍÓÚ¿¡]' MetaCasa/Features`.
- 2.4 Liquid Glass real: `if #available(iOS 26.0, *) { .glassEffect(...) }` dentro del modifier `liquidGlass` existente (`Interactions.swift:137-163`) — un archivo, toda la app lo hereda. Contexto: desde abril 2026 todo submit compila con SDK iOS 26; el opt-out muere con iOS 27 SDK (~abril 2027).
- 2.5 Haptics: generators estáticos con `prepare()` + migrar a `.sensoryFeedback` declarativo.

**Web**
- 2.6 SEO: `app/robots.ts`, `app/sitemap.ts`, `opengraph-image`, `metadataBase` (hoy: nada; compartir el link en WhatsApp — el canal LatAm — muestra card pelada).
- 2.7 Unificar colores de charts en `chart-tokens.ts` (`flows-chart.tsx:84-104` tiene literales hardcodeados) + extraer `<ChartTooltip>` compartido.
- 2.8 Deps muertas: decidir `framer-motion` (0 imports → usarlo en Fase 3) y `zod` (0 imports → usarlo en actions o borrar). `tsconfig.tsbuildinfo` a .gitignore.
- 2.9 Manifest: icono maskable 512×512 dedicado + `shortcuts` ("Nueva transacción") + `screenshots`.

**Backend**
- 2.10 CORS: allowlist de orígenes conocidos en las 6 edge functions (hoy `*`).
- 2.11 Webhook RevenueCat: dedupe por `event_id` (`UNIQUE` + `ON CONFLICT DO NOTHING`).
- 2.12 Instalar `pg_cron` + `pg_net` (habilita Fase 3 backend).
- 2.13 Mover helpers de RLS (`is_household_member`, `current_user_household_*`) a schema privado no expuesto por PostgREST (no basta REVOKE: RLS necesita EXECUTE).
- 2.14 Versionar en el repo las edge functions que hoy solo viven en prod (`wallet-proxy`, `ai-proxy`, `web-handoff`).

## FASE 3 — Medianas (1-2 semanas c/u, definen el nivel "premium")

> **Estado 2026-07-28**: 3.1 ✅ · 3.2 ✅ · 3.3 ✅ · 3.4 ✅ (scrubbing con RuleMark + haptic por mes en Reports) · 3.5 ✅ (Dynamic Type real vía `UIFontMetrics` + tiles como Button con label/value/hint) · 3.6 ✅ (badge de ahorro calculado de precios VIVOS + timeline del trial + haptic de selección) · 3.11 ✅ · 3.12 ✅ · 3.7 ✅ (TipKit con reglas por uso + empty states con CTA que abren AddGoal/AddBill) · 3.8 ✅ · 3.9 ✅ · 3.10 ✅ · 3.13 ✅ · 3.14 ✅ · 3.15-3.19 ✅.
>
> **FASE 3 COMPLETA (iOS + web + backend).** El String Catalog pasó de 933 a 952 keys (es/en/pt-BR). Web: 61 tests en verde, `tsc` limpio, `next build` exitoso (35/35 páginas).
>
> **Bug de dinero encontrado por los tests nuevos (3.14) y corregido en `lib/money.ts`**: `parseMoney` devolvía **1,234** tanto para `"1,234,567"` (usuario US) como para `"1.234.567"` (usuario LatAm) — `String.replace(",", ".")` sólo reemplaza la PRIMERA ocurrencia y `parseFloat` corta en el segundo separador. Un movimiento de 1,2 millones se guardaba como 1,23. Reescrita con reglas explícitas (el separador más a la derecha es decimal; múltiples separadores iguales son de miles) y verificada a mano contra 12 casos. El caso genuinamente ambiguo (`"1.234"` → 1,234) no cambió, así que no hay regresión.
>
> **Dashboard web**: de 11 queries bloqueantes a 3 + 6 secciones que se transmiten con `<Suspense>`.
>
> **Nota de entorno (confirma `entorno-icloud-desktop-lentitud`)**: el `next build` tardó **52 minutos** con el worker de webpack al ~2,7% de CPU — I/O-bound por iCloud, no por el código. Vale mover el repo fuera del Desktop sincronizado, como ya se hizo con StageForge y VegaOS.
>
> **Nota sobre 3.5**: la tentación era migrar los tokens a los text styles de Apple, pero eso achicaba el balance héroe de 52pt a 34pt. Se usó `UIFontMetrics(forTextStyle:).scaledFont(for:)` con los tokens declarados como `static var` (no `let`): conserva la escala "Midnight Sage" en el tamaño por defecto, escala de verdad con Dynamic Type, y al ser computados se recalculan cuando el usuario cambia el tamaño de texto (un `let` habría quedado cacheado por proceso).
>
> **Bugs reales encontrados al activar el widget (3.1)** — todos arreglados:
> 1. `BillReminderAttributes` (app) vs `BudgetActivityAttributes` (extension) eran tipos DISTINTOS → la Live Activity habría arrancado sin UI. Los attributes ahora viven en `MetaCasaWidgets/BillReminderAttributes.swift`, compilado en AMBOS targets, + UI nueva en `BillReminderLiveActivity.swift`.
> 2. `WidgetSnapshotSync.writeLatest` armaba un `[String: Any]` con `Optional.none as Any` cuando no había vencimientos → `JSONSerialization` fallaba y **el widget nunca recibía datos**. Ahora usa el struct `WidgetSnapshot` compartido.
> 3. La moneda de Live Activity y Spotlight estaba hardcodeada en `"USD"` → un hogar en ARS habría visto dólares. Ahora la vista inyecta la moneda real antes del load.
> 4. `NetWorthBreakdown`/`AccountBalance` no eran `Codable` (rompía el snapshot del Home) y `BudgetLiveActivity` tenía un ternario que mezclaba `HierarchicalShapeStyle` con `Color`.
>
> **Requisito manual pendiente para que el widget funcione en device**: crear el App Group `group.com.metacasa.shared` en el Developer Portal y habilitarlo en los App IDs `com.metacasa.app` y `com.metacasa.app.widgets` (los entitlements ya lo declaran). Sin eso, compila e instala pero el widget muestra el estado vacío.

**iOS**
- 3.1 **Activar target MetaCasaWidgets + Live Activity de bills** — el código de vistas YA está escrito (`MetaCasaWidgets/BalanceWidget.swift`, el YAML exacto está en su comentario líneas 10-24); falta target en `project.yml` + App Group `group.com.metacasa.shared` + `ActivityConfiguration`. Impacto muy alto: Home/Lock Screen/Dynamic Island.
- 3.2 **Face ID lock real**: estado `.locked` en RootView + re-lock en background (grace ~60s) + shield del app switcher + toggle en Settings (~80 líneas). Hoy pide biometría y si falla abre igual.
- 3.3 **Cache snapshot del Home** (stale-while-revalidate, mismo patrón que `WidgetSnapshot`) + **RPC `net_worth` server-side** (hoy baja 10.000 transacciones por pull-to-refresh). Patrón `envelope_balance` SECURITY DEFINER ya existe.
- 3.4 Charts interactivos: `.chartXSelection` + annotation + `.sensoryFeedback` en Reports (el scrubbing es EL gesto premium de Copilot).
- 3.5 Dynamic Type (tokens `Font.mc*` con `relativeTo:` — hoy tamaños fijos, cero soporte) + pase VoiceOver (7 labels en toda la app; tappables a `Button`; `AXChartDescriptor`).
- 3.6 **Paywall pro**: RevenueCatUI Paywalls (A/B desde dashboard) o custom. Datos RevenueCat 2026: trial 7 días +38-52% conversión; anual preseleccionado con mensual decoy → 69-74% eligen anual; timeline visual del cobro reduce cancelaciones; top vs bottom quartile de paywall = 4x revenue.
- 3.7 TipKit (4-5 tips con reglas) + empty states con CTA por widget del Home (funnel de activación).

**Web**
- 3.8 **Capa de motion** con framer-motion: AnimatePresence en dialogs, stagger 40ms en KPIs, contador animado en saldos hero, barras de metas animando al entrar en viewport. Respetar `data-reduce-motion` ya existente.
- 3.9 Suspense/streaming en dashboard (hoy: 11 queries en `Promise.all` antes de pintar un byte — KPIs primero, resto async).
- 3.10 `useOptimistic` en transacciones, bills y metas (React 19 ya está).
- 3.11 **Landing `app/(marketing)`** rebrandeada Midnight Sage (portar bloques de `marketing/Landing/index.html`, que hoy usa una TERCERA paleta) + retiro de Firebase con redirects 301.
- 3.12 `next/font` self-hosted: serif variable (Fraunces/Newsreader) + sans — hoy el "serif editorial" solo existe en Apple; en Windows/Android cae a Georgia.
- 3.13 Command palette ⌘K (`cmdk`): navegación + nueva transacción + búsqueda. Estándar fintech premium 2026.
- 3.14 Tests de `lib/money.ts`, `lib/fx.ts` y health score (lógica financiera pura; Vitest, una tarde).

**Backend**
- 3.15 Jobs `pg_cron`: materializar recurring/installments, recordatorios de bills (`reminder_days` hoy no dispara nada), limpieza de hogares huérfanos, barrido de trials.
- 3.16 Realtime: agregar tablas core a la publication (hoy vacía) + suscripción por household en iOS/web — el sync multi-dispositivo hoy es polling.
- 3.17 Soft-delete (`deleted_at`) + `audit_log` append-only + `updated_at` en `transactions` (hoy no se puede auditar una edición).
- 3.18 Sentry + logging estructurado en las 6 edge functions; tabla de log de webhooks RC para reconciliación.
- 3.19 `period_year/month` como columnas GENERATED (hoy las calcula el cliente, nullable, riesgo de drift) + `numeric(19,4)` en dinero.

## FASE 4 — Apuestas grandes (semanas+, estratégicas)

> **Estado 2026-07-28**: 4.1 ✅ · 4.2 ✅ · 4.3 ✅ · 4.4 ✅ · 4.5 ✅ · 4.7 ✅ · 4.8 ✅ · 4.9(tests) ✅. **8 de 11.** Pendientes, TODOS bloqueados por credenciales/decisión de Ariel: 4.6 (SIWA — necesita Service ID + key en Apple), 4.9(CI — necesita el código en GitHub), 4.10 (push APNs — necesita key de Apple), 4.11 (iPad — no bloqueado, pero es polish y la app es iPhone-only por decisión).
>
> **4.8 PWA offline ✅ — 132 tests verdes, build OK, `public/sw.js` (44 KB) verificado.** La decisión que define esta feature: **NO cachear nada financiero**. Supabase, `/api/*`, `/auth/*` y los payloads RSC van NetworkOnly; las navegaciones son NetworkFirst pero un guard sólo persiste páginas PÚBLICAS (y sólo `200` + `basic` + `!redirected`), así que las rutas de la app no dejan rastro y offline caen a `/~offline` en vez de mostrar saldos viejos. Se descartó el `defaultCache` de serwist a propósito, porque cachea HTML y prefetch RSC — o sea, saldos. Estáticos/fuentes/íconos sí van CacheFirst.
>
> **Dos bugs de auth que el SW destapó** (requirieron tocar `middleware.ts`, marcado como "no editar", con razón justificada): (1) `/sw.js` no estaba excluido del matcher, así que a un usuario sin sesión se le redirigía a `/login` y **el service worker nunca se registraba**; (2) sin `/~offline` en las rutas públicas, el precache guardaba el login como "página offline".
>
> **4.3(b) Insights en pantalla ✅** — con 0 insights la sección **no renderiza nada** (ni card ni encabezado): el RPC sólo devuelve desvíos ≥25%, así que lo normal es que no haya nada, y una card de "todo tranquilo" permanente entrena al usuario a ignorar justo la zona donde después aparece la alerta que importa. Los colores comunican *atención* (champagne) vs *vas bien* (income), NO gasto/ingreso — y el monto va `kind="neutral"` porque con `kind="gasto"` habría salido coral con signo menos, contradiciendo el mensaje. Ambos montos usan `<Amount>` para respetar el modo privacidad (con `formatMoney` crudo se filtraban).
>
> **4.1 Cache offline SwiftData ✅** — read-through en los 4 services más leídos. **BUILD SUCCEEDED + 31/31 tests.** Tres decisiones que valen:
> 1. **`CachedWindow` (ventana de cobertura)**: sin esto, el fetch del mes del Home pisaba el del año de Reports y offline se servía un mes **haciéndolo pasar por el año** — totales falseados sin que se note. Sólo se sirve cache si la ventana pedida está *contenida* en la cubierta, y la cobertura se recorta sola cuando el fetch se truncó por `limit`.
> 2. **Red ≠ auth**: sólo se cae al cache ante fallas de conectividad y 5xx. Un 401/4xx se propaga tal cual para que el refresh de JWT funcione — servir datos viejos ante un token vencido sería enmascarar un problema de sesión.
> 3. **El banner usa el sync MÁS VIEJO en pantalla**, no el más nuevo, y se sostiene 3s en loads mixtos: con ~10 requests en paralelo, el último en terminar no decide el cartel al azar. Nunca mostrar números viejos como si fueran de ahora.
> Si el store no abre: log + `captureError`, borra y reintenta UNA vez, y si falla corre en modo sin-cache. Cero `try!` — es una app publicada.
>
> **Bug de crash garantizado encontrado por los tests**: el modelo tenía una propiedad llamada **`entity`**, nombre reservado de CoreData. Compilaba, pero al primer fetch tiraba `NSInternalInconsistencyException` — una excepción de Objective-C que **`try?` no atrapa**. Renombrada a `kind`. Además `groupContainer: .automatic` hacía caer el store en el App Group del widget; se fijó en `.none`. → memoria `leccion-swiftdata-nombres-reservados`.
>
> **4.2 Wallets LatAm ✅ — el bloqueante para retirar la PWA ya no existe.** Antes de construir verifiqué contra la function viva que **MP_CLIENT_ID/SECRET ya están configurados** (el `oauth_exchange` con un código falso devolvió `invalid_grant` de Mercado Pago, no el 503 de "no configurado"). Portado a `metacasa-web`: conector puro testeable, server actions (OAuth con `state` en cookie httpOnly + `timingSafeEqual`, sync con dedupe por `external_id`, import selectivo que **pre-categoriza con el RPC `suggest_category`** de 4.3), ruta `/wallets` + callback, i18n es/en/pt. 103 tests verdes, tsc limpio, build OK. El token nunca se guarda en claro (el trigger `encrypt_access_token_trigger` cifra y anula el plaintext) y `lib/db/wallets.ts` nunca lo selecciona.
>
> **Hallazgo de seguridad verificado y parcialmente cerrado**: `anon` y `authenticated` tenían SELECT/INSERT/UPDATE sobre `connected_wallets.access_token_encrypted`. Severidad real BAJA (cifrado con clave en Vault + RLS por dueño → como mucho veías el ciphertext de tu propia credencial), pero es material criptográfico expuesto de gaste. **Revocado para `anon`** (riesgo de rotura cero). Para `authenticated` quedó documentado en `supabase/migrations/20260728130000_wallet_token_grants.sql` con la secuencia correcta: revocar SELECT rompería la PWA legacy, que hace `select('*')` — y hoy la PWA es la única web operativa porque Vercel está pausado. Se cierra después de reactivar Vercel y retirar Firebase.
>
> **Pendiente de Ariel para activar wallets**: registrar la redirect URI en el panel de MP (app `2693470312497962`) → `https://usehomefinance.com/wallets/callback` (+ `http://localhost:3000/wallets/callback` para dev). Sin eso MP rechaza con `invalid_redirect_uri`.
>
> **4.7 Light mode "Daylight Sage" ✅** — paleta clara propia (no el oscuro invertido): base crema #F2EFE6, verde-carbón para texto, sage y terracota ajustados. Todos los tokens ≥4.5:1 AA, con los ratios documentados en el CSS. Sin flash: preferencia en **cookie** (no localStorage) para que el Server Component ya renderice la clase correcta, + script inline en `<head>` para el caso `system`. 44 archivos migrados de clases hardcodeadas (`bg-white/[0.06]`, hex sueltos) a tokens con **alfa distinta por tema** (un velo oscuro sobre crema pesa ~1,6× lo que pesa blanco sobre negro). 73 tests verdes, tsc limpio, build OK.
>
> **Bug preexistente encontrado de paso**: `.glass` declaraba `backdrop-filter` ANTES de `-webkit-backdrop-filter`, y Lightning CSS dedupeaba dejando sólo la variante webkit → **sin blur en Firefox**, también en el tema oscuro. Corregido.
>
> **Contraste del tema OSCURO corregido (deuda que este trabajo destapó)**: `--mc-text-dim` era #3e4844 = **1.98:1** y `--mc-text-muted` #7a8782 = 4.25:1 sobre superficies elevadas — ambos por debajo de AA. `dim` estaba documentado como "decorativo", pero se usa en **133 lugares** para hints y captions (texto informativo real, no elementos deshabilitados, que sí estarían exentos). Se subieron a #7e8c86 y #9fb0a9: los tres niveles quedan en ≈14.8 / 8.3 / 5.3 sobre el fondo, todos AA en el peor caso (surface-2), conservando el matiz verde-gris y un salto de jerarquía perceptible. Ratios calculados, no estimados.
>
> **Pendientes menores señalados** (no bloquean): en la PWA instalada en iOS la status bar sigue fija en oscuro (`statusBarStyle: black-translucent` + `theme_color` del manifest) — con tema claro queda texto blanco sobre crema; requiere decisión de producto.
>
> **4.9 pgTAP — 14/14 en verde contra prod.** `supabase/tests/rls_isolation.sql`: dos usuarios en dos hogares y se verifica que ninguno vea ni escriba lo del otro, más los triggers de dinero (fill_period, audit_log, learn_category y la corrección que pisa la regla). Corre todo dentro de una transacción con ROLLBACK — **confirmado que no dejó ni una fila** en producción. Gotchas documentados en el archivo: `plan(N)` va antes del primer test, y las temp tables del fixture necesitan GRANT explícito al rol `authenticated` (incluida la secuencia del serial). Falta engancharlo a CI.
>
> **4.5 FX automático — VIVO en prod.** Arquitectura sin edge function ni secretos: `pg_net` es async, así que el ciclo va en dos jobs encadenados (`fx_fetch` 09:40 UTC → `fx_process` 09:45). Fuentes: `open.er-api.com` (11 monedas) + **`dolarapi.com` blue para ARS**, que pisa al oficial — ese override ES el diferencial LatAm (hoy: blue 1560 vs oficial ~1470). Propaga a `households.fx_rates` derivando `rate = r[base_hogar]/r[moneda]`. **Verificado en prod**: matemática correcta en las 5 monedas base que existen (ARS/COP/EUR/HKD/USD) y, lo más importante, **una cotización con `source='manual'` NO se pisa** (probado inyectando una y revirtiéndola después).
>
> **4.4 Agregados — VIVO en prod.** `mv_household_month_summary` (matview con índice único → `REFRESH CONCURRENTLY`, no bloquea lecturas) + `account_balance_snapshots` diarios + `month_summary()` RPC. Se eligió matview sobre tabla incremental por triggers porque los montos se editan y borran: una tabla incremental acumula deriva ante cualquier bug, el matview siempre coincide con la verdad. **Verificado**: 13 filas contrastadas contra el cálculo directo, 0 discrepancias; y `month_summary` levanta excepción al pedir un hogar ajeno (es SECURITY DEFINER, así que se testeó explícitamente).
>
> **4.3(a) Categorización que aprende — VIVO en prod.** `category_rules` por hogar + trigger `learn_category` + `suggest_category()`. Server-side a propósito: antes el keyword-map estaba duplicado en el cliente y no aprendía. **Decisión clave**: una corrección del usuario GANA sobre el histórico (cambia la regla ya y resetea `hits`), porque recategorizar y que la app siga sugiriendo lo viejo se siente roto. Sembrado con el historial propio de cada hogar → 71 reglas en 6 hogares desde el día uno. **Verificado**: sugiere por coincidencia parcial, aprende de la corrección, y no filtra reglas entre hogares.
>
> **Hardening de paso**: los advisors marcaron 3 funciones nuevas con `search_path` mutable y `month_summary` invocable por `anon` — corregidos ambos.

- 4.1 **[iOS] SwiftData como cache offline completo** de transactions/accounts con sync incremental — paridad estructural con Copilot/Monarch (local-first = velocidad percibida ES diseño). Ya previsto como Fase 3.4 del roadmap.
- 4.2 **[Web] Portar wallets LatAm (Mercado Pago OAuth) a metacasa-web** — el diferencial competitivo vive solo en la PWA legacy; la edge function `wallet-proxy` ya existe. **Prerequisito del retiro total de la PWA.** Al portar: la anon key hardcodeada de `src/services/wallets.js:8` pasa a env.
- 4.3 **[Producto] IA embebida, dos vías** (patrón Revolut AIR + Copilot): (a) invisible — categorización que aprende de correcciones, server-side con tabla `category_rules` + `ai-proxy`; (b) conversacional — asistente invocable con insights proactivos ("este mes el hogar gastó 25% más en delivery"). `ai-proxy` con quota ya existe; es EL diferencial 2026.
- 4.4 **[Backend] Vistas materializadas de balances** (`mv_household_month_summary`) + snapshots diarios de cuentas — lo primero que se rompe con 10k usuarios es recomputar todo desde `transactions`.
- 4.5 [Backend] FX automático: edge function + pg_cron diario (dólar blue para ARS); unificar tabla `fx_rates` (hoy 0 filas) vs JSONB en `households` — una sola fuente.
- 4.6 [iOS] Sign in with Apple + passkeys vía Supabase (`signInWithIdToken`) — fricción de signup vs todos los competidores.
- 4.7 [Web] Light mode (el mapeo semántico ya está; falta paleta light + toggle SSR-safe). [iOS] ya lo tiene.
- 4.8 [Web] Offline con serwist + banner de instalación; curaduría de los mejores ~15 widgets de la PWA legacy como sección "Insights" (donde la legacy le gana a Monarch en profundidad).
- 4.9 [Backend] pgTAP (tests de RLS multi-hogar y triggers) + Supabase branching + CI — elimina el drift de raíz.
- 4.10 [Backend] Push notifications APNs: alertas de envelope 80/95/100%, vencimientos de TC, bills.
- 4.11 ✅ **parcial (2026-07-31)** [iOS] Migrado a la **Tab API de iOS 18+** con `.tabViewStyle(.sidebarAdaptable)`, que da el sidebar de iPad sin escribir un `NavigationSplitView` a mano ni duplicar la jerarquía; iOS 17 conserva el camino legacy. **Falta la decisión de Ariel**: el target sigue `TARGETED_DEVICE_FAMILY: "1"` (iPhone-only). Habilitar iPad es cambiar ese flag, pero implica que App Review pruebe la app en iPad y que haya que subir screenshots de iPad — es decisión de tienda, no de código. Pendientes menores: `.tabViewBottomAccessory` iOS 26 (se omitió a propósito: sin un contenido que gane el espacio permanente es decoración) y `.navigationTransition(.zoom)` cards→detalle.

---

## Patrones de mercado a adoptar (research 2026, rankeados)

Ya los tenemos ✅ / nos faltan ❌:

1. ✅ Dashboard de widgets customizable (Monarch/Revolut 10) — iOS ya lo tiene con `DashboardEditorSheet`.
2. ✅ Modo oculto de saldos "ojito" (estándar absoluto LatAm: MP/Ualá/Nubank/Naranja X) — iOS lo tiene (tapar la fuga, ítem 1.4); **web no lo tiene → agregarlo**.
3. ✅ Número héroe serif con tabular figures (Nubank/Monzo) — ya es identidad de la app.
4. ✅ Swift Charts interactivos con scrubbing (Copilot, Apple Design Award) — hecho en **3.4** (RuleMark + haptic por mes en Reports).
5. ✅ **parcial** Liquid Glass: el modifier real con fallback iOS 17-25 está en **2.4**. Falta el morph del FAB con `GlassEffectContainer`..
6. ✅ Widgets de sistema + Dynamic Island — hecho en **3.1**. ⚠️ En device muestran estado vacío hasta que exista el App Group `group.com.metacasa.shared` en el Developer Portal.
7. ✅ **(2026-07-31)** Anillos/diales de presupuesto animados con semáforo + proyección "a este ritmo llegás al 110%" (Copilot). `BudgetRing` + `BudgetPace` (12 tests). El anillo **reemplaza** a la barra lineal de la fila de envelope: dos representaciones del mismo porcentaje era ruido. Lo que define la feature es **cuándo calla**: antes del 15% del período (una compra el día 1 proyectaría 31× y alarmaría por algo normal), sobre un mes cerrado (ahí el gasto es un hecho, decir "proyectado" sería falso), sobre un mes futuro, y cuando el envelope YA se pasó (avisar de un 110% futuro sobre algo que ya ocurrió suena roto). Semáforo extraído a `EnvelopeStatus.severity` para que anillo, texto y color no puedan divergir; tick de proyección topeado en una vuelta para que 300% no dé tres vueltas.
8. ✅ **parcial (2026-07-31)** Metas como "cajitas/pots" con fondeo de un toque + confeti + haptic. `GoalQuickFund` (13 tests) propone hasta 3 montos derivados de **lo que falta** (no del objetivo: si faltan $1.000, ofrecer "$5.000" haría pasarse de largo), redondeados hacia abajo a dos cifras significativas para que se lean como montos elegidos por una persona. Antes aportar costaba 5 pasos; ahora el caso común es un toque + confirmación. **La confirmación es deliberada a propósito**: se descartó el drag-para-fondear estilo Monzo porque un gesto que mueve plata según la distancia del arrastre genera aportes accidentales — en una app de finanzas eso no es "delightful", es un bug. De paso se cableó `ConfettiOverlay`, que existía sin usarse en ningún lado. **Falta el "Salary Sorter"** (repartir el ingreso del mes entre presupuestos), que es la mitad grande de esta idea y encaja con el waterfall multi-persona (ADR-008).
9. ✅ IA embebida — hecho en **4.3**: categorización que aprende de correcciones (server-side, `category_rules` + trigger) e insights en pantalla.
10. ❌ Grilla de accesos rápidos LatAm bajo el saldo (MP/Nubank shortcuts) — iOS tiene shortcuts carousel; elevarlo a fila de acciones circulares primarias.
11. ❌ Onboarding de confianza gradual: modo manual/demo antes de pedir datos + quiz corto que personaliza + checklist gamificada (Copilot/Monarch/YNAB) — hay base (`WelcomeTourView` + `SetupChecklistCard`).
12. ✅ Paywall estructural — hecho en **3.6** (badge de ahorro con precios vivos, timeline del trial, haptic de selección).
13. ✅ **parcial (2026-07-31)** Feed de movimientos: densidad Monarch, chevron › y subtotales por día hechos. **Falta sólo los logos de comercio**, que necesitan una fuente de logos (Clearbit/Brandfetch) y decisión de privacidad: resolver el logo desde el cliente filtra el nombre del comercio a un tercero..
14. ✅ Insights proactivos — hecho en **4.3(b)**. Con 0 insights la sección no renderiza nada, a propósito.
15. ✅ **parcial** Motion: web con framer-motion en **3.8**, iOS con scrollTransition y haptics en **2.1/2.5**, anillos animados hoy. Todo respeta `reduceMotion`. Falta una pasada de coherencia (viscosidadsiempre).

Lecciones de mercado clave: Mercado Pago **revirtió** su cambio de identidad a amarillo (la identidad de una app financiera no se toca a la ligera — defender Midnight Sage); Ualá optimiza transiciones para gama media (relevante Android futuro); la home de Ualá se **reordena por IA** según uso real.

---

## Decisión estratégica web (del auditor, para ratificar por Ariel)

**`metacasa-web` es el futuro.** Deploy a producción con dominio propio ya; landing adentro como `(marketing)`; PWA de Firebase se retira con 301 **solo después** de portar wallets LatAm (4.2). No invertir ni una hora más de UI en `src/App.jsx`. No hay migración de datos (mismo Supabase).

## Verificaciones pendientes en dashboards (no automatizables)

- Supabase: plan de backups / **PITR** (no-negociable antes de usuarios pagos), MFA/TOTP disponible, expiración OTP.
- RevenueCat: productos reales + verificar que el paywall bloquea (playbook release del harness).

## Fuentes principales del research

Apple (developer.apple.com: Copilot Money case, HIG Liquid Glass), building.nubank.com, revolut.com/news (Revolut 10, AIR), raggededge.com (Monzo), buck.co (Cash App), monarch.com/blog (refresh 2025), revenuecat.com/blog (benchmarks 2026), conor.fyi/writing/liquid-glass-reference, screensdesign.com (Copilot/Monarch/YNAB teardowns). URLs completas en el informe de research (sesión 2026-07-27).
