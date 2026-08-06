# Home Finance — estado vivo

> Última actualización: **2026-08-04**.
> Este archivo es lo primero que tiene que leer cualquier IA que entre al proyecto.
> Si trabajaste acá y algo de esto cambió, **actualizalo antes de cerrar la sesión**.

## Sesión 2026-08-06 — fila de acciones primarias

**Ítem 10 del plan, hecho.** Cuatro círculos pegados al saldo —Gasto, Ingreso, Vencimiento,
Preguntar— como MP/Nubank/Ualá. Gasto e Ingreso abren el alta con el tipo **ya elegido**: ese
toque del selector es el que se saltea y hace que un sueldo entre cargado como gasto. Va fija,
no como widget del dashboard: si se pudiera ocultar dejaría de ser primaria. Verificada en el
simulador.

**Del ítem 11 (onboarding), lo que realmente falta es menos de lo que decía el plan:**
- ✅ La **checklist gamificada ya existía** y está bien resuelta: `OnboardingProgress`
  auto-detecta cada paso consultando los servicios reales, así que nunca miente sobre el
  estado. El plan la listaba como pendiente.
- ❌ **Quiz de personalización.** Lo valioso sería preguntar **cada cuánto cobra** el usuario
  (`PeriodType` ya soporta week/biweek/month) y qué quiere lograr primero, para preconfigurar
  el período del presupuesto y el orden de los widgets. Hoy el presupuesto es mensual sí o sí:
  para alguien que cobra quincenal, la app arranca desalineada con su realidad.
- ❌ **Modo demo antes de pedir datos.** Es un **cambio de arquitectura**, no una pantalla: la
  app necesita sesión de Supabase para todo. Requiere una capa de datos local de sólo lectura
  y decidir qué pasa al registrarse (¿se migran los datos de prueba o se descartan?). No
  conviene hacerlo apurado.

---

## Sesión 2026-08-05 — la 1.1.0 enviada y tres bugs más

**La 1.1.0 (build 13) está EN REVISIÓN en App Store.** Archive, export firmado, `VERIFY
SUCCEEDED`, upload con la API key, versión creada, novedades en los tres idiomas (son
obligatorias en los tres: el primer envío falló por eso) y enviada.

**Dos bloqueos documentados que ya no existen:**
- **El App Group `group.com.metacasa.shared` YA ESTÁ**: existe en el portal, habilitado en
  `com.metacasa.app` y `com.metacasa.app.widgets`, y el binario lo lleva firmado en la app y en
  el appex. Verificado con `codesign -d --entitlements`.
- Los códigos promocionales de App Store **no sirven** para desbloquear premium: son códigos *de
  la app*, que es gratuita. La vía es TestFlight, donde las compras son sandbox.

**Tres bugs arreglados (no van en la 1.1.0, que ya está en la cola):**
1. **Quien pagaba fuera de iOS quedaba bloqueado igual.** El gate miraba trial + StoreKit, y
   StoreKit sólo conoce las compras de ESE Apple ID. `EntitlementService` existía hace meses,
   funcionaba, y lo usaba únicamente el paywall para mostrar información. Ahora son tres vías.
2. **12 enums sin caso desconocido.** Un valor nuevo del servidor tiraba la respuesta ENTERA.
   `TxType` y `SubscriptionStore` quedan estrictos a propósito.
3. **Las fechas de vencimiento se mostraban un día antes.** El decoder parseaba las columnas
   `date` en UTC; en huso negativo eso retrocede un día y **un vencimiento de hoy salía como
   vencido**. Afecta también metas y deudas, porque el decoder es compartido.

**Cuenta de App Review**: tenía Vencimientos, Cuotas y Deudas **vacíos** — el reviewer veía tres
pantallas en blanco. Se poblaron con datos coherentes (5 vencimientos, 2 planes de cuotas, 1
deuda). De ahí salió el bug de fechas.

**Screenshots es-MX: 6 de 6 completos** con la identidad nueva.

**176 tests iOS, 151 web.**

---

## Sesión 2026-08-04 (tarde) — la app cargada con datos reales

Se cargó el agosto real del hogar de Ariel (40 movimientos, 5 vencimientos, presupuesto con 11
sobres) y **usarla con datos de verdad destapó dos bugs que con la base vacía no existían**:

- **Los movimientos se agrupaban bajo el día anterior.** `dateLabel` hacía `new Date("2026-08-04")`:
  un string de sólo-fecha se interpreta como medianoche **UTC** y al formatearlo en huso negativo
  —toda LatAm— retrocede un día. Un movimiento cargado hoy salía como "Ayer". Ahora se parsea a
  medianoche local. **Quedan tres sospechas del mismo patrón sin verificar**: `debt-card.tsx:199`
  y `goal-card.tsx:100` (`new Date(<columna date>)`), y `bills-view.tsx:54`, que calcula "hoy" con
  `toISOString()` — después de las 21 h en Argentina eso ya devuelve el día siguiente.
- **El filtro de categorías repetía "Otros"** (está en gastos y en ingresos) con warning de claves
  duplicadas en React.

Verificado en el navegador con la sesión real: selección múltiple, barra de lote, buscador,
presupuesto y dashboard.

**Las tres sospechas de fecha se confirmaron y están arregladas** (deudas, metas y el "hoy" de
vencimientos, que se tomaba en UTC y de noche adelantaba un día). Ahora hay un solo helper,
`parseDayLocal` / `todayLocal` en `lib/i18n/dates`, con 8 tests.

### Pendientes que salieron de esta sesión

- **Falta el tipo de cuenta "Billetera virtual"**, que en LatAm es la cuenta principal de mucha
  gente (Mercado Pago, Ualá, Naranja X). **No se agregó a propósito**: `AccountType` en iOS era un
  enum sin caso desconocido, así que crear el tipo desde la web le habría dejado la app publicada
  sin NINGUNA cuenta. Ya está el fallback (`UnknownTolerantDecodable`), pero recién se puede agregar
  el tipo cuando la base instalada tenga esa versión — o sea, después de publicar la 1.1.0 y esperar.
- **Quedan 14 enums `String, Codable` sin caso desconocido** en `metacasa-ios/MetaCasa/Models/`
  (`GoalStatus`, `DebtStatus`, `BillStatus`, `Frequency`, `RolloverMode`, `SubscriptionStatus`…).
  Cada uno es la misma bomba: un valor nuevo del lado servidor y la respuesta entera se pierde.
  Conformarlos a `UnknownTolerantDecodable` es una línea cada uno; se dejó para después del submit.
  `TxType` es el caso donde **no** corresponde fallback: no hay a dónde caer sin falsear los totales.
- **Marzo 2027, mudanza a España**: el hogar pasa a operar en EUR. **No hay que cambiarle la moneda
  al hogar actual** — `transactions.amount` está en la moneda base, así que el histórico argentino se
  reinterpretaría como euros. El camino es un hogar nuevo en EUR (la app ya soporta varios). Antes
  conviene verificar que el patrimonio neto no sume hogares de monedas distintas y que el
  entitlement sea por usuario y no por hogar.

---

## Sesión 2026-08-04 (mañana) — screenshots de tienda y dos bugs que salieron de ahí

Se retomó la regeneración de los screenshots para poder subir la **1.1.0**. Intentar usar la app en
el simulador destapó dos problemas reales de producto:

- **El trial pedía login de Apple en cada arranque.** `TrialManager.trialStartDate()` llamaba a
  `AppTransaction.shared` —que es **interactivo**— en todos los arranques. Sin sesión de App Store
  iniciada, StoreKit abre "Iniciar sesión en cuenta de Apple"; al cancelarlo volvía a aparecer, en
  loop, con la app trabada en el splash detrás. No es del simulador: le pasa a cualquiera con la
  sesión caída, y un pedido de credenciales de Apple sin contexto en una app de finanzas es lo que
  entrena al usuario a caer en phishing. Ahora el ancla se resuelve **una vez** y queda en Keychain.
  8 tests: con ancla resuelve en 0,005 s; sin ancla tarda los 4 s del timeout de StoreKit.
  El comentario de `AccessController` que decía "el trial se calcula LOCAL, sin red" **era falso**
  hasta este arreglo.
- **El Pareto 80/20 se pintaba con la paleta de Swift Charts** (azul, verde, naranja, magenta, rojo):
  el look "fintech saturado" del que el design system se declara contrapunto, justo en una pantalla
  que se usa para vender la app. Ahora hay **una sola** paleta de gráficos (`Color.chartCategories`,
  8 tonos Midnight Sage) y la usan tanto Reportes como el donut del Home — que tenía su propia lista
  con dos colores repetidos.

**Screenshots**: el set publicado (18 imágenes) no estaba viejo sólo en 4 pantallas — está armado
con el **logo anterior** (verde neón 3D) en las 18. Ahora se componen por script
(`scripts/screenshots/compose.py`, ver su README) desde el ícono y los colores vigentes.
**es-MX: 5 de 6 listas** en `store/ready/es-MX/`.

**Lo que quedó trabado y por qué:**
- `05-debts` — Vencimientos, Cuotas y Deudas están **vacíos** en la cuenta que se usa para capturar.
- `en-US` y `pt-BR` — el hogar demo se llama "Mi Hogar", las categorías son "Vivienda"/"Alimentación"
  y la moneda es ARS. Con la app en inglés eso se ve mitad traducido y en pesos. Hace falta un hogar
  demo por mercado (USD / BRL), como ya pedía `APP_STORE_COPY.md` § 6.

---

## Sesión 2026-08-03/04 — qué cambió

**Dinero (los tres clientes ahora derivan del servidor):**
- `amount` va SIEMPRE en la moneda base. El import CSV y los recibos guardaban el monto crudo
  etiquetado con la moneda extranjera: un resumen en dólares entraba dividido por la cotización.
  Un solo constructor (`NewTransactionInput.converting`) en iOS y Flutter, que TIRA sin cotización.
- Totales agregados en el servidor (`transaction_totals`). Antes se bajaban 1000 filas y se sumaba
  en el cliente, descartando en silencio las más viejas.
- "Listo para asignar" tenía CINCO definiciones. Ahora todas leen `budget_period_summary`.
- Transferencias excluidas de los agregados en los tres clientes (18 sitios en Flutter, 9 en web).
  Los saldos por cuenta NO filtran: ahí las dos piernas son el mecanismo.

**Infra:**
- Netlify deployea desde el repo (antes era manual; el sitio sirvió código viejo 2 días sin que
  nadie se enterara). `publish` se resuelve distinto por CLI que por CI — ver netlify.toml.
- Migraciones: repo y ledger idénticos, 51 = 51. `scripts/check-migration-drift.sh` lo vigila.
- Linter de Supabase: 0 errores. Se cerraron dos agujeros introducidos ese mismo día.

**i18n:** catálogo al 100% (985 claves). 16 claves mostraban el identificador CRUDO en los tres
idiomas por un desfase `%lld` vs `%@`.

---

## ✅ MIGRACIÓN CERRADA (2026-08-01)

`https://usehomefinance.com` está **EN LÍNEA**. La migración de Vercel a Netlify terminó completa:

- DNS en Netlify (zona `6a6e0d97c08a56003cef888e`), nameservers `dns1..4.p08.nsone.net`
- Certificado SSL emitido. Verificado por HTTPS: `/`, `/login`, `/privacy`, `/~offline`, `/register`
  devuelven 200; `/dashboard` sin sesión hace 307 a `/login`; `www` hace 301 al apex
- **El email de Brevo nunca se cortó**: los 4 registros (DKIM x2, DMARC, TXT) se espejaron ANTES de
  mover los nameservers, así que durante la propagación ambas zonas decían lo mismo
- `web-handoff` desplegado apuntando al dominio propio → el handoff desde la app vuelve a abrir la web
  YA CON SESIÓN, en vez de mandar a la PWA vieja a loguearse a mano
- Supabase Auth ya estaba correcto: Site URL `https://usehomefinance.com` y allowlist con
  `https://usehomefinance.com/**`
- Sin pagarle nada a Vercel y sin crear cuentas nuevas

**Pendiente menor:** `ai-proxy` en prod no tiene `home-finance-web.netlify.app` en su allowlist de CORS
(sí tiene el dominio propio, que es el que importa). Sólo haría falta si se usa el subdominio temporal.

⚠️ **Para junio 2027:** el dominio **sigue registrado en Vercel** y auto-renueva el 1-jun-2027 a
US$ 11,25. Si esa cuenta sigue suspendida, la renovación puede fallar. Conviene transferirlo a otro
registrador en algún momento tranquilo.

**Lo que sigue en el producto:** 9 hallazgos de auditoría en `AUDITORIA-2026-08-01.md`, ordenados por
gravedad. Los grandes: rollover de sobres que nunca se calcula, transferencias que inflan los KPIs, y el
preview del import que debería preguntar cuenta y moneda.

---

## En una línea

App de finanzas del hogar para LATAM. iOS publicada y funcionando; la web **en línea** en
`usehomefinance.com` (Netlify, migrada el 1-ago-2026); el plan de nivel pro (`app/PLAN_NIVEL_PRO.md`)
tiene las Fases 1-4 casi completas y lo que queda está mayormente bloqueado por credenciales de Ariel,
no por código.

## Qué está vivo y qué no

| Frente | Estado | Dónde |
|---|---|---|
| iOS | **Publicada** en App Store `1.0.3` (4-jun-2026). Local va `1.0.3` build `12` con cambios sin publicar. | `app/metacasa-ios` |
| Android | `.aab` generados, sin publicar. | `app/metacasa-flutter`, binarios en `builds/` |
| Web | Next.js 15 en Netlify. **En línea** en `usehomefinance.com`, SSL emitido. | `app/metacasa-web` |
| Web (legacy) | PWA en Vite. **Se retira.** No invertir UI acá. Sus wallets LatAm ya fueron portadas. | `app/src` |
| Backend | Supabase `rgslvrxdppphzvqgcwbx`, **ACTIVE_HEALTHY**, org en plan **pro**. | `app/supabase` |

## Bloqueos abiertos (necesitan a Ariel, no a una IA)

1. **App Group `group.com.metacasa.shared`** sin crear en el Developer Portal → los widgets compilan e
   instalan pero muestran estado vacío.
2. **Redirect URI de Mercado Pago** sin registrar (app `2693470312497962`) → las wallets no se pueden
   conectar. Falta `https://usehomefinance.com/wallets/callback` + `http://localhost:3000/wallets/callback`.
3. **Sign in with Apple** (4.6), **push APNs** (4.10) y **CI** (4.9) — esperan credenciales / repo en GitHub.
4. **Subir la 1.1.0 a App Store Connect** — el binario y los screenshots están listos, falta el Apple ID.
5. **Datos demo de vencimientos, cuotas y deudas** — están vacíos en la cuenta que se usa para capturar,
   así que la pantalla 5 del set de tienda (`05-debts`) no se puede sacar hasta poblarlos.

⚠️ **Para junio 2027:** el dominio **sigue registrado en Vercel** y auto-renueva el 1-jun-2027 a
US$ 11,25. Si esa cuenta sigue suspendida, la renovación puede fallar. Conviene transferirlo a otro
registrador en algún momento tranquilo.

## Reglas de este proyecto que ya costaron caro

- La app publicada lee la URL que devuelve la **edge function**, no la del `Info.plist`. Se puede cambiar el
  destino web sin release de iOS.
- **Drift de migraciones**: una migración en el repo ≠ aplicada en prod. Comparar el ledger vivo contra
  `app/supabase/migrations/` antes de razonar sobre el backend. Todo cambio por CLI, nada por dashboard.
- `parseMoney` ya tuvo un bug que convertía 1.234.567 en 1,23. Cualquier toque a dinero va con tests.
- No dejar features a medio cablear. Si el código de una vista existe pero no hay target/entitlement/call
  site, **no está hecho**.

## Dónde seguir

`app/PLAN_NIVEL_PRO.md` es la hoja de ruta. Lo que queda sin bloqueo externo:

- Patrones de mercado ❌ del plan: anillos de presupuesto con semáforo + proyección, metas como cajitas con
  gesto de fondeo, grilla de acciones rápidas, onboarding de confianza gradual, feed con logos de comercio.
- Fase 4.11: iPad con `NavigationSplitView`, Tab API iOS 18+, `.tabViewBottomAccessory` iOS 26.
- Enganchar los tests pgTAP a CI (cuando haya CI).

## Bitácora

- **2026-08-01 (tarde)** — **DNS migrado de Vercel a Netlify.** Vercel bloqueaba la escritura de DNS por
  la cuenta suspendida, así que se cambiaron los nameservers. Los 4 registros de email de Brevo se
  espejaron ANTES del cambio: el correo nunca se cortó. Apex y www resuelven a Netlify, HTTP 200.
  Falta sólo el certificado SSL, trabado del lado de Netlify. Sin pagar Vercel ni crear cuentas nuevas.
- **2026-08-01** — Auditoría de tres frentes (producto, seguridad, App Store) + arreglos. **16 de 27
  hallazgos cerrados**, cada uno verificado a mano antes de tocar y contra producción después.
  Cerrados en prod: bypass del app lock, auto-inscripción en hogares ajenos, `wallet-proxy` que
  filtraba el `MP_CLIENT_SECRET`, CORS que rompía borrar-cuenta desde la web, sobres que ignoraban
  subcategorías. Bugs de dinero: patrimonio neto multi-moneda, fecha que corría el mes, cuotas sin
  residuo, paywall que podía cobrar sin desbloquear, y el selector de cuenta (51 de 61 transacciones
  no tenían cuenta). **Tests: 31 → 85.** Detalle en `AUDITORIA-2026-08-01.md`.

- **2026-07-31 (tarde)** — Web **en línea** en `home-finance-web.netlify.app` (verificado: 5 rutas en 200,
  cero errores de consola, claro y oscuro sin fallos de contraste AA, `/dashboard` redirige 307 a `/login`).
  iOS: anillos de presupuesto con proyección de ritmo, metas con fondeo de un toque, Tab API iOS 18.
  **54/54 tests.** Healthcheck ajustado para vigilar el sitio de Netlify y no notificar por el DNS pendiente.

- **2026-07-31** — Consolidación: todo el producto pasó de 7 carpetas desparramadas en `~/Desktop/Proyectos`
  (más `~/metacasa-supabase` y un `.aab` suelto en el Escritorio) a `~/dev/HomeFinance/`, **fuera de iCloud**.
  Se borraron 56.725 archivos de worktrees muertos de Claude y las 5 copias `MetaCasa N.xcodeproj`.
  Ver `../README.md` y `../archive/README.md`.
- **2026-07-28** — Fase 4 al 8/11. Light mode "Daylight Sage", PWA offline, wallets LatAm portadas, FX
  automático con dólar blue, pgTAP 14/14 contra prod.
- **2026-07-27** — Se generó `PLAN_NIVEL_PRO.md` a partir de 4 auditorías en paralelo.
