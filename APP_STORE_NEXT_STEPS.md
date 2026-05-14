# MetaCasa — App Store, próximos pasos concretos

**Actualizado**: 2026-05-13 22:30 GMT-3 — post Sprint A (memoria + consent + auto-refresh + tools nuevas).

Este doc es la **punch-list canónica** de lo que falta para subir a la App Store. Los pasos administrativos (acción humana de Ariel) están separados de los pasos técnicos (que puedo automatizar yo).

Para historial completo: ver `APP_STORE_CHECKLIST.md` (versión 2026-05-02) y `APP_STORE_COPY.md` (copy en 3 idiomas).

---

## ✅ Ya está hecho (no hay que volver a tocar)

**Backend/Supabase** (sesión 2026-05-01):
- Tokens OAuth wallets cifrados con pgcrypto + Vault.
- 18+ migraciones versionadas, 6 índices FK, security definer revocados.
- `ai-proxy` v6 + `tts-proxy` v6 — quotas 1000/d, 30000/m.
- Leaked Password Protection: ON.

**iOS — Infraestructura legal y de privacidad**:
- Privacy Policy + Terms live en https://metacasa-app-cf592.web.app/privacy.html y /terms.html.
- PrivacyInfo.xcprivacy con 5 datatypes (Email, UserID, OtherFinancialInfo, PurchaseHistory, CrashData).
- Info.plist hardened: `ITSAppUsesNonExemptEncryption=false`, todos los permisos descriptos (mic, foto, cámara, biometría, speech), placeholders para RevenueCat y Sentry.
- App icon 1024×1024 ✓.
- Localización 100% en es-AR, en, pt-BR (668 keys).

**iOS — Asistente IA (post Sprint A 2026-05-13)**:
- 17 tools agentic (incluyendo `add_transaction`, `mark_bill_paid`, `compare_periods`, `get_financial_health_score`, `analyze_inflation_impact`).
- Vision multimodal real con Claude (build 5076 + UI definitiva 4512).
- Voice mode: STT Apple + Anthropic Haiku 4.5 + ElevenLabs Malena rioplatense + auto-VAD + streaming TTS con prefetch.
- **Memoria conversacional persistente** entre sesiones (Sprint A 2026-05-13).
- **Consent al primer uso** + toggle "Solo on-device" en Settings → "Privacidad del Asistente IA" (Sprint A).
- **Auto-refresh JWT** proactivo antes de cada request al asistente (Sprint A).
- Multi-hogar safety en el chat: re-hidrata si cambia el household.

**Apple Developer Program**:
- Enrolled + pagado + **aprobado** (confirmado por Ariel el 2026-05-13).
- Team ID activo: `K84H562MWX`.

**RevenueCat — código iOS**:
- `RevenueCatService.swift` 100% implementado (configure / login / logout / currentOffering / purchase / restore).
- `PaywallView.swift` completo con offering real + fallback placeholder.
- Falta solo: la API key en `Info.plist` (paso administrativo en RevenueCat dashboard, ver §1 abajo).

---

## 🎯 Lo que falta — acción humana de Ariel

Estos pasos requieren cuentas externas o dispositivos físicos. Yo no los puedo hacer.

### 1. App Store Connect — crear la app (30 min)
1. Login a https://appstoreconnect.apple.com con tu Apple ID.
2. My Apps → **+** → New App
3. Datos:
   - **Platforms**: iOS
   - **Name**: `Home Finance`
   - **Primary language**: Spanish (Argentina) o Spanish (Mexico)
   - **Bundle ID**: `com.metacasa.app` (debe coincidir con `metacasa-ios/project.yml`)
   - **SKU**: `metacasa-ios-001`
   - **User Access**: Full Access
4. **Agreements, Tax, and Banking**: completar Free + Paid Apps Agreement (sin esto Apple no procesa pagos).

### 2. App Store Connect — crear los IAPs (30 min)
My Apps → MetaCasa → **In-App Purchases** → +

**Premium Mensual**:
- Type: Auto-Renewable Subscription
- Product ID: `com.metacasa.premium.monthly`
- Subscription Group: `MetaCasa Premium`
- Price tier: Tier 4 (~$3.99 USD)
- Localizations: ES, EN, PT-BR
- 7-day free trial: habilitado

**Premium Anual**:
- Type: Auto-Renewable Subscription
- Product ID: `com.metacasa.premium.annual`
- Same Group: `MetaCasa Premium`
- Price tier: Tier 25 (~$24.99 USD)
- 7-day free trial: habilitado

### 3. App Store Connect API Key (10 min)
1. Users and Access → Keys → **In-App Purchase** → **+**
2. Name: `RevenueCat`
3. Descargar el `.p8` (solo se descarga una vez — guardalo seguro).
4. Anotar **Key ID** + **Issuer ID**.

### 4. RevenueCat — crear proyecto y conectar (45 min)
https://app.revenuecat.com → Create new project → "MetaCasa"

A. **App Settings** → iOS App → Apple App Store:
   - Bundle ID: `com.metacasa.app`
   - Subir el `.p8` del paso 3
   - Pegar Key ID + Issuer ID

B. **Products** → Import from App Store (auto-detecta los 2 IAPs creados)

C. **Entitlements** → + Create:
   - Identifier: `premium`
   - Attached products: ambos (monthly + annual)

D. **Offerings** → "default" → agregar packages para cada producto

E. **Webhooks** → + Add:
   - URL: `https://rgslvrxdppphzvqgcwbx.supabase.co/functions/v1/revenuecat-webhook`
   - Authorization: anotar el bearer secret que generes

F. **API Keys** → copiar la **iOS Public SDK Key** (empieza con `appl_`)

### 5. Pegar la API key en iOS (5 min)
Editar `metacasa-ios/MetaCasa/Supporting/Info.plist`:
```xml
<key>REVENUECAT_API_KEY</key>
<string>appl_TU_KEY_REAL_DE_REVENUECAT</string>
```

Después: `cd metacasa-ios && xcodegen generate` para actualizar el proyecto.

### 6. Webhook secret en Supabase (5 min)
https://supabase.com/dashboard/project/rgslvrxdppphzvqgcwbx/functions/secrets
- Name: `REVENUECAT_WEBHOOK_SECRET`
- Value: el bearer del paso 4.E

### 7. Screenshots — 5-7 por idioma × 3 idiomas (4-6h)
Apple exige mínimo **6.9" iPhone (1320×2868)** — los demás son legacy/opcionales.

Pantallas recomendadas a capturar (en device, iPhone Ariel iOS 18.4 o iPhone 17 Pro Max):
1. Home dashboard con datos reales (después de cargar 1-2 meses de tx).
2. Tab Movimientos con filtros activos.
3. Voice mode con orb en estado "speaking".
4. Tab Presupuesto con envelopes coloreados.
5. Asistente IA chat con respuesta de tool call (ej. health score).
6. Reportes / Health Score.
7. (Opcional) Plan Editor visual.

Truco: con la app abierta, **Side button + Volume up** = screenshot directo. Después transfer al Mac via AirDrop.

Para cada idioma (es-AR / en / pt-BR), cambiar el idioma de la app (Ajustes → Idioma) y volver a capturar.

### 8. Privacy Nutrition Label en ASC (30 min)
App Store Connect → MetaCasa → **App Privacy** → Get Started

Declarar exactamente lo que dice `PrivacyInfo.xcprivacy`:
- **Email Address** — Linked to identity, used for: App Functionality + Authentication. Not used for tracking.
- **User ID** — Linked to identity, used for: App Functionality. Not used for tracking.
- **Other Financial Info** — Linked to identity, used for: App Functionality. Not used for tracking. *(Importante: declarar — son las transacciones, presupuestos, metas.)*
- **Purchase History** — Linked to identity, used for: App Functionality. Not used for tracking. *(De RevenueCat / IAPs.)*
- **Crash Data** — NOT linked to identity, used for: App Functionality + Analytics. Not used for tracking.
- **Tracking**: NO.

### 9. Demo account para Apple Review (30 min)
Apple revisa la app con una cuenta tuya. Sin esto rechazan inmediato.

1. Crear cuenta nueva con email tuyo válido (ej. `review@metacasa.app` redirigido a tu email).
2. Cargar 3 meses de transacciones de ejemplo (al menos 30-50 tx para que se vea natural).
3. Crear 4 budgets, 2 goals, 1 invitación de hogar.
4. App Store Connect → **App Review Information**:
   - Sign-in Required: Yes
   - User name: el email de la cuenta demo
   - Password: una fuerte (no la real tuya)
   - Notes: copiar el texto de `APP_STORE_COPY.md` sección "App Review Information → Notes for reviewer"

### 10. Pegar copy de App Store (1h)
Todo el texto está en `APP_STORE_COPY.md`. Para cada idioma (es / en / pt-BR):
- Name + Subtitle + Promotional Text
- Description + Keywords
- What's New (para esta versión: novedades del Asistente IA con memoria)
- Support URL: `https://metacasa-app-cf592.web.app/`
- Privacy Policy URL: `https://metacasa-app-cf592.web.app/privacy.html`
- Terms URL: `https://metacasa-app-cf592.web.app/terms.html`
- Category: Finance / Productivity
- Age Rating: 4+

### 11. Stack trace del crash de mic (5 min cuando puedas)
En tu iPhone: Settings → Privacy & Security → Analytics & Improvements → Analytics Data → buscar `Home Finance-*.ips` recientes con "scenebuilder" o "crash" → Share → mandármelo.

### 12. TestFlight beta (1-2 semanas)
Xcode → Product → Archive (scheme MetaCasa, configuración Release).
- Distribute App → App Store Connect → Upload.
- Esperar 5-15 min hasta que aparezca en ASC.
- Internal Testing: tu email + 2-3 personas de confianza.
- External Testing: +30 emails amigos/familia (no requiere review de Apple).
- 1 semana mínimo de recolección de bugs.

### 13. Submit final
ASC → MetaCasa → App Store → **+** → seleccionar build de TestFlight → verificar todo → **Submit for Review**.

Apple tarda 24-72h. Common rejections para finance + AI:
- Privacy Policy URL inaccesible → ✓ ya está live.
- "Account creation required" → ✓ Sign-in Required declarado.
- "AI third-party disclosure missing" → ✓ AssistantConsentSheet implementado.
- Demo account no funciona → testealo vos antes de submit.

---

## 🛠️ Lo que falta — tareas técnicas que YO puedo hacer

Estas son las próximas mejoras opcionales pero importantes. Cualquiera la podemos arrancar diciéndolo:

### Sprint B (4-6h)
- **Streaming SSE de Anthropic** — el chat empieza a aparecer en 500ms en lugar de 3s. UX huge upgrade.
- **App Intents x5 nuevos** (Siri Shortcuts) — `ViewBudget`, `AddGoal`, `CheckGoal`, `PayBill`, `OpenAssistant`. De 2 a 7 intents totales.
- **Sentry SDK integración real** — sin esto los crashes en producción son ciegos.

### Sprint C (8-12h)
- **Validación CFDI 4.0 (México)** + **ARCA con CAE (Argentina)** — diferenciador LATAM crítico. Tool nueva del asistente + scan QR + API verificacfdi / WSAA-WSFEv1.
- **Liquid Glass material iOS 26** — chat bubbles + voice orb con `.glassEffect()` para wow factor en Apple Review.
- **Live Activity + Dynamic Island** durante voice mode.

### Sprint D (4-6h)
- **Tool result UI cards inline** — render transaction card animada cuando `add_transaction` ejecuta + botón Undo (5s).
- **3 tools más**: `transfer_between_accounts`, `set_budget_envelope`, `categorize_via_ai`.
- **Localización formal** de los strings hardcoded en es-AR (badge privacidad, sheet, AssistantPrivacyView).

---

## ⚡ Timeline realista

Asumiendo que arrancás los pasos administrativos esta semana:

| Día | Lo que pasa |
|---|---|
| **Hoy (2026-05-13)** | ✅ Apple Dev aprobado · ✅ Sprint A commit pushed (memoria + consent + auto-refresh + 2 tools nuevas) |
| **Mañana (14/may)** | Yo: Sprint B (streaming + Sentry + App Intents) · Vos: ASC create app + IAPs + RevenueCat |
| **15-17/may** | Vos: screenshots + demo account + Privacy Label · Yo: Sprint C si querés diferenciadores LATAM |
| **18-20/may** | TestFlight beta interno (5 personas) — bugs |
| **21-24/may** | Bug fixes + TestFlight beta externo (30 emails) |
| **25/may** | Submit a Apple Review |
| **26-28/may** | Apple revisa (24-72h) |
| **29-31/may** | Live en App Store 🚀 |

**Total realista: 2-3 semanas** desde hoy.

---

## 🆘 Si te trabás

- **No sabés cómo crear IAP en ASC**: https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/overview-for-in-app-purchases
- **No sabés cómo configurar RevenueCat**: video https://www.revenuecat.com/docs/getting-started/quickstart
- **El asistente se cae con 401 después de 1h**: ya está fixed con `ensureFreshToken` en Sprint A — si vuelve a pasar, avisame.
- **Apple rechazó algo**: pegame el mensaje exacto y lo respondo.

---

Última actualización: 2026-05-13 22:30 GMT-3 — Sprint A landed.
