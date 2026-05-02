# PROJECT_CONTEXT.md — manual vivo de MetaCasa / Home Finance

> **Regla de oro**: cualquier IA o developer que vaya a modificar este proyecto DEBE leer este archivo antes de tocar código, y actualizarlo al terminar un cambio estructural. No es documentación; es el estado real del sistema.

Última actualización: **2026-04-20** — fin de Fase A (i18n + formatters).

---

## 1. Producto

**Identidad**: "Home Finance" — app de finanzas personales / del hogar, multi-usuario, multi-moneda.

**Mercado**:
- **Core**: US + global (inglés).
- **Diferencial**: LatAm (es-AR con inflación/FX, es-ES para España, pt-BR para Brasil).

**Posicionamiento**: competidor directo de Monarch Money, YNAB (zero-based budgeting), Copilot Money (UI), Mobills (LatAm). Privacy-first (IA on-device cuando sea posible), multi-usuario por hogar real, soporte LatAm de primer nivel.

**Monetización**: RevenueCat — Free tier + Premium (mensual/anual). Trials 7 días. A/B testing de precios por región.

---

## 2. Stack real

| Capa | Tecnología | Estado |
|------|------------|--------|
| **iOS nativo** | Swift 6 (strict concurrency) + SwiftUI + SwiftData (cache futura) | Fase 3 en curso (MVP funcional) |
| **Android** | Kotlin + Jetpack Compose + Room + supabase-kt | Pendiente Fase 4 |
| **PWA legacy** | React 18 + Vite 7 + Tailwind v4 + Firebase Hosting | Hecha, refactor en paralelo Fase 2 |
| **Backend** | Supabase (Postgres 17.6) — proyecto `METACASA` id `rgslvrxdppphzvqgcwbx`, us-east-1 | Productivo |
| **Auth** | Supabase Auth (email + OAuth) con workaround JWT explícito | Productivo |
| **Monetización** | RevenueCat SDK iOS + Android | Integrado, sin productos reales aún |
| **AI** | Apple Intelligence FoundationModels (iOS 26+) con fallback heurístico | Pendiente Fase D |

---

## 3. Estructura del repo

```
metacasa-app/
├── CLAUDE.md                     # Convenciones + reglas para agentes
├── PROJECT_CONTEXT.md            # ESTE archivo
├── UI_NOTES.md                   # Design system (tokens)
├── src/                          # PWA monolito (16k líneas, refactor Fase 2)
├── supabase/migrations/          # SQL versionado
├── metacasa-ios/
│   ├── project.yml               # XcodeGen spec
│   ├── MetaCasa.xcodeproj/       # Generado — NO editar a mano
│   └── MetaCasa/
│       ├── App/                  # MetaCasaApp, RootView, AppState
│       ├── Core/                 # Services, Formatters, Config
│       ├── Features/             # Vistas por dominio
│       ├── Models/               # Structs Codable
│       ├── Resources/            # Localizable.xcstrings
│       └── Supporting/           # Info.plist, Assets, entitlements
└── [android/ pendiente]
```

---

## 4. Arquitectura iOS

### 4.1 Auth + JWT

**Bug crítico resuelto (2026-04-20)**: `supabase-swift v2` no propaga consistentemente la session al PostgREST client → requests caían como rol `anon` → RLS rechazaba todo.

**Solución en producción**:
- `AuthManager` guarda `accessToken` + `refreshToken` en memoria (en `AuthSession` struct).
- `TokenHolder` (actor) es el single source of truth del JWT vigente.
- `AppState` escribe en `TokenHolder` en signIn / restore / signOut.
- `SupabaseRPC` (cliente HTTP custom con URLSession) lee el token de `TokenHolder` e inyecta `Authorization: Bearer <token>` en cada request.
- Todos los services usan `SupabaseRPC` (nadie usa `client.from(...).execute()` directo).

### 4.2 Data layer — los 9 services

Todos son `actor`s con singleton `.shared`. Todos usan `SupabaseRPC` (REST o RPC helpers) y leen el JWT del `TokenHolder`:

| Service | Responsabilidad |
|---------|-----------------|
| `HouseholdService` | CRUD households, invitaciones, miembros. `create` vía RPC server-side `create_household` (SECURITY DEFINER, evita recursión RLS). |
| `TransactionService` | CRUD transactions. `insert` genera `period_year/month` server-side. |
| `BudgetService` | Periods + allocations + `envelope_balance` RPC para saldo de envelope. |
| `AccountService` | CRUD accounts (checking, savings, cash, credit_card, etc). |
| `CreditCardService` | Detalle de TC (statement, due day, min pay %, interés mensual). |
| `GoalService` | Goals + contributions (trigger de auto-completion al llegar a target). |
| `RecurringService` | CRUD recurring_transactions. |
| `CategoryService` | Blob JSONB por hogar (custom categories por encima de defaults). |
| `EntitlementService` | Cache local escrito por webhook de RevenueCat. |

### 4.3 Estado global

`AppState` (`@Observable`, `@MainActor`):
- `session: AuthSession?` — user actual
- `currentHouseholdId: UUID?` + `households: [Household]`
- `isBootstrapping`, `isBiometricLocked`, `lastError`

`AppLocaleManager` (`@Observable`, `@MainActor`):
- `current: SupportedLocale` con persistencia en UserDefaults
- Hacia `SupabaseRPC` se expone `AppLocaleStorage.effectiveLocale` (nonisolated, thread-safe).
- Se inyecta al root via `.environment(\.locale, manager.effectiveLocale)` — propaga a Text, FormatStyle, DatePicker.

### 4.4 Formatters (i18n)

Regla: **NUNCA usar `NumberFormatter` a mano en una View**. Siempre `Money.format(...)` o `Money.parse(...)`.

- `Money` → API principal (`.compact` / `.precise` / `.auto`). Lee locale del `AppLocaleStorage`.
- `CurrencyFormatter` → façade legacy que delega en `Money`. Mantenido por compatibilidad; no usar en código nuevo.
- `MoneyText` → View reactiva a `@Environment(\.locale)` — úsala cuando no necesitás color semántico (referencias, allocated, target).
- `AmountLabel` → View con 4 kinds semánticos para contextos con color:

### 4.5 Convención de signos y colores — REGLA ESTRICTA

**Todos los montos en UI deben pasar por `AmountLabel` o `MoneyText`. NO usar `Text(CurrencyFormatter.format(...))`.**

`AmountLabel.Kind`:

| Kind | Signo | Color | Caso de uso |
|------|-------|-------|-------------|
| `.gasto` | siempre `-` | siempre rojo (`brandDanger`) | transacciones tipo gasto, total gastos del mes, deuda TC, pago mínimo, interés |
| `.ingreso` | sin signo | siempre verde (`brandSuccess`) | transacciones tipo ingreso, total ingresos del mes, contribuciones a goals |
| `.balance` | signo natural (`-` si negativo) | rojo si <0, verde si >0, neutro si =0 | saldo del mes (ingresos-gastos), disponible para asignar, remaining de envelope, saldo de cuenta (por si hay deuda) |
| `.neutro` | sin signo | color default | referencias (allocated, target), límites de crédito, caption de comparación `X/Y` |

**Convenciones importantes**:
- La DB guarda gastos como **valor absoluto** (positivo). `.gasto` negates internamente antes de formatear — no mandes negativos.
- Para ingresos, **NO mostramos `+`** (apps premium como Monarch/Copilot no lo usan, queda más limpio).
- `.balance` es el único kind que elige color dinámicamente.
- Envelope `spent / allocated` son referencias comparativas → `MoneyText` neutro.

**Ejemplo concreto** (home dashboard):
```swift
// Saldo del mes (puede ser +/-)
AmountLabel(amount: viewModel.balance, currency: hogar.defaultCurrency, kind: .balance)

// Tile GASTOS del mes
AmountLabel(amount: viewModel.totalGastos, currency: hogar.defaultCurrency, kind: .gasto)

// Tile INGRESOS del mes
AmountLabel(amount: viewModel.totalIngresos, currency: hogar.defaultCurrency, kind: .ingreso)
```

### 4.5 i18n (String Catalog)

- Archivo: `MetaCasa/Resources/Localizable.xcstrings`.
- Idiomas: `es` (base), `es-AR`, `es-ES`, `en`, `pt-BR`.
- Development language: `es`.
- Uso en Views: `Text("key.path")` — SwiftUI resuelve automáticamente.
- Uso fuera de Views: `String(localized: "key.path")`.
- Cambio de idioma en runtime: `LanguageSettingsView` setea `AppLocaleManager.shared.current`.
- Xcode auto-extrae strings nuevos al buildar — el catalog se actualiza solo si se abre en Xcode.

---

## 5. Base de datos (Supabase)

**Proyecto**: `METACASA` (`rgslvrxdppphzvqgcwbx`, us-east-1).

**Tablas principales** (todas con RLS obligatorio):
- `households`, `household_members`, `household_invitations`
- `transactions` (con `period_year`, `period_month` generated)
- `budget_periods`, `budget_allocations`
- `accounts`, `credit_cards`
- `goals`, `goal_contributions`
- `recurring_transactions`
- `categories` (blob JSONB por hogar)
- `user_entitlements` (cache escrito por webhook RevenueCat)

**RLS policies**: patrón `(select auth.uid())` siempre, nunca `auth.uid()` plano (perf).

**Funciones SECURITY DEFINER**:
- `create_household(p_name, p_currency, p_timezone)` — evita issues de RLS al crear hogar + owner member atómicamente.
- `accept_household_invitation(invite_token)` — acepta invite y agrega al caller.
- `envelope_balance(p_period_id, p_category, p_subcategory)` — calcula saldo del envelope.
- `has_active_entitlement(ent)` — checkea entitlement vigente.
- `current_user_household_ids()`, `is_household_member(hid)`, `current_user_household_role(hid)`, `current_user_default_household()` — helpers para RLS policies (SECURITY DEFINER para evitar recursión).

---

## 6. Convenciones críticas

1. **SQL**: `snake_case` para tablas/columnas. Toda tabla `public.*` con RLS.
2. **Migraciones**: cada cambio vía `apply_migration` MCP + archivo versionado `supabase/migrations/YYYYMMDDHHMMSS_nombre.sql`.
3. **Secrets**: `.env` ignored. Nunca service_role en frontend.
4. **Logs**: NUNCA loguear `access_token`, `refresh_token`, emails, balances, PAN/CVV.
5. **Frontend**: Tailwind v4 + tokens en `UI_NOTES.md`. Sin estilos inline.
6. **iOS**: Swift 6 strict concurrency. Actors para services, `@MainActor` para ViewModels.
7. **i18n**: usar String Catalog keys con prefijo de dominio (`auth.`, `tx.`, `budget.`, `more.`, etc). Nunca hardcodear strings en Views.
8. **Money**: siempre via `Money.format(..., currency: hogar.defaultCurrency)`. Nunca asumir locale en código de servicio.
9. **Commits**: conventional commits recomendado. No pushear a main sin revisión, especialmente migraciones.

---

## 7. Roadmap (estado al 2026-04-20)

| Fase | Descripción | Estado |
|------|-------------|--------|
| **Fase 0** | Auditoría + fixes RLS performance + cifrado tokens + migraciones versionadas | ✅ Completada |
| **Fase 1** | Schema canónico — households, accounts, envelope budgets, goals, entitlements, multi-moneda | ✅ Completada |
| **Fase 2** | Refactor del monolito `src/App.jsx` en componentes/hooks/services | 🟡 En paralelo |
| **Fase 3.1** | iOS MVP: login/signup, CRUD básico, household | ✅ Completada |
| **Fase 3.2** | Features acumuladas: accounts, credit cards, goals, members, invites, categories | ✅ Completada |
| **Fase 3.3** | Refactor completo a `SupabaseRPC + TokenHolder` (fix del bug RLS) | ✅ Completada 2026-04-20 |
| **Fase A** | i18n (String Catalog es-AR/es-ES/en-US/pt-BR) + Money formatter + PROJECT_CONTEXT.md | ✅ Completada 2026-04-20 |
| **Fase B** | Export CSV (23 cols) + PDF con breakdown + Share Sheet + 7 rangos + locale-aware | ✅ Completada 2026-04-20 |
| **Fase C (parcial)** | Import CSV con auto-detección de columnas, preview, mapping editable, dedupe por (fecha+monto+cat+nota) | ✅ Completada 2026-04-20. Excel (CoreXLSX) pendiente. |
| **Port Web → iOS #1** | Movimientos full-featured: filtros completos + chips activos + sort menu + vista lista/calendar heatmap + day detail sheet | ✅ Completada 2026-04-20 |
| **Port Web → iOS #2** | Presupuesto waterfall multi-persona (ingresos → deducciones → remanente → distribución equal/proportional/custom) + StrategySettingsSheet | ✅ Completada 2026-04-20 |
| **Port Web → iOS #3** | Vencimientos + Cuotas + Deudas — 3 módulos completos (list + form + detail) con urgencia color-coded, ledger de cuotas, cálculo de interés + payoff projection | ✅ Completada 2026-04-20 |
| **Port Web → iOS #4** | Home dashboard enriquecido con upcoming bills card + debts/plans count cards (subset de los 60 widgets web) | ✅ Completada 2026-04-20 |
| **Port Web → iOS #5** | Reports: Health Score 0-100 + Swift Charts nativos (6-month bars + Pareto donut) + category drill-down con barras proporcionales | ✅ Completada 2026-04-20 |
| **Port Web → iOS #6** | Privacy mode + FX rates manager + Quick shortcuts (templates) + Subcategorías anidadas en AddTransaction | ✅ Completada 2026-04-20 |
| **Port Web → iOS #7** | Voice entry + Mercado Pago OAuth — difefridos (requieren dispositivo real / credenciales vivas) | 📋 Parking lot documentado |
| **Fase C** | Import CSV + Excel (CoreXLSX SPM) con mapeo columnas + preview + dedupe | 🔜 |
| **Fase D** | AI Assistant global (FAB + FoundationModels + fallback heurístico + context-aware) | 🔜 |
| **Fase E** | Auditoría QA completa + polish iPad (NavigationSplitView) | 🔜 |
| **Fase 3.4** | Features premium iOS: Widget, Live Activities, Shortcuts, SwiftData offline | Pendiente |
| **Fase 3.5** | RevenueCat real (productos en App Store Connect + paywall + webhook) | Pendiente |
| **Fase 3.6** | TestFlight + App Store submission (Fastlane + CI + screenshots + nutrition label) | Pendiente |
| **Fase 4** | Android nativo (Kotlin + Compose + Room + supabase-kt) | Post-launch iOS |

---

## 8. Decisiones de arquitectura registradas

### ADR-001: custom SupabaseRPC en vez de supabase-swift directo
**Fecha**: 2026-04-20.
**Contexto**: supabase-swift v2 no propaga JWT al PostgREST client después de signIn → RLS rechaza todo.
**Decisión**: implementar cliente mínimo propio (`SupabaseRPC`) basado en `URLSession` que inyecta JWT explícito. Solo `AuthManager` y `SupabaseService` siguen usando supabase-swift.
**Consecuencia**: control total sobre el flujo HTTP. Si supabase-swift arregla el bug en un release futuro, podemos volver gradualmente. `AuthManager` sigue siendo responsable de signIn/signUp/refresh.

### ADR-002: String Catalog (.xcstrings) en vez de JSON custom
**Fecha**: 2026-04-20.
**Contexto**: el brief pedía "archivos de traducción centralizados (JSON)".
**Decisión**: usar `Localizable.xcstrings` (Xcode 15+). JSON custom pierde el toolchain nativo (auto-extract, XLIFF export, Xcode editor, pluralización).
**Consecuencia**: si algún día queremos sync con web, exportamos XLIFF o escribimos un script que transforme .xcstrings → JSON para la PWA.

### ADR-003: TokenHolder actor global vs parameter threading
**Fecha**: 2026-04-20.
**Contexto**: hace falta el JWT en cada request HTTP. Pasarlo por parámetro a cada service obliga a modificar todas las call sites.
**Decisión**: actor global `TokenHolder` que guarda el token vigente; services lo leen implícitamente.
**Consecuencia**: API de services queda limpia. El único actor que sabe del JWT es el que ejecuta HTTP.

### ADR-004: i18n override vs follow-system
**Fecha**: 2026-04-20.
**Contexto**: en países con inflación/FX, los usuarios pueden querer forzar un idioma distinto al del sistema (ej. español en un iPhone en inglés para laburar con contador argentino).
**Decisión**: override explícito vía `AppLocaleManager`, default `.system`. Persistido en UserDefaults.
**Consecuencia**: el cambio aplica al instante en toda la UI sin restart porque propagamos `.environment(\.locale, ...)` al root.

### ADR-008: modelo waterfall multi-persona como diferencial
**Fecha**: 2026-04-20.
**Contexto**: el presupuesto "zero-based" tradicional (YNAB, Goodbudget) no maneja hogares multi-persona con cuentas personales + compartidas. El web implementó un modelo waterfall: ingresos hogar → deducciones (fijos, bills, cuotas, deudas, compartidos, %ahorro, %inversión) → remanente distribuido a cuentas personales (equal/proportional/custom).
**Decisión**: portar el modelo idéntico a iOS con `WaterfallCalculator` (motor puro) + `WaterfallViewModel` (async loading) + `WaterfallBudgetView` (UI con cards + chevrons de mes + StrategySettingsSheet). Se agregan 4 tablas nuevas a Supabase (bills, installment_plans, installment_payments, debts) + columna `strategy` jsonb en households + columna `ownership` en accounts.
**Consecuencia**: diferencial real vs Monarch/YNAB/Copilot. Requiere que el usuario mantenga sus bills/cuotas/deudas al día para que el waterfall calcule bien. Trade-off aceptado.

### ADR-007: portar features desde MetaCasa web como source of truth
**Fecha**: 2026-04-20.
**Contexto**: tras construir varias features iOS desde cero, detectamos que la PWA web ya tenía implementación completa de cada una con UX probada por el usuario. El prototipo iOS era más simple y menos completo.
**Decisión**: la PWA (`src/App.jsx` 16.331 líneas) es el **source of truth funcional** para lógica y UX. iOS porta feature por feature, manteniendo nomenclatura y flujos. Las mejoras iOS-native son visuales/performance: SF Symbols, DisclosureGroup, segmented pickers, `.presentationDetents`, haptics, Swift Charts, swipe actions, material backgrounds — no reinventar la funcionalidad.
**Consecuencia**: evita semanas de re-diseño. Cada pantalla iOS se evalúa contra la paridad del web. Agent explore-subagent genera el catálogo de features web antes de cada port. Documentado en PROJECT_CONTEXT.md sección 7 (roadmap).

### ADR-006: exports CSV usan `.` como decimal universal (ignora locale)
**Fecha**: 2026-04-20.
**Contexto**: el primer prototipo del CSV respetaba el locale del usuario (`25.000,50` en es-AR). Excel en es-AR lo abre bien, pero Excel en en-US lo interpreta como string porque esperaba `25000.50`. Peor: si el usuario manda el CSV a su contador con setup distinto, se rompe.
**Decisión**: para el CSV, forzamos `Locale("en_US_POSIX")` en el formatter de amounts → siempre `.` decimal, sin miles. Se escriben con escape RFC 4180 + UTF-8 BOM. El PDF sí respeta el locale del usuario (es un reporte final, no data intercambiable).
**Consecuencia**: interoperabilidad máxima. El CSV puede abrirse en Excel/Sheets/Numbers en cualquier país sin ambigüedad.

### ADR-005: convención de signos — gastos siempre con `-`, ingresos sin `+`
**Fecha**: 2026-04-20.
**Contexto**: originalmente los gastos se mostraban sin signo con color rojo (`$25.000` rojo). El usuario pidió el signo menos explícito en todos los gastos para eliminar ambigüedad ("¿es gasto o ingreso?") sin depender solo del color.
**Decisión**: `AmountLabel.Kind` define 4 semánticas (`.gasto`, `.ingreso`, `.balance`, `.neutro`). Gastos siempre con `-` rojo. Ingresos sin `+` verdes (decisión UX alineada con Monarch/Copilot — limpio, el color ya comunica). `.balance` aplica signo + color según valor. `.neutro` es para referencias (allocated, target).
**Consecuencia**: toda la presentación numérica queda consistente. La DB sigue guardando valores absolutos (positivos) — el kind decide cómo renderizar. La refactorización tocó 6 views (Home, BudgetView, AccountsView, CreditCardDetailView, GoalsView, GoalDetailView, TransactionRow).

---

## 9. Cómo buildear

Desde `metacasa-ios/`:

```bash
# Regenerar xcodeproj (necesario al agregar archivos nuevos)
xcodegen generate

# Build + install + launch en simulator
rm -rf build
xcodebuild -project MetaCasa.xcodeproj -scheme MetaCasa \
  -destination 'platform=iOS Simulator,id=FA061303-C6DE-4738-9A8C-8BEB1E656625' \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build

ditto --norsrc --noextattr --noacl \
  "build/Build/Products/Debug-iphonesimulator/Home Finance.app" \
  /tmp/HomeFinance-clean.app

codesign --force --deep --sign - \
  --entitlements MetaCasa/Supporting/MetaCasa.entitlements \
  /tmp/HomeFinance-clean.app

xcrun simctl uninstall FA061303-C6DE-4738-9A8C-8BEB1E656625 com.metacasa.app
xcrun simctl install FA061303-C6DE-4738-9A8C-8BEB1E656625 /tmp/HomeFinance-clean.app
xcrun simctl launch FA061303-C6DE-4738-9A8C-8BEB1E656625 com.metacasa.app
```

**Razón del workaround**: macOS 26 agrega `com.apple.provenance` xattr a todos los archivos creados en Desktop/iCloud → codesign rechaza el bundle. El flow es: build sin codesign → copiar con `ditto --noextattr` a `/tmp` → codesign manual.

**Usuario de test**: `ctotest2026@gmail.com` / `TestSecure!2026` (email auto-confirmado via SQL admin).

---

## 10. Preguntas frecuentes para IAs futuras

- **¿Dónde agrego un string nuevo?** En `Localizable.xcstrings` via Xcode editor, o manualmente al JSON. Usá prefijo de dominio (`auth.`, `tx.`, etc). Agregá al menos `es`, `en`, `pt-BR`.
- **¿Cómo formateo un monto?** `Money.format(amount, currency: hogar.defaultCurrency, style: .compact)`. No uses `NumberFormatter` directo.
- **¿Cómo creo un endpoint nuevo?** Si es acción → RPC SECURITY DEFINER en Supabase. Si es CRUD → agregar método al service correspondiente usando `SupabaseRPC.{select,insert,update,delete}`.
- **¿Cómo agrego una View nueva?** Poner en `Features/<Dominio>/`. Usar `Text("localization.key")`. Si necesita string interpolado: `Text("saludo \(name)", tableName: nil)`.
- **¿Cómo disparo un side effect al cambiar idioma?** El environment `\.locale` propagado al root ya actualiza todos los `Text` y `formatted()` automáticamente. Si necesitás lógica custom, observá `AppLocaleManager.shared.current`.

---

## 10b. Parking lot — features diferidas (pendientes de próxima sesión)

Estas dos features están **doc-completas** y listas para implementar pero requieren
trabajo que es mejor hacer con el usuario en vivo (permisos del device, credenciales
reales, verificación de UX).

### 10b.1 Voice entry (dictado de voz para crear movimientos)

**Source of truth en web**: `App.jsx:3184-3203, 4000+`. Usa SpeechRecognition de
browser + keyword mapping (`CATEGORY_KEYWORDS: App.jsx:32-42`) para auto-parsear
categoría.

**Plan de implementación iOS**:
1. Permisos: `Info.plist` ya tiene `NSSpeechRecognitionUsageDescription` y
   `NSMicrophoneUsageDescription`.
2. Nuevo archivo `Core/VoiceRecognizer.swift`:
   - `SFSpeechRecognizer` (locale automático desde `AppLocaleManager.effectiveLocale`)
   - `AVAudioEngine` con tap en el audio input
   - `SFSpeechAudioBufferRecognitionRequest` para streaming partial results
   - Publica `transcription: String` + `isRecording: Bool` via `@Observable`
3. `Core/TransactionParser.swift`:
   - Regex para extraer monto (primer número)
   - Keyword map categoría (mantener igual que web: "supermercado" → Alimentación, "uber" → Transporte, etc.)
   - Devuelve `(amount, category, note)` parcial
4. Nueva UI `AddTransactionView.voiceButton`:
   - Mic icon en toolbar. Al presionar inicia grabación, ícono pulsante rojo.
   - Sheet `VoiceCaptureSheet` con waveform animado + transcription en vivo.
   - "Listo" completa el parseo → rellena amount/category/note → dismiss.
5. Strings i18n: `voice.*`.

**Por qué diferirlo**: el simulator no tiene micrófono real y SFSpeechRecognizer
no funciona bien en simulator. Se necesita testing en device real + iteración con
palabras que el usuario realmente usa (spanglish, acentos regionales).

**Estimación**: ~3-4 hs de dev + iteración con usuario.

### 10b.2 Mercado Pago (OAuth + sync)

**Source of truth**: `src/services/wallets.js` + edge function `wallet-proxy` que
ya existe en Supabase (para PWA). Usa `client_id: 2693470312497962` (público).

**Plan de implementación iOS**:
1. Nuevo schema Supabase: tabla `wallet_connections` con `(household_id, provider,
   encrypted_access_token, refresh_token, expires_at)`. Usar `pgcrypto + vault`
   para cifrar como ya hacemos con OAuth tokens.
2. Edge function `wallet-proxy` ya soporta `oauth_exchange` y `oauth_refresh` —
   no hace falta tocar backend.
3. Swift: `Core/WalletService.swift` con:
   - `startOAuth(provider)` → construye URL MP OAuth + abre via `ASWebAuthenticationSession`
   - Callback handler: intercepta redirect con `code` → llama edge function
     `wallet-proxy/oauth_exchange` → guarda tokens
   - `sync(walletId)` → llama `wallet-proxy/{wallet_id}/payments` → parsea JSON
     → crea `Transaction` records en batch
4. UI `Features/Wallets/WalletsView.swift` con list + connect flow.
5. Flag entitlement: solo para Premium (via RevenueCat).

**Por qué diferirlo**:
- Necesito el MP access_token real del usuario para probar — no puedo estubarlo.
- El OAuth flow en simulator puede fallar con certificate pinning a producción.
- La UX del sync (qué hacer con duplicados, categorización automática, manejo de
  devoluciones) merece discusión detallada.

**Estimación**: ~6-8 hs de dev + 2-3 hs de testing con API real.

---

## 11. Contactos / servicios externos

- **Supabase dashboard**: https://rgslvrxdppphzvqgcwbx.supabase.co (id: `rgslvrxdppphzvqgcwbx`)
- **Firebase Hosting PWA**: https://metacasa-app-cf592.web.app/
- **Apple Developer**: Team ID pendiente (no crítico mientras desarrollamos en simulador sin device real)
- **RevenueCat**: account pendiente de crear productos reales
