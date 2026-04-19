# MetaCasa iOS — Home Finance

App nativa iOS de gestión de finanzas del hogar. Parte de la Fase 3 del proyecto MetaCasa.

## Stack

- **Swift 6** (strict concurrency)
- **SwiftUI** para UI
- **SwiftData** para cache local (agregado en próximas fases)
- **supabase-swift** para backend (auth + data + realtime)
- **RevenueCat** para suscripciones (a integrar en próximas sesiones)
- **iOS 17+** como deployment target

## Setup inicial (solo la primera vez)

### 1. Instalar XcodeGen

```bash
brew install xcodegen
```

### 2. Generar el proyecto Xcode

```bash
cd metacasa-ios
xcodegen generate
```

Esto crea `MetaCasa.xcodeproj` desde `project.yml`. **Nunca commitees** `MetaCasa.xcodeproj` (está en .gitignore) — siempre se regenera.

### 3. Configurar Team ID en Xcode

Abrí `MetaCasa.xcodeproj` en Xcode. En la pestaña **Signing & Capabilities**:
- Seleccioná tu team Apple Developer.
- Ajustá Bundle Identifier si hace falta (default: `com.metacasa.app` — cambialo a algo que te pertenezca en tu developer account).

### 4. Configurar secretos de Supabase

El proyecto lee `SUPABASE_URL` y `SUPABASE_ANON_KEY` desde `Info.plist`. Los valores actuales apuntan al proyecto Supabase `METACASA` (id `rgslvrxdppphzvqgcwbx`). Si en algún momento cambiás de proyecto, editá `MetaCasa/Info.plist`.

### 5. Correr en simulador

En Xcode: selecciona un simulador iOS 17+ (iPhone 15, 16 o 17 Pro) y hacé `Cmd+R`. Al primer build, Xcode descarga las dependencias (supabase-swift, RevenueCat).

## Estructura

```
MetaCasa/
├── App/                  Entry point (MetaCasaApp, AppState, RootView)
├── Core/                 Servicios: Supabase, Auth, Keychain, Biometrics, Design System
├── Models/               Modelos Codable mapeados al schema Supabase
├── Features/             UI dividida por dominio
│   ├── Onboarding/       Login, Signup, crear/unirse a hogar
│   ├── Home/             Dashboard principal
│   ├── Transactions/     Agregar y listar movimientos
│   ├── Budget/           Envelope budget (YNAB-style)
│   ├── Accounts/         Cuentas bancarias y tarjetas
│   ├── Goals/            Metas de ahorro (placeholder, próxima fase)
│   ├── Settings/         Ajustes del hogar y de la app
│   └── Paywall/          RevenueCat paywall (placeholder)
└── Supporting/           Info.plist, entitlements, Assets.xcassets
```

## Principios de diseño

- **Swift strict concurrency**: `@MainActor` en ViewModels y views; todos los `async` bien anotados.
- **Codable models** espejan las tablas Supabase 1:1. No hay ORM.
- **Auth flow**: email+password → sesión en Keychain → biometría requerida para abrir la app en re-launches.
- **RLS-aware**: el cliente asume que Supabase filtra por household. Nunca hacemos filtros de seguridad client-side.
- **Multi-hogar**: el `AppState` expone `currentHouseholdId`. Toda query pasa por ahí.

## Features incluidos en este scaffold (Fase 3.1)

- [x] Login / Signup con Supabase Auth
- [x] Crear hogar nuevo / (TODO) unirse con invite token
- [x] Home con saldo disponible del mes
- [x] Agregar transacción (gasto / ingreso)
- [x] Listar transacciones del período
- [x] Envelope budget con Ready to Assign
- [x] Cuentas (listar, agregar básica)
- [x] Ajustes (logout, cambiar hogar, moneda)
- [x] Design system (tokens de colores, tipografía, spacing)
- [x] Keychain + biometría baseline

## Pendientes próximas sesiones

- Biometría fullscreen al reabrir app (actualmente solo al login)
- RevenueCat SDK + paywall funcional
- Goals (CRUD + contribuciones)
- Cuentas: tarjetas de crédito (vencimiento, mínimo, interés)
- Multi-moneda con FX automático
- Widgets (Home Screen + Lock Screen)
- Live Activities para saldo
- Push notifications de presupuesto superado
- Shortcuts / App Intents para "registrar gasto con Siri"
- SwiftData cache local + offline
- Unit tests + UI tests
- Fastlane + TestFlight CI
- Certificate pinning
- Localización (es, en, pt)

## Comandos útiles

```bash
xcodegen generate              # Regenerar .xcodeproj desde project.yml
xcodegen generate --spec project.yml

# Borrar caches Xcode si algo se rompe
rm -rf ~/Library/Developer/Xcode/DerivedData/MetaCasa-*
```

## Troubleshooting

- **"Missing package product 'Supabase'"**: Xcode → File → Packages → Reset Package Caches.
- **Build falla con Swift 6 strict concurrency**: revisá que los ViewModels sean `@MainActor` y los `actor` sean aislados correctamente.
- **Login funciona en simulador pero no en device real**: verificá el Team ID en Signing & Capabilities + que tengas Apple Developer Program activo.
