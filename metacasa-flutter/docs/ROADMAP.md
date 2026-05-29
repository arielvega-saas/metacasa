# Home Finance — Android (Flutter) · Roadmap & progreso

> Objetivo: **paridad 1:1** con la app iOS publicada (ver [IOS_AUDIT.md](IOS_AUDIT.md)), calidad igual o mejor, lista para Google Play. Es un proyecto de varias semanas/meses y múltiples sesiones. Se trabaja por **vertical slices** (cada feature funcional de punta a punta) manteniendo el proyecto **siempre compilando**.

## Stack elegido
Flutter 3.27 · Riverpod · freezed/json_serializable · **`decimal`** (plata) · supabase_flutter · purchases_flutter (RevenueCat) · local_auth · flutter_secure_storage · go_router · google_fonts (Inter+Newsreader) · figma_squircle · lucide_icons · fl_chart · speech_to_text · flutter_tts/ElevenLabs · google_mlkit · flutter_local_notifications · home_widget.

## Arquitectura de carpetas (objetivo)
```
lib/
├── core/        theme/ ✓ · network/ · utils/ · constants/ · haptics/
├── config/      env, supabase init, router
├── models/      freezed (Transaction, Account, Budget, Household, ...)
├── data/        repositories/ (uno por entidad, sobre PostgREST) · edge/ (ai-proxy, tts-proxy, delete-account)
├── state/       providers Riverpod (appState, auth, household activo, prefs)
├── features/    home/ transactions/ budget/ accounts/ bills/ goals/ ... (cada una: presentation + controller)
└── shared/      widgets reutilizables (MCCard, AmountText, MCButton, MCChip, ...)
```

## Fases

- [~] **Fase 0 — Auditoría** *(hecha)*: deep-audit del iOS real (5 dominios). Ver IOS_AUDIT.md.
- [~] **Fase 1 — Base técnica** *(Ola 1 cerrada y verificada; falta Ola 2)*
  - [x] Scaffold proyecto + deps
  - [x] Design system Midnight Sage (`core/theme/`) — analyze limpio + test verde
  - [x] Config: Supabase init (`--dart-define`, `env.json` gitignoreado) + localización es/en/pt
  - [x] **Modelos freezed + enums + `Decimal`** — los 18 modelos **verificados 1:1 contra la DB viva** (no solo el Swift). `Bill` reescrito porque el Swift estaba stale vs la tabla real.
  - [x] Navegación: 5 tabs + FAB asistente (go_router StatefulShell) + RootGate
  - [x] Shared widgets base (MCCard, AmountText, MCButton, MCChip, MCProgressBar, EmptyState, MCSectionHeader)
  - [x] **Ola 2 — Datos:** 12 repos PostgREST (uno por entidad) + calculadoras `balance`/`waterfall` + edge clients (delete-account real; ai/tts-proxy stubs). Verificados contra DB viva.
  - [x] **Ola 3 — Auth:** email/password + reset (redirect web) + gate biométrico (`local_auth`, FragmentActivity) + **sesión cifrada en Android Keystore** (`SecureLocalStorage`) + `appGateProvider` real (session → household) + pantallas login/signup/crear-unirse-hogar.
  - [x] `applicationId` → `com.metacasa.app`.
  - [ ] Pendientes menores anotados (no bloquean): `households.settings` jsonb, `created_by` a poblar en goal/debt/installment insert, `url_launcher` directo para links legales, timezone IANA real, full CurrenciesCatalog. Se atacan al construir cada feature.

> 🏁 **HITO 2026-05-29: el APK de Android COMPILA** (`flutter build apk --debug` ✓). Toolchain lockeado: minSdk 23, AGP 8.3.2, Gradle 8.7, JDK de Android Studio. Camino a Google Play despejado a nivel técnico.

> **Proceso (modelo empresa):** Ola 1 se construyó con 3 especialistas en paralelo (modelos / componentes / navegación) → comité de revisión adversarial (2 revisores) → reconciliación de blockers (Bill vs schema vivo, localización) → pase de pulido → verificación (analyze + test). Todo verde.
- [x] **Fase 2 — Core financiero** ✅: Home dashboard (balance/stats/top-gastos/semáforo/proyección) · Movimientos (alta/edición/lista + filtros + detalle) · Presupuesto (envelopes + Waterfall + strategy). Lógica de plata con `Decimal`, espejada del iOS.
- [x] **Fase 3 — Satélites** ✅: Cuentas + tarjetas + net worth · Metas + aportes (ETA) · Vencimientos · Recurrentes · Cuotas (ledger) · Deudas (proyección de payoff). Todas wireadas en "Más", compilando en Android.
- [ ] **Fase 4 — Hogares + Settings**: multi-usuario (crear/unirse/invitar/roles) · 13 pantallas de ajustes · multi-moneda/FX · backup/export · privacidad + borrado de cuenta.
- [ ] **Fase 5 — Monetización**: RevenueCat + Play Billing · trial 7d (gate duro) · 2 paywalls.
- [ ] **Fase 6 — IA Asistente**: servicio desacoplado (Anthropic vía `ai-proxy`) · 22 tools · chat + persistencia · voz (speech_to_text + ElevenLabs/`tts-proxy`) · multimodal (OCR/recibos/PDF/XLSX) · consent sheet.
- [ ] **Fase 7 — Reportes + plataforma**: health/Pareto/comparar/anual/heatmap (fl_chart) · notificaciones · widget · App Shortcuts.
- [ ] **Fase 8 — Hardening + Google Play**: cert pinning · JDK17/Gradle · íconos adaptativos + splash · AAB release + signing · Data Safety · listing · closed testing.

## Matriz de paridad (iOS → Flutter)

| Feature iOS | Estado Flutter | Fase |
|---|---|---|
| Design system Midnight Sage | ✅ Hecho | 1 |
| Auth + onboarding + biometría | ⬜ Pendiente | 1 |
| Navegación 5 tabs + FAB | ⬜ | 1 |
| Modelos + repos + Supabase | ⬜ | 1 |
| Home / dashboard | ⬜ | 2 |
| Movimientos (CRUD + filtros + calendario) | ⬜ | 2 |
| Presupuesto (envelopes + waterfall) | ⬜ | 2 |
| Categorías | ⬜ | 2 |
| Cuentas + tarjetas + net worth | ⬜ | 3 |
| Metas + aportes | ⬜ | 3 |
| Vencimientos | ⬜ | 3 |
| Recurrentes (+motor) | ⬜ | 3 |
| Cuotas | ⬜ | 3 |
| Deudas | ⬜ | 3 |
| Hogares multi-usuario | ⬜ | 4 |
| Settings (13 pantallas) | ⬜ | 4 |
| Multi-moneda / FX | ⬜ | 4 |
| Backup / export (CSV/PDF/JSON) | ⬜ | 4/7 |
| Borrado de cuenta | ⬜ | 4 |
| Monetización (paywall + trial) | ⬜ | 5 |
| Asistente IA (chat + 22 tools) | ⬜ | 6 |
| Voz (STT + TTS ElevenLabs) | ⬜ | 6 |
| Multimodal (OCR/PDF/XLSX) | ⬜ | 6 |
| Reportes (health/Pareto/heatmap) | ⬜ | 7 |
| Notificaciones locales | ⬜ | 7 |
| Widget home | ⬜ | 7 |
| App Shortcuts (≈ Siri) | ⬜ | 7 |

## Decisiones de paridad pendientes de confirmar con el usuario
Los **bugs/gaps** listados en IOS_AUDIT §2: ¿replicar bug-for-bug o corregir? Recomendación: corregir los que afectan correctitud de plata (recurrentes/bills/cuotas que no postean, rollover, multi-moneda insert) y dejar el resto igual hasta tener feedback.
