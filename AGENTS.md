# MetaCasa — Codex project guide

App de finanzas personales del hogar. Hoy es una **PWA en React + Vite + Tailwind v4 + Supabase + Firebase Hosting**. La dirección estratégica confirmada es migrar a **iOS nativo (Swift 6 + SwiftUI + SwiftData) y Android nativo (Kotlin + Jetpack Compose + Room)**, manteniendo Supabase como backend. La PWA se refactoriza en paralelo (no se congela).

## Stack actual

| Capa | Tecnología |
|------|------------|
| Frontend (PWA) | React 18 + Vite 7 + Tailwind v4 + @dnd-kit + lucide-react |
| Backend | Supabase (Postgres 17.6) — proyecto `METACASA` id `rgslvrxdppphzvqgcwbx`, región us-east-1 |
| Auth | Supabase Auth (email + OAuth) |
| Hosting PWA | Firebase Hosting — https://metacasa-app-cf592.web.app/ |
| Edge Functions | Deno — `wallet-proxy` para OAuth y proxy a wallets LatAm |
| Monetización (próximo) | RevenueCat (iOS + Android) |

## Estructura del repo

```
metacasa-app/
├── src/
│   ├── main.jsx           Entry point Vite (monta AppWithProviders)
│   ├── App.jsx            MONOLITO 16k+ líneas — a refactorizar (Fase 2)
│   ├── supabaseClient.js  Cliente Supabase desde .env
│   ├── index.css          Design tokens + Tailwind
│   └── assets/            Logos e imágenes
├── public/                Static + PWA manifest, iconos
├── scripts/
│   └── copy-public.mjs    Post-build: copia assets a dist/
├── supabase/
│   └── migrations/        SQL versionado de cambios en DB
├── UI_NOTES.md            Design system (dark theme, glass cards, tokens)
├── AGENTS.md              Este archivo
├── firebase.json          Config Firebase Hosting (deploy desde dist/)
├── vite.config.js         publicDir=public, copyPublicDir=false
└── package.json           Node 20+, Vite 7, React 18
```

## Comandos útiles

```bash
npm run dev                       # Dev server local (vite)
npm run build                     # Build a dist/ + copy-public.mjs
npm run preview                   # Preview del build
npx firebase deploy               # Deploy a Firebase Hosting
```

## Mercados y producto

- **Target**: US + global como core; LatAm como plus/diferenciador (mantener integraciones MercadoPago/Uala/Brubank/NaranjaX).
- **Multi-usuario por hogar**: obligatorio. Modelo `households` + `household_members` en DB (diseñado en Fase 1).
- **Monetización**: RevenueCat — Free tier + Premium (mensual/anual). A/B testing de precios. Trials 7 días.
- **Lógica de presupuesto**: zero-based (YNAB) + envelopes (Goodbudget) + "In my pocket" (PocketGuard) con rollover.

## Convenciones

- **SQL**: `snake_case` para tablas y columnas. Todas las tablas `public.*` llevan RLS obligatorio.
- **RLS policies**: usar `(select auth.uid())`, nunca `auth.uid()` plano (perf).
- **Migraciones**: cada cambio de schema vía `apply_migration` + archivo versionado en `supabase/migrations/YYYYMMDDHHMMSS_nombre.sql`.
- **Secrets**: `.env` (ignorado por git). Nada de claves de service_role en frontend.
- **Logs sensibles**: nunca loguear `access_token`, `refresh_token`, emails, balances.
- **Frontend**: Tailwind v4 + clases del design system en [UI_NOTES.md](UI_NOTES.md). No estilos inline.

## Seguridad (MASVS + OWASP Mobile + fintech)

- **Tokens OAuth** de wallets: cifrados en DB con pgcrypto + Vault. Usar `public.get_wallet_access_token(wid)` desde edge functions (service_role).
- **Biometría**: Face ID / Touch ID / BiometricPrompt obligatorio en apps nativas (Fase 3/4).
- **Certificate pinning**: en nativo, pinning a `*.supabase.co`.
- **Keychain / Android Keystore**: única ubicación aceptable para refresh tokens en mobile nativo.
- **Nunca logguear**: `access_token`, `refresh_token`, emails, balances, PAN/CVV (no deberíamos tocar tarjetas).

## Roadmap vigente

- **Fase 0** (en curso / hecha): auditoría, fixes RLS performance, índices FK, cifrado tokens, migraciones versionadas, limpieza repo.
- **Fase 1** (en curso): schema canónico — households, accounts, envelope budgets, goals, entitlements RevenueCat, multi-moneda extendida.
- **Fase 2**: refactor del monolito `src/App.jsx` en componentes/hooks/services.
- **Fase 3**: iOS nativo MVP (Swift 6 + SwiftUI + SwiftData + supabase-swift + RevenueCat).
- **Fase 4**: Android nativo (Kotlin + Compose + Room + supabase-kt + RevenueCat).

Ver `~/.Codex/projects/-Users-arielvega-Desktop-metacasa-app/memory/project_metacasa_next_actions.md` para acciones concretas pendientes.

## Precaución

- **No tocar `src/App.jsx`** en bloque sin un plan de refactor — es 16k líneas con 22 widgets interdependientes.
- **No borrar** `src/assets/logo-v*.jpg` mientras `App.jsx` los importe.
- **No commitear** `.env`, `.env.bak`, ni claves de service_role.
- **No pushear a main** sin revisar los cambios — especialmente migraciones de DB.
- **`wallet-proxy` edge function**: cualquier cambio requiere mantener compatibilidad con el flujo de OAuth (`oauth_exchange`, `oauth_refresh`) y el de proxy (`wallet_id`).
