# Data Safety form — Google Play Console · Home Finance

> Sección **Política de la app → Seguridad de los datos** del Play Console.
> Cada respuesta acá está **derivada del código real**: permisos de `AndroidManifest.xml`,
> modelos de `lib/models/`, edge clients de `lib/data/edge/` y el flujo de IA
> (`lib/features/assistant/`). Donde Play pide un sí/no, está marcado.
>
> **Fuentes de verdad:**
> - Permisos: `android/app/src/main/AndroidManifest.xml`
> - Datos guardados: `lib/models/*.dart` (transactions, accounts, households, goals, etc.)
> - Auth + datos en backend: Supabase (Postgres us-east-1, RLS).
> - Borrado: edge function `delete-account` (`lib/data/edge/account_deletion_client.dart`).
> - IA: consentimiento explícito en `lib/features/assistant/presentation/consent_sheet.dart`.

---

## 0. Preguntas de encabezado (overview)

| Pregunta de Google | Respuesta | Justificación |
|---|---|---|
| ¿Tu app recopila o comparte alguno de los tipos de datos del usuario requeridos? | **Sí** | Email para auth + datos financieros que el usuario ingresa + (opcional) audio/fotos para el asistente. |
| ¿Todos los datos del usuario están **cifrados en tránsito**? | **Sí** | Todo el tráfico va por HTTPS/TLS a Supabase y a los proxies de IA. La app solo declara `INTERNET`; no hay endpoints en texto plano. |
| ¿Ofrecés una forma de que los usuarios **soliciten la eliminación** de sus datos? | **Sí** | Borrado in-app: Ajustes → eliminar cuenta (edge function `delete-account` → `auth.admin.deleteUser`, borra/anonimiza datos en cascada). URL de borrado: ver §4. |

> **Nota sobre "cifrado en tránsito":** confirmar que NINGUNA librería haga llamadas HTTP sin TLS. Las dependencias (`supabase_flutter`, `http`, `just_audio` para el MP3 del TTS) usan HTTPS. ✅

---

## 1. Tipos de datos recopilados

Para **cada** tipo: Google pregunta (a) ¿se recopila?, (b) ¿se comparte con terceros?, (c) ¿es obligatorio u opcional?, (d) propósito(s), (e) ¿está vinculado a la identidad del usuario?.

> **Definición de "compartir" (Google):** transferir a un **tercero separado**. Supabase (nuestro backend/procesador), Anthropic, ElevenLabs y RevenueCat son procesadores que actúan por instrucción nuestra → en Data Safety **se declaran como recopilación**, y para los providers de IA/voz marcamos también "compartido" porque el dato sale a una empresa distinta. **Ningún dato se vende ni se usa para publicidad.**

### A. Información personal

| Dato | ¿Recopilado? | ¿Compartido? | Obligatorio/Opcional | Propósitos | ¿Vinculado al usuario? |
|---|---|---|---|---|---|
| **Direcciones de correo electrónico** | Sí | No | Obligatorio | Gestión de la cuenta (login/auth); invitar miembros al hogar por email | Sí |
| **Nombre** (display name del miembro del hogar) | Sí (opcional, lo pone el usuario) | No | Opcional | Funcionalidad de la app (mostrar quién es quién en el hogar) | Sí |
| **Otra info (IDs de usuario)** | Sí (UUID de Supabase Auth) | Sí (a RevenueCat, hasheado, para suscripción) | Obligatorio | Gestión de la cuenta; funcionalidad de la app | Sí |

> Fuente: `HouseholdMember.displayName`, `HouseholdInvitation.email` (`lib/models/household.dart`); auth de Supabase.

### B. Información financiera

> Google define esta categoría como **"Información financiera del usuario"**. Subtipos relevantes:

| Dato | ¿Recopilado? | ¿Compartido? | Obligatorio/Opcional | Propósitos | ¿Vinculado al usuario? |
|---|---|---|---|---|---|
| **Otra info financiera** (transacciones, presupuestos, cuentas, saldos iniciales, metas, deudas, cuotas, vencimientos, montos, categorías, notas que escribe el usuario) | Sí | Sí — solo un **resumen** se envía a Anthropic **si** el usuario activa el asistente de IA y dio consentimiento. | El registro es opcional (el usuario decide qué carga); la app es para esto. | Funcionalidad de la app (núcleo: presupuesto/gastos/metas) | Sí |

> **Importante:** la app **NO** maneja **números de tarjeta de crédito/débito (PAN), CVV ni credenciales bancarias**. Las "tarjetas" del modelo (`credit_cards`) guardan solo metadatos definidos por el usuario (límite, día de cierre, día de vencimiento, red Visa/Mastercard) — **no** el número real. Marcar **"Info de pago" = NO recopilado**. Fuente: modelo `CreditCardDetails` en IOS_AUDIT.md §1; no hay campo de PAN en `lib/models/`.
> **No hay payment processing in-app de tarjetas:** las suscripciones las cobra **Google Play Billing**; Home Finance nunca ve la tarjeta del usuario.

### C. Mensajes / Contenido del usuario (IA — solo si se usa)

| Dato | ¿Recopilado? | ¿Compartido? | Obligatorio/Opcional | Propósitos | ¿Vinculado al usuario? |
|---|---|---|---|---|---|
| **Otro contenido generado por el usuario** — texto de los mensajes al asistente | Sí (solo si usa la IA) | **Sí — a Anthropic** | Opcional (feature opt-in con consentimiento) | Funcionalidad de la app (responder al usuario) | Sí |
| **Fotos** — imágenes de recibos que el usuario elige escanear | Sí (solo si escanea) | **Sí — a Anthropic** (visión) | Opcional | Funcionalidad de la app (extraer datos del recibo) | Sí |

> Fuente: `consent_sheet.dart` ("Tus mensajes y un resumen de tus finanzas… fotos de recibos"); `ai_proxy_client.dart`; IOS_AUDIT.md §7.

### D. Audio

| Dato | ¿Recopilado? | ¿Compartido? | Obligatorio/Opcional | Propósitos | ¿Vinculado al usuario? |
|---|---|---|---|---|---|
| **Grabaciones de voz / audio del usuario** | **Se procesa, NO se sube** | **No** (el audio crudo nunca sale del dispositivo) | Opcional (solo modo voz) | Funcionalidad de la app (comandos de voz) | N/A |

> ⚠️ **Matiz que hay que declarar bien.** El permiso `RECORD_AUDIO` está en el manifest (línea 9) por el modo voz (`speech_to_text`). El STT es **on-device**: solo el **texto transcripto** se manda al asistente, no el audio. Por eso **NO se marca "Grabaciones de audio" como recopiladas/compartidas**, pero **SÍ** hay que poder justificarlo en la declaración de permisos sensibles (ver `release-checklist.md`).
> El TTS (ElevenLabs, voz **de salida**) recibe **texto** de la respuesta, no audio del usuario.

### E. Datos NO recopilados (marcar explícitamente "No" si Play los lista)

| Categoría | Estado |
|---|---|
| Ubicación (aprox. o precisa) | **No** — sin permisos de location |
| Contactos | **No** — sin permiso `READ_CONTACTS` |
| Calendario | **No** |
| Fotos/videos en general (galería completa) | **No** — solo la foto puntual de un recibo que el usuario elige (Photo Picker, sin permiso de almacenamiento) |
| Historial de navegación / búsqueda web | **No** |
| Apps instaladas | **No** |
| SMS / llamadas | **No** |
| Salud y fitness | **No** |
| Identificadores de publicidad (AAID) | **No** — la app no tiene ads ni tracking |

---

## 2. Propósitos de recopilación (mapeo Google)

Google ofrece una lista cerrada de propósitos. Los aplicables a Home Finance:

| Propósito de Google | ¿Aplica? | Para qué datos |
|---|---|---|
| Funcionalidad de la app | **Sí** | Datos financieros, email, contenido de IA, audio |
| Gestión de la cuenta | **Sí** | Email, ID de usuario |
| Analíticas | **Sí (mínimo)** | Solo logs de error agregados, sin datos personales/financieros (ver nota) |
| Comunicaciones del desarrollador | No | — |
| Publicidad o marketing | **No** | — |
| Personalización | **No** | — |
| Prevención de fraude / seguridad / cumplimiento | **Sí** | ID de usuario / sesión (auth) |

> **Analíticas:** declarar solo si hay un SDK de telemetría activo. La PWA/iOS tienen `SENTRY_DSN` vacío. **Verificar en el código Flutter** que no haya analytics/crashlytics activo antes de marcar "Analíticas". Si no hay ningún SDK, marcar **No**. (Acción en checklist.)

---

## 3. Prácticas de seguridad (sección "Security practices")

| Pregunta de Google | Respuesta | Justificación |
|---|---|---|
| ¿Los datos están cifrados en tránsito? | **Sí** | HTTPS/TLS a Supabase + proxies. |
| ¿Los usuarios pueden pedir que se eliminen sus datos? | **Sí** | Borrado in-app (edge function `delete-account`). |
| ¿Te comprometés con la política de Familias de Google Play? | **No aplica** (la app no está dirigida a niños; ver content-rating.md / target audience 18+ o 13+) | — |
| ¿La app fue revisada contra un estándar de seguridad global (ej. MASVS)? | **Opcional — Sí si querés** | El proyecto sigue MASVS/OWASP Mobile (CLAUDE.md). Podés marcar "Independent security review" solo si tenés un reporte; si no, dejarlo sin marcar. |

---

## 4. Eliminación de datos (campo obligatorio si "Sí" en borrado)

- **Mecanismo in-app:** Ajustes → (sección Avanzado/Cuenta) → **Eliminar cuenta**. Doble confirmación, borra cuenta + datos en cascada server-side. Implementado en `delete_account_screen.dart` + `account_deletion_client.dart` → edge function `delete-account`.
- **URL de solicitud de borrado de cuenta** (Google la pide aparte del flujo in-app — campo *"Account deletion request URL"* en la ficha):
  - **Recomendado publicar:** `https://metacasa-app-cf592.web.app/delete-account.html` (o `/privacy.html#borrado` apuntando a la sección de borrado).
  - ⚠️ **Esta URL hay que crearla/publicarla.** Hoy existe `privacy.html` con la sección de eliminación pero no una landing dedicada de "solicitar borrado". Ver blocker en `release-checklist.md`.
- **Qué se borra:** cuenta de auth, transacciones, cuentas, presupuestos, metas, deudas, cuotas, vencimientos, membresías de hogar (FKs en SET NULL para preservar historial de hogares compartidos de otros miembros). Conversaciones de IA guardadas localmente se borran con la cuenta.
- **Retención post-borrado:** backups técnicos hasta 90 días, luego eliminación permanente (alinear con privacy-policy.md §8).

---

## 5. Resumen para copiar al "Data safety" (vista que ve el usuario en Play)

**Datos que la app recopila:**
- Información personal: direcciones de email, nombre (opcional), IDs de usuario.
- Información financiera: datos financieros del usuario (transacciones, presupuestos, saldos, metas) — **ingresados por el usuario, no datos de tarjetas/banco**.
- Contenido del usuario: mensajes al asistente y fotos de recibos (solo si usa la IA, con consentimiento).

**Datos que la app comparte (con procesadores, nunca vendidos):**
- Resumen financiero, mensajes y fotos de recibos → **Anthropic** (asistente IA), solo con consentimiento.
- ID de usuario hasheado + estado de suscripción → **RevenueCat / Google Play Billing**.

**Prácticas de seguridad:**
- Cifrado en tránsito. ✅
- El usuario puede pedir el borrado de sus datos. ✅
- No se venden datos. No hay publicidad. No hay tracking. ✅
