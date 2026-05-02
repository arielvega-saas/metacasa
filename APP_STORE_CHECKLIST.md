# 🚀 MetaCasa — Checklist ejecutivo para App Store submit

Estado al 2026-05-02. Todo lo técnico autonomable está hecho. Lo que falta requiere tu acción directa porque involucra: cuentas externas (Apple Developer, RevenueCat), abogado, hardware físico (iPhone tuyo), o decisiones de negocio.

**Orden recomendado para minimizar bloqueos en cadena.**

---

## SEMANA 1 — Bloqueantes

### 1️⃣ Activar Leaked Password Protection (30 segundos)
1. Abrir https://supabase.com/dashboard/project/rgslvrxdppphzvqgcwbx/auth/providers
2. Bajar a sección "Password Strength and Leaked Password Protection"
3. Toggle ON "Prevent use of leaked passwords"
4. Save

### 2️⃣ Sacar el .ips del crash de mic (5 minutos)
**Sin esto NO se puede arreglar el bug del mic — y sin mic, voice mode tiene un punto de falla.**

1. En tu iPhone: Settings → Privacy & Security → Analytics & Improvements → Analytics Data
2. Buscar archivos que empiezan con `Home Finance-` o `Home Finance-...ips`
3. Tap en el más reciente que tenga "scenebuilder" o crash
4. Tap el icono de Share arriba derecha → AirDrop a tu Mac o copiar a Files
5. Pasame el .ips para diagnosticar el stack trace real

### 3️⃣ Apple Developer + App Store Connect setup (1 día)
1. Verificá que tengas **Apple Developer Program activo** ($99/año en https://developer.apple.com/programs)
2. En App Store Connect (https://appstoreconnect.apple.com):
   - **My Apps → +** crear nueva app
   - Bundle ID: `com.metacasa.app` (debe coincidir con `project.yml:24`)
   - SKU: `metacasa-ios-001`
   - User access: Full Access
3. **Agreements, Tax, and Banking**: completar Free + Paid Apps Agreement (Apple no procesa pagos hasta esto)

### 4️⃣ RevenueCat dashboard setup (2-3h)
**Sin esto el paywall queda en placeholder mode — no podés cobrar.**

A. **App Store Connect** primero:
   1. My Apps → MetaCasa → In-App Purchases → +
   2. Crear:
      - **Premium Mensual** (Auto-Renewable Subscription)
        - Product ID: `com.metacasa.premium.monthly`
        - Subscription Group: `MetaCasa Premium`
        - Price tier: Tier 4 ($3.99 USD aprox, depende de mercado)
        - Localizations: ES, EN, PT-BR
        - 7-day free trial habilitado
      - **Premium Anual** (Auto-Renewable Subscription)
        - Product ID: `com.metacasa.premium.annual`
        - Same group: `MetaCasa Premium`
        - Price tier: Tier 25 ($24.99 USD aprox)
        - 7-day free trial habilitado
   3. Crear App Store Connect API key:
      - Users and Access → Keys → In-App Purchase → +
      - Name: "RevenueCat"
      - Download .p8 (solo se descarga una vez, guardalo)
      - Anotar Key ID + Issuer ID

B. **RevenueCat dashboard** (https://app.revenuecat.com):
   1. Create new project → "MetaCasa"
   2. App Settings → iOS App → Apple App Store
      - Bundle ID: `com.metacasa.app`
      - Subir el .p8 de Apple
      - Pegar Key ID + Issuer ID
   3. Products → Import from App Store (auto-detecta los 2 productos creados antes)
   4. Entitlements → + Create
      - Identifier: `premium`
      - Attached products: ambos (`monthly` + `annual`)
   5. Offerings → "default" (default offering) → agregar packages para cada producto
   6. Webhooks → + Add
      - URL: `https://rgslvrxdppphzvqgcwbx.supabase.co/functions/v1/revenuecat-webhook`
      - Authorization: anotar el bearer secret que generes
   7. API Keys → copiar la **iOS Public SDK Key** (empieza con `appl_`)

C. **Pegar API key en iOS**:
   1. Editar `metacasa-ios/MetaCasa/Supporting/Info.plist`
   2. Agregar:
      ```xml
      <key>REVENUECAT_API_KEY</key>
      <string>appl_TU_KEY_ACA</string>
      ```
   3. Rebuild iOS

D. **Webhook secret en Supabase**:
   1. https://supabase.com/dashboard/project/rgslvrxdppphzvqgcwbx/functions/secrets
   2. + Add Secret
      - Name: `REVENUECAT_WEBHOOK_SECRET`
      - Value: el bearer secret del paso B.6

### 5️⃣ Privacy Policy review legal (1-2 semanas en paralelo)
- Mandar el documento actual a un abogado especializado en privacy/finance apps
- URLs activas: 
  - https://metacasa-app-cf592.web.app/privacy.html
  - https://metacasa-app-cf592.web.app/terms.html
- Pedirle que complete:
  - Sección 9 de Terms ("[JURISDICCIÓN A COMPLETAR ANTES DE LANZAR]")
  - Adapte a GDPR/CCPA/LFPDPPP/LGPD según mercados objetivo
  - Revise sección 6 de Privacy (terceros: Anthropic, ElevenLabs, Supabase, RevenueCat)
- Una vez aprobado por abogado, actualizar:
  - `metacasa-ios/MetaCasa/Features/Settings/LegalView.swift`
  - `public/privacy.html` y `public/terms.html`
  - `npm run build && firebase deploy --only hosting`

---

## SEMANA 2 — Assets visuales

### 6️⃣ Screenshots App Store (4-6h)
**Apple requiere mínimo 1 size obligatorio: 6.9" (1320×2868) — los demás son legacy/opcionales.**

1. Sacar 5-7 screenshots por idioma desde tu iPhone físico:
   - Settings → Display → Cargar screenshots con datos REALES (los del review se ven mal sin data)
2. Lo más fácil: usar **Xcode Screenshot Helper** o tomar capturas directas en device.
3. Resoluciones requeridas:
   - **6.9" iPhone 16/17 Pro Max**: 1320×2868 o 2868×1320 ✓ obligatorio
   - **6.5" iPhone 11 Pro Max**: 1242×2688 (legacy, recomendado)
4. Pantallas a capturar:
   - Home dashboard
   - Lista de Movimientos
   - Voice mode con orb activo
   - Tab Presupuesto envelope
   - Reportes / Health Score
   - Configuración del hogar
   - (Opcional) Plan Editor visual

### 7️⃣ App Privacy Nutrition Label (30 minutos)
1. App Store Connect → MetaCasa → App Privacy → Get Started
2. Declarar exactamente lo que dice `metacasa-ios/MetaCasa/Supporting/PrivacyInfo.xcprivacy`:
   - **Email Address** (linked to identity, used for: app functionality + authentication, not used for tracking)
   - **User ID** (linked to identity, used for: app functionality + authentication, not used for tracking)
   - **Tracking**: NO

### 8️⃣ Pegar el copy de App Store (1h)
Todo el texto está en `APP_STORE_COPY.md`. Pegá literal:
- Name, Subtitle, Promotional Text, Description, Keywords, What's New
- Para los 3 idiomas (ES, EN, PT-BR)
- URLs: privacy + terms + support
- Category: Finance / Productivity
- Age Rating: 4+

### 9️⃣ Demo account para Apple Review (30 minutos)
Apple necesita una cuenta de prueba para revisar la app:
1. Crear una cuenta nueva con email tipo `review@metacasa.app` (usá un email tuyo válido)
2. Cargar 3 meses de transacciones de ejemplo
3. Crear 4 budgets, 2 goals, 1 invitación de hogar
4. App Store Connect → App Review Information:
   - Sign-in Required: Yes
   - User name: `review@metacasa.app`
   - Password: (uno fuerte)
   - Notes: pegado el texto que está en `APP_STORE_COPY.md` → sección "App Review Information → Notes for reviewer"

---

## SEMANA 2-3 — Validación

### 🔟 Sentry SDK (opcional pero recomendado)
**No es bloqueante para submit, pero te avisa de crashes en producción.**

1. Crear cuenta en https://sentry.io (free tier alcanza al inicio)
2. New Project → Apple → iOS → name "metacasa-ios"
3. Copiar el DSN (formato: `https://abc@o123.ingest.sentry.io/456`)
4. Agregar al `metacasa-ios/project.yml`:
   ```yaml
   packages:
     # ... existing
     Sentry:
       url: https://github.com/getsentry/sentry-cocoa
       from: "8.40.0"
   ```
   Y al target dependencies:
   ```yaml
   dependencies:
     # ... existing
     - package: Sentry
       product: Sentry
   ```
5. Regenerar Xcode project: `cd metacasa-ios && xcodegen generate`
6. Crear `metacasa-ios/MetaCasa/Core/ObservabilityService.swift`:
   ```swift
   import Foundation
   import Sentry

   enum ObservabilityService {
       static func boot() {
           guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
                 !dsn.isEmpty else {
               print("[Sentry] DSN missing in Info.plist — skipping init")
               return
           }
           SentrySDK.start { options in
               options.dsn = dsn
               options.enableAutoPerformanceTracing = false
               options.enableUserInteractionTracing = false
               options.attachScreenshot = false
               options.attachViewHierarchy = false
               options.environment = "production"
           }
       }
   }
   ```
7. Llamar en `MetaCasaApp.init()`: `ObservabilityService.boot()`
8. Pegar DSN al `Info.plist` como `SENTRY_DSN`

### 1️⃣1️⃣ TestFlight beta (1-2 semanas)
1. Xcode → Product → Archive (con el scheme MetaCasa, configuración Release)
2. Distribute App → App Store Connect → Upload
3. Esperar 5-15 min hasta que aparezca en ASC (automatic processing)
4. Internal Testing: agregar tu email + 2-3 personas de confianza
5. External Testing: + 30 emails amigos/familia (no requiere review de Apple)
6. Pedirles que prueben:
   - Signup + login
   - Cargar 5 transacciones
   - Crear 1 meta
   - Voice assistant (decirle algo)
   - Eliminar hogar y crear nuevo
7. Recolectar bugs por 1 semana mínimo

---

## SEMANA 4 — Submit

### 1️⃣2️⃣ Submit final
1. Subir build final desde Xcode (incrementar `MARKETING_VERSION` en `project.yml` si hubo cambios desde TestFlight)
2. App Store Connect → MetaCasa → App Store → +
3. Seleccionar el build de TestFlight
4. Verificar: copy ✓, screenshots ✓, IAPs ✓, privacy label ✓, demo account ✓
5. **Submit for Review**

Apple tarda 24-72h en review. Common rejections para finance apps:
- Privacy Policy URL inaccesible → ✓ ya tenés Firebase live
- "Account creation required" → declarar Sign-in Required
- "App Tracking Transparency missing" → si no trackeás, declararlo en Privacy Manifest (ya está)
- Demo account no funciona → testealo antes de submit

---

## ⚡ Resumen de tiempos realistas

| Acción | Tiempo | Bloqueante? |
|--------|--------|-------------|
| 1. Leaked Password Protection | 30 seg | Soft |
| 2. Stack trace .ips | 5 min | Sí (mic) |
| 3. Apple Developer + ASC | 4h | Sí |
| 4. RevenueCat setup | 3h | Sí |
| 5. Abogado | 1-2 sem | Soft |
| 6. Screenshots | 4-6h | Sí |
| 7. Privacy Nutrition Label | 30 min | Sí |
| 8. Pegar copy en ASC | 1h | Sí |
| 9. Demo account | 30 min | Sí |
| 10. Sentry | 2h | No (opcional) |
| 11. TestFlight beta | 1-2 sem | Sí |
| 12. Submit + Apple review | 1 sem | Sí |

**Tiempo total realista: 3-5 semanas** para un submit con confianza.

---

## 🆘 Si te trabás

- **No sabés cómo crear IAP en ASC**: Apple docs https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/overview-for-in-app-purchases
- **No sabés cómo configurar RevenueCat**: video tutorial https://www.revenuecat.com/docs/getting-started/quickstart
- **Mic sigue trabándose**: pasame el .ips y lo arreglo
- **Cambios en Privacy Policy del abogado**: editá `LegalView.swift` + `public/privacy.html` + `npm run build && firebase deploy --only hosting`

---

Última actualización: 2026-05-02 (auto-generado por Claude Code)
