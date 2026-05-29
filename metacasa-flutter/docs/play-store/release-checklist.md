# Release Checklist — Google Play · Home Finance (Android / Flutter)

> Paso a paso para publicar **Home Finance** en Google Play. App: `com.metacasa.app`.
> Port Android del iOS ya publicado (v1.0.2). Leyenda:
> - 🔑 = **necesita credenciales o una decisión del user** (no se puede hacer sin él).
> - 🤖 = lo puede dejar listo Claude / automatizable.
> - ⚠️ = depende de resolver un blocker (ver sección final).
>
> Esta lista asume que la app **ya compila** (verificado: `flutter build apk --debug` ✓). Lo que falta es: monetización, firma de release, assets de tienda y el papeleo de compliance que cubren los otros archivos de esta carpeta.

---

## 0. Pre-requisitos de cuenta (una sola vez)

- [ ] 🔑 **Cuenta de Google Play Developer** activa (pago único USD 25). Si ya existe la del iOS no sirve — Play es de Google. Confirmar que el user la tiene o crearla.
- [ ] 🔑 Aceptar el **Developer Distribution Agreement** y completar el perfil de cuenta (tipo: individual u organización; **datos fiscales y de identidad** — Google los verifica para apps nuevas).
- [ ] 🔑 Si la cuenta es nueva (creada después de nov-2023): Google exige **closed testing con ≥12 testers durante ≥14 días** antes de poder publicar a producción. **Planificar esto con tiempo** (ver §10).

---

## 1. Crear la app en Play Console

- [ ] 🔑 Play Console → **Crear app**.
  - Nombre de la app: **Home Finance** (debe coincidir con iOS).
  - Idioma predeterminado: **Inglés (en-US)** (core global). ES y PT se agregan como traducciones.
  - Tipo: **App** (no juego).
  - Gratis o de pago: **Gratis** (la monetización es por suscripción in-app, así que la app se publica como gratuita).
  - Declaraciones: confirmar cumplimiento de políticas y leyes de exportación de EE.UU.

---

## 2. Ficha de Play Store en 3 idiomas (Store listing)

> Copiar de los archivos `listing-en.md`, `listing-es.md`, `listing-pt.md` de esta carpeta.

- [ ] 🤖 **Listing principal en-US:** título, descripción corta, descripción completa (de `listing-en.md`).
- [ ] 🤖 Agregar traducción **es-419** (de `listing-es.md`).
- [ ] 🤖 Agregar traducción **pt-BR** (de `listing-pt.md`).
- [ ] 🔑⚠️ **Assets gráficos** (hay que producirlos — no existen aún para Android):
  - [ ] **Ícono de la app:** 512×512 PNG, 32-bit. (Reusar el `ic_launcher` adaptativo del proyecto, exportado a 512.)
  - [ ] **Gráfico destacado (Feature graphic):** 1024×500 PNG/JPG. **Obligatorio.**
  - [ ] **Screenshots de teléfono:** mín. 2, recomendado 4–8. 16:9 o 9:16, lado mínimo 320px, máximo 3840px. Usar las capturas reales de la app con los captions de los `listing-*.md`. (El emulador `metacasa` AVD sirve para capturarlas; o adaptar las del iOS reescalando.)
  - [ ] (Opcional) Screenshots de **tablet 7"/10"** si se declara soporte tablet.
  - [ ] (Opcional pero alto impacto) **Video de YouTube** demo.
- [ ] 🤖 Categoría: **Finanzas**. Tags: presupuesto / finanzas personales / ahorro.
- [ ] 🔑 **Email de contacto** y **sitio web** (`https://metacasa-app-cf592.web.app/`). Ver blocker del email.

---

## 3. Build: AAB firmado de release

> Play exige **Android App Bundle (.aab)**, no APK. Y **firmado con una clave de release**, no debug.

- [ ] ⚠️🔑 **Crear keystore de subida (upload key).** Hoy `android/app/build.gradle` firma release con la **debug key** (línea 39) → **Play lo rechaza**. Pasos:
  ```
  keytool -genkey -v -keystore ~/home-finance-upload.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
  - 🔑 El user define y **guarda** la contraseña del keystore (NO va al repo ni al chat).
  - Crear `android/key.properties` (gitignoreado) con `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
  - Editar `android/app/build.gradle`: leer `key.properties` y usar ese `signingConfig` en `buildTypes.release` (reemplazar `signingConfigs.debug`).
- [ ] 🤖 **Activar Play App Signing** al subir el primer bundle (Google gestiona la clave de firma final; vos subís con la upload key). Recomendado.
- [ ] 🤖 (Recomendado) Activar **R8 / minify + shrink** en release (`isMinifyEnabled = true`, `isShrinkResources = true`) — la skill de readiness lo pide para ofuscación. Verificar que no rompa reflection de Supabase/freezed; testear el AAB release antes de subir.
- [ ] 🤖 Bump de versión: `pubspec.yaml` está en `1.0.0+1`. El `+1` es el **versionCode** (debe ser único y creciente en cada subida). Subir `versionName`/`versionCode` según corresponda.
- [ ] 🔑 **Build del AAB** (necesita **JDK 17** instalado — hoy Java no está instalado, según notas del proyecto):
  ```
  flutter build appbundle --release --dart-define-from-file=env.json
  ```
  - ⚠️ Build aislado (matar procesos Flutter/Gradle previos; iCloud puede lockear `build/` — ver gotchas del proyecto).
- [ ] 🤖 Verificar el AAB: `bundletool` o subirlo al track interno y revisar warnings.

---

## 4. Monetización (in-app products) — Fase 5, INCOMPLETA

> ⚠️ **Bloqueante para la propuesta de valor:** el código Flutter **todavía NO integra RevenueCat / Play Billing** (`purchases_flutter` no está en `pubspec.yaml`). La app tiene el modelo `UserEntitlement` (lectura) pero **no hay paywall ni compra**. Sin esto, o se publica sin Premium, o se completa Fase 5 antes.

- [ ] 🔑⚠️ Decidir: ¿publicar v1 **sin** monetización (toda la app gratis) o completar Fase 5 primero? (Recomendado para un primer release de testing: completar Fase 5, ya que iOS tiene gate duro de trial.)
- [ ] 🔑 Crear la **cuenta/Project de RevenueCat para Android** + API key de Play (`goog_...`). (iOS usa `appl_mJefXoJQLCqrPEtqgXKSlacJUkW`; Android necesita la suya.)
- [ ] 🔑 En Play Console → **Monetización → Productos → Suscripciones**: crear `com.metacasa.premium.monthly` y `com.metacasa.premium.annual` (mismos IDs que iOS para consistencia). Definir precios — el user mencionó querer $6.99/$49.99 (vs los $4.99/$39.99 viejos de iOS).
- [ ] 🔑 Configurar **trial de 7 días** en cada suscripción (oferta introductoria).
- [ ] 🔑 Vincular Play ↔ RevenueCat (subir la **service account JSON** de Google Play a RevenueCat para validación server-side).
- [ ] 🤖 Conectar el **webhook RevenueCat → Supabase** (escribe `user_entitlements`). El backend ya tiene el enum `play_store` listo (IOS_AUDIT.md §0).
- [ ] 🤖 Implementar las 2 paywalls (trial + locked) en Flutter y el `Restore purchases`.

---

## 5. Data Safety (Seguridad de los datos)

> Completar con `data-safety.md` de esta carpeta.

- [ ] 🤖 Declarar datos recolectados: **email, nombre (opc.), ID de usuario, datos financieros del usuario, contenido de IA (mensajes + fotos de recibos, opcional)**.
- [ ] 🤖 Marcar **cifrado en tránsito = Sí**.
- [ ] 🤖 Marcar **el usuario puede pedir borrado = Sí** + cargar la **URL de borrado** (ver blocker).
- [ ] 🤖 **Analytics = No** (verificado: no hay SDK de analytics/crashlytics en `pubspec.yaml`).
- [ ] 🤖 **Info de pago / nº de tarjeta = No recopilado** (la app no toca PANs; Play Billing cobra).
- [ ] 🤖 **Audio = NO marcar como recopilado** (STT on-device; solo se sube el transcript). Pero declarar el permiso `RECORD_AUDIO` en §7.

---

## 6. Content rating (IARC)

> Completar con `content-rating.md`.

- [ ] 🤖 Iniciar cuestionario, categoría **"Todas las demás categorías de apps"** (no juego).
- [ ] 🤖 Responder: sin violencia/sexo/drogas/gambling. **Sí** a "interacción entre usuarios" (hogar multi-usuario, sin chat público) y **Sí** a "compras digitales".
- [ ] 🤖 Enviar → rating esperado **Para todos / Everyone**.

---

## 7. App content (declaraciones obligatorias del Play Console)

- [ ] 🔑 **Política de privacidad (URL):** pegar `https://metacasa-app-cf592.web.app/privacy.html` (ver blocker de URL + naming). Texto canónico en `privacy-policy.md`.
- [ ] 🔑 **Público objetivo y contenido:** marcar **18+** (recomendado) o 13+; **NO** incluir menores de 13 → evita Families Policy. (Ver `content-rating.md`.)
- [ ] 🤖 **Anuncios:** declarar **"No, la app no contiene anuncios"** (verificado: sin SDK de ads).
- [ ] 🤖 **App de noticias:** No. **App de gobierno:** No. **COVID/contact tracing:** No.
- [ ] ⚠️🔑 **Declaración de permisos sensibles** (Play los cuestiona en review — hay que justificar **cada uno** en el formulario *"Permissions declaration"* o en las notas):
  - [ ] **`RECORD_AUDIO`** → *"Comandos de voz del asistente financiero. El reconocimiento de voz es on-device; el audio crudo no se sube a ningún servidor."*
  - [ ] **`CAMERA`** → *"Escaneo de recibos: el usuario fotografía un recibo y la app extrae los datos del gasto. Uso explícito iniciado por el usuario."*
  - [ ] **`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`** → ⚠️ **Play restringe esto fuertemente** (desde Android 13). Solo se permite para alarmas/calendarios/recordatorios genuinos. Justificación: *"Recordatorios de vencimientos de cuentas en fecha/hora exacta elegida por el usuario."* **Considerar alternativa:** si no se necesita exactitud al minuto, migrar a `setInexactRepeating` / WorkManager y **quitar el permiso** → evita el formulario de excepción. **Decisión del user.**
  - [ ] **`RECEIVE_BOOT_COMPLETED`** → re-programar notificaciones tras reinicio (estándar, bajo escrutinio).
  - [ ] **`POST_NOTIFICATIONS`** → recordatorios (runtime permission Android 13+, OK).
  - [ ] **`USE_BIOMETRIC` / `USE_FINGERPRINT`** → bloqueo biométrico de la app (OK, no requiere declaración especial).

---

## 8. Naming / branding consistency (pre-submit)

> Apple ya rechazó iOS por esto (2.3.8). Play también compara el nombre de tienda con lo que ve el usuario.

- [ ] ⚠️🤖 **`android:label`** en `AndroidManifest.xml` dice **`"metacasa"`** → cambiar a **`"Home Finance"`** (label del launcher en el teléfono).
- [ ] ⚠️🤖 **Consent sheet** (`consent_sheet.dart`) dice **"MetaCasa IA"** → cambiar a "Home Finance" o "Asistente de Home Finance".
- [ ] ⚠️🤖 **URL de privacidad** en `consent_sheet.dart` (`https://metacasa.app/privacy`) → alinear con la URL real (`...web.app/privacy.html`) o registrar el dominio.
- [ ] 🤖 `grep -ri "metacasa" lib/` y revisar cualquier string **user-facing** (no los `applicationId`/`namespace`/comentarios, que pueden quedar). Igual que el auto-grep que se hace en iOS antes de cada submit.

---

## 9. Cuenta demo para el revisor de Google

- [ ] 🔑 Play Console → **App access** → declarar que la app requiere login y dar credenciales de prueba. Reusar/crear una cuenta demo en Supabase (iOS usó `vegaariel976+appreview@gmail.com`; el Android initiative ya sembró `demo@homefinance.app` / `Demo1234!` con datos — confirmar que sigue viva o resembrar).
- [ ] 🔑 Notas para el revisor: explicar el **trial duro de 7 días** (si Fase 5 está activa) y que el asistente IA requiere aceptar un consentimiento.

---

## 10. Testing tracks → Producción

- [ ] 🤖 Subir el primer AAB al track **Internal testing** (rápido, hasta 100 testers, sin review largo). Smoke-test en device real.
- [ ] 🔑⚠️ **Closed testing** (obligatorio para cuentas nuevas: ≥12 testers / ≥14 días). Crear lista de testers (emails) y compartir el opt-in link.
- [ ] 🤖 (Opcional) **Open testing** (beta pública) para más feedback.
- [ ] 🔑 **Promover a Producción:** elegir rollout (sugerido **staged rollout** 20% → 100%). Países: US + global + LatAm (AR/MX/BR como foco). Confirmar precios de suscripción por país.
- [ ] 🤖 Tras aprobación: monitorear **Android vitals** (crashes/ANRs) y reviews.

---

## ⚠️ Blockers a resolver antes de subir

> Detectados leyendo el código. Ordenados por severidad. **Los 1–3 son hard-stop** (Play rechaza o la app queda inconsistente); 4–6 son funcionales/de propuesta de valor; 7–8 son de papeleo que hay que producir.

### 🔴 1. Release firmado con la DEBUG key
`android/app/build.gradle` línea 39: `signingConfig = signingConfigs.debug` en el `release` buildType. **Un AAB firmado con la debug key es rechazado por Play.** → Crear upload keystore + `key.properties` + signingConfig de release (ver §3). **Hard-stop.**

### 🔴 2. `android:label="metacasa"` ≠ nombre de tienda "Home Finance"
`AndroidManifest.xml` línea 20. El nombre que ve el usuario en el launcher del teléfono dice "metacasa", pero la ficha de Play (y el iOS publicado) dicen **"Home Finance"**. Apple ya rechazó iOS por exactamente esto (Guideline 2.3.8). → Cambiar `android:label` a `"Home Finance"`. **Hard-stop de consistencia.**

### 🔴 3. Monetización (RevenueCat/Play Billing) NO integrada
`purchases_flutter` no está en `pubspec.yaml`; no hay paywall ni flujo de compra (Fase 5 pendiente, confirmado en la memoria del proyecto). La app iOS tiene **gate duro de trial 7 días** → si Android se publica sin esto, o no monetiza, o queda en paridad rota. → Decidir: completar Fase 5 (recomendado) o publicar v1 gratis. **Necesita cuenta RevenueCat del user + crear productos en Play.**

### 🟠 4. URL de privacidad inconsistente entre código y hosting real
`consent_sheet.dart` línea 16 apunta a `https://metacasa.app/privacy`, pero la política real está en **Firebase** (`https://metacasa-app-cf592.web.app/privacy.html`). El dominio `metacasa.app` puede no existir. → Registrar `metacasa.app` (con redirect) **o** cambiar la constante a la URL de `web.app`. La URL en la ficha de Play y en la app deben coincidir y cargar por HTTPS.

### 🟠 5. Email/dominio de contacto sin confirmar
`privacy.html` usa `privacy@metacasa.app` (dominio posiblemente inexistente). La ficha de Play, la política y el soporte in-app deben usar un email **que funcione**. → Decisión del user: usar `vegaariel976@gmail.com` o activar `metacasa.app`.

### 🟠 6. `SCHEDULE_EXACT_ALARM` bajo escrutinio de Play
Permiso restringido desde Android 13 (`AndroidManifest.xml` líneas 15–16). Play pide justificación o puede rechazar si no es esencial. → Justificar como "recordatorios de vencimientos en hora exacta" **o** migrar a alarmas inexactas/WorkManager y quitar el permiso. **Decisión del user.**

### 🟡 7. Falta la URL pública de "solicitar borrado de cuenta"
Google pide, además del borrado in-app (que ✅ existe vía `delete-account`), una **URL de solicitud de borrado** en la ficha. No hay una landing dedicada (`delete-account.html`). → Crear una página simple en Firebase que explique cómo borrar (o un endpoint), y/o apuntar a la sección de borrado de `privacy.html`.

### 🟡 8. Assets de tienda Android inexistentes
No hay feature graphic 1024×500 (obligatorio) ni screenshots Android. → Producir: ícono 512², feature graphic, 4–8 screenshots (capturables del AVD `metacasa` o reescalando los del iOS) con los captions de los `listing-*.md`.

### 🟢 Notas menores (no bloquean)
- `namespace = "com.metacasa.metacasa"` en build.gradle (línea 9) — cosmético, no afecta el `applicationId` (`com.metacasa.app` ✅, correcto).
- R8/minify no activado — recomendado por la skill de readiness pero no obligatorio para publicar.
- `terms.html` ya dice "Home Finance" (9 menciones) — OK; tiene 1 mención residual de "metacasa" que conviene revisar.
