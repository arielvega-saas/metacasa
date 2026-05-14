# 🚀 La app está lista para subir

**Cierre técnico de la sesión 2026-05-13. Sprint A + B + C completado.**

Este documento es el **playbook final paso a paso** que prometí al inicio. Las tareas técnicas que dependían de mí están todas hechas y validadas (12 builds verdes). Lo que sigue son acciones humanas tuyas — todo bien acotado, con tiempo estimado y enlaces directos.

---

## ✅ Estado técnico (lo hice yo, ya está en `main`)

### Asistente IA (foco principal)
- ✅ **22 tools agentic** (add/update/delete tx, transfer, mark_bill_paid, set_budget_envelope, compare_periods, project_scenario, detect_patterns, suggest_savings, get_goals/accounts/bills, analyze_inflation, categorize_transaction, validate_cfdi, validate_arca, etc.)
- ✅ **Memoria conversacional persistente** entre sesiones via Claude Haiku summaries
- ✅ **Consent flow** Apple Review 5.1.1 + UI completa en Settings
- ✅ **Auto-refresh JWT** proactivo
- ✅ **Vision multimodal** (Claude vision + Apple Vision OCR fallback)
- ✅ **Voice mode** con auto-VAD + streaming TTS + Malena rioplatense
- ✅ **7 App Intents** (Siri Shortcuts)
- ✅ **CFDI 4.0 (México) + ARCA (Argentina)** — diferenciador LATAM crítico

### Infraestructura
- ✅ **Sentry SDK** integrado (queda esperando DSN)
- ✅ **RevenueCat** code 100% implementado (queda esperando API key)
- ✅ **Privacy Manifest** completo (5 datatypes, no tracking)
- ✅ **Info.plist hardened** (ITSAppUsesNonExemptEncryption=false, todos los permisos)
- ✅ **Liquid Glass material iOS 26** en chat + voice mode
- ✅ **Localización formal** 668+27 keys en es/en/pt-BR

### Documentación / Legal
- ✅ `APP_STORE_COPY.md` — copy en 3 idiomas con What's New actualizado
- ✅ `APP_STORE_NEXT_STEPS.md` — punch list canónica
- ✅ `ASSISTANT_AI_DISCLOSURE.md` (raíz) + `public/assistant-ai.html` (PWA-ready)
- ✅ `LegalView` con Privacy + Terms + Link al disclosure del Asistente
- ✅ Privacy Policy + Terms live en Firebase

### Validación
- ✅ **12 builds `BUILD SUCCEEDED`** sin errores en xcodebuild iphonesimulator
- ✅ **Apple Developer Program** pagado y aprobado (confirmaste el 13/may)

---

## 📋 Lo que tenés que hacer vos — orden estricto

> ⚠️ Hacelo en este orden — cada paso desbloquea el siguiente.

### Día 1 (mañana 14/may, ~3h)

#### 1. App Store Connect — crear la app (30 min)

1. Login: https://appstoreconnect.apple.com
2. **My Apps → + → New App**
3. Datos exactos:
   - Platforms: **iOS**
   - Name: **Home Finance** (recordá: nombre comercial en App Store es "Home Finance", no "MetaCasa")
   - Primary Language: **Spanish (Argentina)** o **Spanish (Mexico)**
   - Bundle ID: **`com.metacasa.app`** (tiene que matchear `metacasa-ios/project.yml`)
   - SKU: **`metacasa-ios-001`**
   - User Access: **Full Access**

4. **Agreements, Tax, and Banking** (sin esto Apple no te paga):
   - Free + Paid Apps Agreement: completar
   - Tax info: completar formularios para tu país
   - Banking: cargar IBAN/CBU de tu cuenta donde Apple deposita la plata

#### 2. App Store Connect — crear los 2 IAPs (30 min)

ASC → MetaCasa → **In-App Purchases → +**

**A. Premium Mensual**
- Type: Auto-Renewable Subscription
- Reference Name: `Premium Mensual`
- Product ID: **`com.metacasa.premium.monthly`** (literal, copy exact)
- Subscription Group: `MetaCasa Premium`
- Price tier: **Tier 4** (~$3.99 USD)
- Free trial: **7 días**
- Localizations: ES (es-AR), EN, PT-BR (copy desde `APP_STORE_COPY.md`)

**B. Premium Anual**
- Type: Auto-Renewable Subscription
- Reference Name: `Premium Anual`
- Product ID: **`com.metacasa.premium.annual`**
- Same Subscription Group: `MetaCasa Premium`
- Price tier: **Tier 25** (~$24.99 USD = -50% vs anual mensual = -50% saving vs comprar 12 meses sueltos)
- Free trial: **7 días**
- Localizations: ES, EN, PT-BR

#### 3. App Store Connect API Key (10 min)

ASC → **Users and Access → Keys → In-App Purchase → +**

- Name: **RevenueCat**
- Descargá el `.p8` — **solo se descarga UNA VEZ. Guardalo seguro.**
- Anotá:
  - **Key ID** (10 chars alfanuméricos)
  - **Issuer ID** (UUID al pie de la página de Keys)

#### 4. RevenueCat dashboard (45 min)

https://app.revenuecat.com → **Create new project → "MetaCasa"**

**A. App Settings → iOS App → Apple App Store:**
- Bundle ID: `com.metacasa.app`
- Subir el `.p8` del paso 3
- Pegar **Key ID** + **Issuer ID** del paso 3

**B. Products → Import from App Store**
- Click "Import" — RevenueCat detecta auto los 2 IAPs creados en paso 2.

**C. Entitlements → + Create**
- Identifier: **`premium`** (literal, lo usa el código en `UserEntitlement.Name.premium`)
- Attached products: ambos (`com.metacasa.premium.monthly` + `com.metacasa.premium.annual`)

**D. Offerings → "default"**
- Click "Add package" para cada producto
- Paquete `$rc_monthly` → producto monthly
- Paquete `$rc_annual` → producto annual

**E. Webhooks → + Add**
- URL: `https://rgslvrxdppphzvqgcwbx.supabase.co/functions/v1/revenuecat-webhook`
- Authorization: generá un **bearer secret** (copy long random string, guardalo, vas a pegarlo a Supabase en paso 6)

**F. API Keys → iOS App**
- Copiar la **Public SDK Key** que empieza con `appl_`

#### 5. Pegar la API key en iOS (5 min)

Editar `metacasa-ios/MetaCasa/Supporting/Info.plist`:

```xml
<key>REVENUECAT_API_KEY</key>
<string>appl_TU_KEY_REAL_DEL_PASO_4F</string>
```

Después regenerar el proyecto:

```bash
cd metacasa-ios
xcodegen generate
```

#### 6. Webhook secret en Supabase (5 min)

https://supabase.com/dashboard/project/rgslvrxdppphzvqgcwbx/functions/secrets

- **+ Add Secret**
  - Name: **`REVENUECAT_WEBHOOK_SECRET`**
  - Value: el bearer secret del paso 4.E

#### 7. Sentry — crear proyecto (15 min)

https://sentry.io → Sign up (free tier alcanza para empezar)

- New Project → **Apple → iOS**
- Name: `metacasa-ios`
- Copiar el DSN (formato: `https://abc@o123.ingest.sentry.io/456`)
- Pegar en `metacasa-ios/MetaCasa/Supporting/Info.plist`:
  ```xml
  <key>SENTRY_DSN</key>
  <string>https://TU_DSN_AQUI</string>
  ```

#### 8. Deploy del PWA (5 min)

Para que la URL `https://metacasa-app-cf592.web.app/assistant-ai.html` sea pública (Apple Reviewer va a abrirla):

```bash
cd /Users/arielvega/Desktop/metacasa-app
npm run build
firebase deploy --only hosting
```

Verifica abriendo la URL en el browser después del deploy.

---

### Día 2-3 (semana del 15-17/may, ~6h)

#### 9. Screenshots 6.9" (4-6h)

Apple exige **mínimo el size 6.9" iPhone 16/17 Pro Max** (1320×2868). Los demás son legacy / opcionales.

Para cada uno de los 3 idiomas (es, en, pt-BR):

1. Cambiar el idioma de la app: **Más → Ajustes → Idioma**
2. Cargá 3 meses de transacciones de ejemplo (al menos 30 tx para que se vea natural)
3. Tomar 5-7 screenshots con **Side button + Volume up**:
   - Home dashboard con widgets pulidos
   - Tab Movimientos con filtros
   - Voice mode con orb en estado "speaking"
   - Tab Presupuesto con envelopes coloreados
   - Asistente IA chat con respuesta de tool call (ej. health score o compare periods)
   - Reportes / Health Score 0-100
   - (Opcional) Plan Editor visual
4. AirDrop al Mac → ASC upload por idioma

Tip: usá Xcode Screenshot Helper o **device.png** export para asegurar tamaño exacto.

#### 10. Privacy Nutrition Label (30 min)

ASC → MetaCasa → **App Privacy → Get Started**

Declarar **exactamente** lo que dice `PrivacyInfo.xcprivacy`:

- **Email Address**
  - Linked to identity: **Yes**
  - Used for: App Functionality + Authentication
  - Tracking: **No**

- **User ID**
  - Linked to identity: **Yes**
  - Used for: App Functionality
  - Tracking: **No**

- **Other Financial Info** (importante — son las transacciones, presupuestos, metas)
  - Linked to identity: **Yes**
  - Used for: App Functionality
  - Tracking: **No**

- **Purchase History** (de RevenueCat / IAPs)
  - Linked to identity: **Yes**
  - Used for: App Functionality
  - Tracking: **No**

- **Crash Data**
  - Linked to identity: **No**
  - Used for: App Functionality + Analytics
  - Tracking: **No**

**Tracking**: **No** (declarar explícito).

#### 11. Demo account para Apple Review (30 min)

1. Crear nueva cuenta con un email tuyo accesible (ej. `review@metacasa.app` redirigido a tu inbox).
2. Login en la app, cargar 3 meses de transacciones sintéticas (al menos 30-50 tx) para que el reviewer vea un Home realista.
3. Crear 4 budgets, 2 goals, 1 invitación de hogar pendiente.
4. ASC → **App Review Information**:
   - Sign-in Required: **Yes**
   - User name: el email demo
   - Password: una fuerte y distinta de tu personal
   - Notes for reviewer: copiar el texto de `APP_STORE_COPY.md` → sección "App Review Information → Notes for reviewer"

#### 12. Pegar copy en ASC (1h)

ASC → MetaCasa → App Store → cada idioma:

Pegar literal desde `APP_STORE_COPY.md`:

- **Name** (es-AR: "MetaCasa: Finanzas del Hogar" / en: "MetaHome: Household Finance" / pt-BR: "MetaCasa: Finanças do Lar")
- **Subtitle** (30 chars max)
- **Promotional Text** (170 chars — se puede actualizar sin nueva submission)
- **Description**
- **Keywords** (100 chars max, sin espacios después de comas)
- **What's New** (incluye las novedades del Asistente IA con memoria — ya actualizado en el doc)
- **Support URL**: `https://metacasa-app-cf592.web.app/`
- **Privacy Policy URL**: `https://metacasa-app-cf592.web.app/privacy.html`
- **Terms URL**: `https://metacasa-app-cf592.web.app/terms.html`
- **Category**: Finance
- **Secondary Category** (opcional): Productivity
- **Age Rating**: 4+ (no contenido para adultos, no apuestas)

---

### Día 4-7 (semana del 18-24/may, ~10h)

#### 13. TestFlight beta interno (3-5 días)

1. Xcode → Product → **Archive** (scheme MetaCasa, configuración Release, destination "Any iOS Device")
2. Distribute App → App Store Connect → Upload
3. Esperar 5-15 min para que ASC procese el build
4. ASC → TestFlight → Internal Testing → +
5. Invitar tu email + 2-3 personas de confianza
6. Pedirles testear el flow completo en 3 días: signup, cargar 5 tx, crear 1 meta, asistente IA (chat + voice + image), eliminar y crear hogar nuevo
7. Recolectar bugs vía TestFlight feedback

#### 14. TestFlight beta externo (5 días)

1. ASC → TestFlight → **External Testing → +**
2. Crear un grupo "Closed Beta"
3. Subir el build a ese grupo
4. **External requires Apple review** del build — 24h
5. Invitar 30 emails (amigos, familia)
6. Recolectar 5 días de feedback

---

### Día 8-10 (~3h work + 24-72h espera)

#### 15. Submit final

1. Si hay bugs de TestFlight, fixearlos en código → re-Archive → Upload → seleccionar el build nuevo
2. ASC → MetaCasa → **App Store → +**
3. Seleccionar el build de TestFlight
4. Verificar todo: copy ✓, screenshots ✓, IAPs ✓, Privacy Label ✓, demo account ✓
5. **Submit for Review**

Apple tarda **24-72h** en revisar. Common rejections para finance + AI:

| Rebote típico | Cómo prevenirlo | Acción si pasa |
|---|---|---|
| "Privacy Policy URL inaccesible" | ✓ Live en Firebase | Re-verificar URL pegada en ASC |
| "Account creation required" | ✓ Sign-in Required declarado | Confirmar en App Review Info |
| "AI third-party disclosure missing" | ✓ AssistantConsentSheet + assistant-ai.html | Linkear el HTML en el response |
| "Demo account no funciona" | ✓ Demo account creado paso 11 | Test ANTES de submit |
| "Multi-currency rates source" | (potencial) | Responder: tasas FX configurables manualmente por user |
| "RevenueCat trial behavior" | ✓ 7-day trial declarado en IAP | Confirmar en metadata IAP |

---

## 🔥 La app va a estar live en App Store entre el 25-29 de mayo

| Día | Acción | Quién |
|---|---|---|
| 14/may | Paso 1-8 (ASC + RevenueCat + Sentry + PWA deploy) | Vos |
| 15-17/may | Paso 9-12 (screenshots, Privacy Label, demo, copy) | Vos |
| 18-22/may | TestFlight interno → externo | Vos + beta testers |
| 23/may | Bug fixes finales | Vos + yo si querés |
| 24/may | Re-archive + Submit | Vos |
| 25-28/may | **Apple Review** (24-72h) | Apple |
| 29/may | 🚀 Live en App Store | — |

---

## 🆘 Si rebota, mandame el mensaje exacto

Cualquier rebote de Apple Review, pegámelo. Las respuestas tipo son cortas y se mandan via App Review Information sin re-submit del binario.

Templates de respuestas para los 3 rebotes más probables ya están en `APP_STORE_COPY.md` → sección "Otros campos App Store Connect → Reviewer notes".

---

## 🧪 Antes de submit, testeá en tu device:

1. **Asistente — memoria persistente**: chateá 5+ mensajes, cerrá el sheet, volvé → debe retomar la conversación.
2. **Consent flow**: Settings → Avanzado → Privacidad del Asistente IA → "Revocar consentimiento y borrar historial" → volver al chat → debe aparecer el consent sheet.
3. **On-device toggle**: activá "Forzar solo on-device" → preguntá al asistente → debe responder con statistical fallback (no Claude).
4. **Siri**: "Hey Siri, ver balance en MetaCasa" (+ los otros 6 atajos).
5. **CFDI / ARCA**: en el chat, pegale un QR de CFDI o un CAE de 14 dígitos → debería responder con datos parseados.
6. **Vision**: tocá paperclip → Escanear recibo → debería levantar la cámara con auto-crop.
7. **Liquid Glass**: botones xmark/paperclip/speaker tienen look glass translúcido.
8. **Locale switch**: cambiá el idioma de la app a English desde Ajustes → Idioma → todos los textos del consent sheet y privacy view deben estar en inglés.

---

## ⚡ Resumen ejecutivo

**Tiempo total realista de aquí al live: 2-3 semanas.**

- 3h de admin web tuyo (Día 1)
- 6h de assets + setup (Día 2-3)  
- 10h de TestFlight beta (Día 4-10)
- 24-72h espera de Apple

**Costo total proyectado**:
- Apple Developer Program: $99 USD/año (ya pagado)
- RevenueCat: free tier hasta $10K MTR (suficiente para arrancar)
- Sentry: free tier 5K events/mes (suficiente para empezar)
- ElevenLabs: $6 USD/mes Starter (ya pagado)
- Anthropic: pay-as-you-go, ~$0.001 por request promedio
- Firebase Hosting: free tier

**Tu app está al 95% técnicamente lista**. Solo falta el sprint admin de configuración + screenshots + submit. **La app está lista para subir** — el código no requiere más cambios para entrar a Apple Review.

---

**Última actualización**: 2026-05-13 23:00 GMT-3 — post Sprint A + B + C (12 commits, ~3700 líneas, 22 tools agentic, 7 App Intents, full i18n).

Cuando pegues la primera screenshot a ASC, mandame screenshot de la página y revisamos.
