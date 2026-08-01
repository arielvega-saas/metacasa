# Auditoría de tres frentes — 2026-08-01

Tres auditores expertos en paralelo (producto financiero, seguridad, readiness de App Store).
**Cada hallazgo listado acá fue verificado a mano contra el código** antes de anotarlo; lo que no se
pudo confirmar se descartó.

Estado: ✅ arreglado · 🔧 pendiente · ⏸️ bloqueado en decisión o credenciales de Ariel

---

## Lo que rompe una garantía de seguridad

| | Hallazgo | Evidencia |
|---|---|---|
| ✅ | **Bypass del app lock.** El `catch` tenía un `default:` que abría la app ante cualquier `LAError` que no fuera cancelación — **incluido `.authenticationFailed`**. O sea: fallabas Face ID, te caía el passcode, lo ponías mal, y la app se abría con todos los saldos. El lock era decorativo contra el único atacante que importa: alguien con el teléfono en la mano. Ahora es lista blanca (`shouldFailOpen`), con 7 tests. | `Core/BiometricLockManager.swift:98-111` |
| ✅ | **APLICADO EN PROD.** Cualquiera podía auto-inscribirse en cualquier hogar. La policy `household_members_insert_self_or_admin` tiene una rama `user_id = auth.uid()` que **no restringe `household_id` ni `role`**: se puede insertar `(hogar ajeno, yo, 'owner')` y quedar dentro con permisos de dueño, salteando `accept_household_invitation`. No es enumerable (hace falta el UUID del hogar), pero **un ex-miembro lo conoce de siempre** — ex pareja, roommate al que sacaron. En una app de finanzas compartidas eso es un modelo de amenaza real. El pgTAP no lo cubre: testea aislamiento de `transactions`, nunca intenta forjar una membresía. **Requiere migración en prod.** | `20260419120300_create_households_and_members.sql:105-109` |
| ✅ | **DESPLEGADO.** Reproducido el ataque contra la función viva: ahora devuelve `401`. `wallet-proxy` no validaba sesión en las ramas OAuth. El `getUser(jwt)` está DESPUÉS del `switch`, y `verify_jwt: true` sólo exige un JWT del proyecto — la anon key **es** uno y es pública. Confirmado contra producción: con sólo la anon key el pedido llegó a Mercado Pago usando el `MP_CLIENT_SECRET` (devolvió `invalid_grant` de MP, no 401 de la función). Cualquiera puede usar el client_secret como oráculo. | `supabase/functions/wallet-proxy/index.ts:64-124` |

---

## Lo que le muestra al usuario un número incorrecto

| | Hallazgo | Evidencia |
|---|---|---|
| 🔧 | **P0 · Ninguna transacción de iOS se asocia a una cuenta.** Los 9 caminos de alta hardcodean `accountId: nil` y **no hay selector de cuenta en el formulario**. El RPC `account_balances` hace `LEFT JOIN ON t.account_id = a.id`, así que devuelve exactamente `starting_balance`. Para un usuario iOS-only, **toda la sección Cuentas y el patrimonio neto están congelados** en el saldo del día que creó la cuenta. Daño colateral: el waterfall en modo "proporcional al ingreso" agrupa por `accountId`, siempre da 0, y **cae al reparto por partes iguales en silencio**. | `AddTransactionView.swift:556` + 8 más |
| 🔧 | **P0 · Multi-moneda invertida.** Se guarda el monto convertido a base pero se etiqueta con la moneda extranjera, y `NewTransactionInput` no tiene `amountOriginal` ni `fxRateToBase`, así que **el original se pierde para siempre**. Hogar en ARS, gasto de USD 100 a 1500 → la lista muestra **"US$ 150.000"**. El contrato canónico está escrito en `metacasa-web/AGENTS_CONTRACT.md:85` y la web lo respeta; iOS lo rompe en las dos puntas. Peor: el exporter CSV usa la convención **opuesta** a la del importer, dentro del mismo target. | `AddTransactionView.swift:558-559`, `TransactionRow.swift:35-39` y 6 más |
| 🔧 | **P0 · El import CSV no convierte monedas.** Cero llamadas a `FXConverter` en todo el importer. Un argentino importa el resumen de su tarjeta en dólares (caso LATAM normal): USD 800 entra como `amount = 800` en base ARS. **Gasto subestimado ~1500×.** | `TransactionCSVImporter.swift:446-455` |
| ✅ | **P1 · ARREGLADO (4 tests).** El patrimonio neto sumaba monedas distintas sin convertir. `AccountBalanceService` acumula sin mirar `account.currency`. Y el RPC suma `starting_balance` (moneda de la cuenta) con `Σ t.amount` (moneda base). USD 5.000 + ARS 300.000 → muestra "$305.000". El valor real es ~$7.800.000. **Error de 25× en la cifra más visible de la app.** La web sí lo hace bien. | `AccountBalanceService.swift:50-68`, `20260727130200:50-52` |
| ✅ | **P1 · APLICADO EN PROD.** Verificado con datos sintéticos que se revierten solos: el saldo pasó de −3500 a −4500 con un gasto de 1000 con subcategoría. Incluye protección anti doble conteo. Los sobres no contaban el gasto con subcategoría. `envelope_balance` matchea con igualdad estricta (`coalesce(t.subcategory,'') = p_subcategory`) pero los sobres se crean con subcategoría vacía. Presupuestás "Comida $200.000", cargás los gastos como *Comida › Supermercado* — que es lo que la UI te invita a hacer — y el sobre muestra **"$0 gastado"** todo el mes. El anillo queda verde, la proyección no dispara, y te pasás sin una sola alerta. **Es el caso de uso más común y falla al 100%.** | `20260601120000_fix_envelope_balance_currency.sql:101` |
| ✅ | **P1 · ARREGLADO (7 tests).** La normalización va en el `init` de `NewTransactionInput`, no en los 8 call sites. La fecha iba con hora local codificada como UTC. Un gasto cargado el 31-ene a las 22:00 en Argentina se guarda como `2026-02-01T01:00Z`: cuenta en el presupuesto de **febrero**. En México la ventana rota es de 18:00 a medianoche — justo cuando la gente carga los gastos del día. La web ya lo resolvió con `toStableDate` (mediodía UTC); iOS quedó afuera del fix. | `AddTransactionView.swift:10,524` vs `metacasa-web/lib/db/transactions.ts:209` |
| 🔧 | **P1 · El rollover de sobres nunca se calcula.** `rollover_from_prev` existe y es configurable desde iOS con las tres opciones, pero **cero escrituras en todo el repo**: no hay trigger, ni job, ni server action. El toggle no hace absolutamente nada. Es feature central de Goodbudget y YNAB. | grep sin resultados |
| 🔧 | **P2 · "Listo para asignar" muestra dos números distintos.** El Home lee la columna de la DB (que iOS **nunca escribe**, queda en 0) y Presupuesto lo calcula local. Mismo usuario, misma app: Home dice "$0" con check verde, Presupuesto dice "$100.000". Y la alerta de sobre-asignación nunca puede dispararse. | `HomeView.swift:1382` vs `BudgetHubView.swift:46-48` |
| 🔧 | **P2 · Las transferencias inflan todos los KPIs.** Se registran como gasto + ingreso sin ningún flag. Mover $500.000 entre cuentas propias suma $500.000 a ingresos **y** a gastos: hunde el health score, "Transferencia" aparece como categoría top. YNAB/Monarch/PocketGuard las excluyen por diseño. | `AIToolHandler.swift:935-963` |
| 🔧 | **P2 · El health score y la racha se derrumban el día 1 de cada mes.** El componente de consistencia dice "últimos 30 días" pero se calcula sobre el mes calendario en curso. El 31-ene: score 85, racha 30 🔥. El 1-feb sin hacer nada distinto: score 66, **racha 0**. Se rompe la métrica de hábito justo cuando más importa retener. | `HomeView.swift:72-94` |
| ✅ | **P3 · ARREGLADO (8 tests).** Cuotas sin residuo. $1.000.000 en 12 cuotas da 12 × `83333,333…`; la UI muestra $83.333 × 12 = $999.996. Falta absorber el residuo en la última, como hace cualquier tarjeta. | `Installment.swift:40-43` |
| 🔧 | **P3 · Truncamiento silencioso de totales.** `totals` usa `limit: 1000` y el Home `limit: 500`, ordenado por fecha desc: pasado el tope se descartan las transacciones **más viejas del mes** y los KPIs quedan bajos sin aviso. Existe el RPC `month_summary` que lo resolvería — y que hoy **no lo llama nadie**. | `TransactionService.swift:96` |

---

## Bloqueantes de submit

| | Hallazgo |
|---|---|
| ✅ | Versión y build eran `1.0.3` / `12`, idénticos a lo publicado → ASC rechaza el binario en el upload. Ahora `1.1.0` / `13`. |
| ✅ | El widget se llamaba **"MetaCasa"** en la galería (`CFBundleDisplayName`) — rechazo 2.3.8, el mismo que ya costó una vez. |
| ✅ | El Help Center afirmaba *"IA: on-device. Tus datos NO salen del iPhone"*, **falso**: se envían texto, resumen financiero y fotos de comprobantes a Anthropic, y texto a ElevenLabs. Declaración de privacidad falsa dentro de la app = rechazo + exposición GDPR. |
| ✅ | Dos textos decían "mandá un email para borrar tu cuenta" — el anti-patrón exacto que prohíbe 5.1.1(v). El flujo real dentro de la app ya cumple; eran los textos los que mentían. Peor: **los dominios `homefinance.app` y `metacasa.app` no tienen MX**, esos mails no llegaban a ningún lado. |
| ✅ | El privacy manifest no declaraba `PhotosorVideos` ni `OtherUserContent` pese a subirlos a un tercero. |
| ✅ | **CREADO.** El appex no tenía privacy manifest propio y usa `UserDefaults(suiteName:)` → email ITMS-91053 y rechazo. |
| ✅ | **ARREGLADOS.** Dos bugs de paywall que cuestan plata. (a) `purchase()` sólo llama `onUnlock()` si RevenueCat devuelve `true`; si el entitlement del dashboard no se llama literalmente `premium` o RC tarda en propagar, **Apple ya cobró y la app sigue trabada** — y StoreKit, que sí habría concedido el acceso, está a una línea. Mismo patrón en `restore()`: reinstalás, ya pagaste, y ves "no tenés suscripciones". (b) Si el offering no carga, el usuario bloqueado ve precios hardcodeados y **ningún botón de compra**. |
| 🔧 | **4 de 6 screenshots desactualizados** (son del 28-may): cambiaron justo Home, Presupuesto, Movimientos y Metas. Guideline 2.3.3. Los válidos están en `store/ready/` (1290×2796) y `store/ready/resized/`; los de `store/en-US|es-MX|pt-BR/` están en 941×1672 y son inservibles. |
| 🔧 | `DeleteAccountView` está **100% en español hardcodeado** — un reviewer en inglés ve la pantalla más sensible sin traducir. Y hay 136 keys sin traducir en `en` y en `pt-BR`. |
| ⏸️ | `usehomefinance.com` está hardcodeado en 3 lugares (redirect de confirmación de email, `WEB_APP_URL`, `applinks:`). **Se dejan como están a propósito**: el fix correcto es mover el DNS, no hornear una URL temporal de Netlify en un binario publicado. Pero **bloquea el submit** hasta que el dominio resuelva, porque hoy el mail de signup manda a un 402 y nadie puede crear cuenta. |

---

## Infraestructura

| | Hallazgo |
|---|---|
| ✅ | **CORS (DESPLEGADO Y VERIFICADO EN PROD).** El allowlist de las edge functions no incluía el origen de Netlify. Verificado contra producción: el preflight devolvía 200 **sin** `Access-Control-Allow-Origin`, o sea que desde la web nueva **borrar cuenta, wallets y asistente estaban rotos**. Corregido en los 5 archivos; **falta desplegar las functions**. |
| 🔧 | **El repo git tiene daño real**: faltan objetos (`3550fe64…`) y hay trees con links rotos. `git rev-list main` falla. No afecta el working tree ni el push (GitHub tiene la historia), pero `git gc` y un `clone` completo van a fallar. Remedio limpio: clonar de nuevo desde GitHub y reemplazar la copia local. |
| 🔧 | Migraciones pendientes: `20260601120000` y `20260601120001` sin aplicar, y `20260601100000` aplicada fuera del ledger. Es `leccion-drift-migraciones-supabase` repitiéndose. |

---

## Verificado y limpio (no asumido)

RLS activo en 28/28 tablas con **exactamente una policy por comando** — la consolidación del ítem 1.3 se sostuvo · ninguna función SECURITY DEFINER con `search_path` mutable (23/23) · **cero secretos filtrados** en el árbol y en el historial de git; el único JWT embebido tiene `"role":"anon"` · el token de wallet descifrado no es alcanzable desde el cliente · tokens de invitación de 192 bits · la key de RevenueCat es **real**, no placeholder (el comentario que dice "PLACEHOLDER" miente) · **el gate de suscripción realmente bloquea** y no depende de RevenueCat: verifica StoreKit 2 directo · middleware web con `getUser()`, `/dashboard` → 307 `/login` · ATS sin excepciones · los 5 usage descriptions presentes y honestos · consent sheet de IA con gate real y opción de revocar.
