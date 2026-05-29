# Política de Privacidad — Home Finance (borrador listo para publicar)

> **Para qué sirve:** Google Play **exige** una URL pública HTTPS con la política de privacidad para cualquier app que recolecte datos del usuario (y Home Finance recolecta email + datos financieros). Sin esto, la app **no se publica**.
>
> **Cómo usar este archivo:**
> 1. Este es el texto canónico (ES). Publicarlo en `https://metacasa-app-cf592.web.app/privacy.html`.
> 2. Ya existe `public/privacy.html` (versión iOS). **Hay que actualizarla** porque está escrita en lenguaje iOS-específico ("Keychain", "tu iPhone", "Apple Speech", "App Store / StoreKit"). Para Android hay que reflejar: **Android Keystore**, **Google Play Billing**, STT **on-device** (sin nombrar Apple). El texto de abajo ya está corregido para ser **multiplataforma (iOS + Android)**.
> 3. Idealmente ofrecer EN/PT también (mismo contenido traducido). Mínimo: ES + EN.
>
> **Controller de datos:** Home Finance (desarrollador: Ariel Vega). Contacto: ver §11.
> **Última actualización:** 2026-05-29.

---

## Texto de la política (canónico, multiplataforma)

### Home Finance — Política de Privacidad

Home Finance (en adelante, "la app") es una herramienta de gestión de finanzas personales del hogar, disponible para iOS y Android. Este documento describe qué datos recolectamos, cómo los usamos y los derechos que tenés sobre ellos. Aplica por igual a la versión de iOS y a la de Android (Google Play).

#### 1. Qué datos recolectamos
- **Datos de cuenta:** email y contraseña (hasheada con bcrypt) para autenticarte.
- **Datos financieros cargados por vos:** transacciones, cuentas, categorías, presupuestos, metas, deudas, cuotas, vencimientos y configuraciones. Son los datos que vos ingresás manualmente.
- **Datos del hogar:** nombre del hogar, miembros que invitás (por email), moneda base, zona horaria.
- **Datos de suscripción** (si usás Premium): identificador anónimo de RevenueCat + estado del entitlement (activo/expirado/trial). En Android la compra la procesa **Google Play Billing**; en iOS, el App Store. Nosotros nunca vemos tu medio de pago.
- **Datos técnicos mínimos:** identificador de dispositivo para la sesión + logs de error agregados (sin datos personales ni financieros específicos).
- **Datos del Asistente IA** (solo si lo usás, y solo después de aceptar el consentimiento explícito dentro de la app): tus mensajes de texto, las transcripciones de voz, un resumen de tu situación financiera (montos, categorías, saldos, metas) y las fotos de recibos que elijas escanear. Estos datos se envían a Anthropic y a ElevenLabs según se detalla en la sección 6. El audio de tu voz se transcribe **en tu propio dispositivo** y **NO se sube**; nunca enviamos emails, contraseñas ni números de tarjeta.

**NO recolectamos:** tu ubicación, tus contactos, tu galería de fotos (solo las imágenes de recibos que vos elijas enviar al asistente), historial de navegación, sensores del dispositivo, identificadores de publicidad, ni ningún otro dato que no sea esencial para la app. **No vendemos tus datos. No mostramos publicidad. No hacemos tracking.**

**Aclaración importante sobre tarjetas:** la app **no** almacena números de tarjeta de crédito/débito, CVV ni credenciales bancarias. Las "tarjetas" que podés crear guardan solo metadatos que vos definís (límite, día de cierre, día de vencimiento), nunca el número real.

#### 2. Dónde se guardan
- Tus datos financieros se guardan en **Supabase** (Postgres cifrado at-rest con AES-256, región us-east-1, EE.UU.). Las políticas de Row Level Security (RLS) garantizan que solo vos y los miembros de tu hogar pueden leerlos.
- Los tokens de sesión (JWT + refresh token) se guardan localmente en tu dispositivo de forma cifrada: en **Android** vía **Android Keystore** (a través de almacenamiento seguro del sistema), y en **iOS** vía Keychain. Quedan protegidos por el bloqueo de tu dispositivo y, si lo activás, por biometría.

#### 3. Quién ve tus datos
- Solamente vos, y los miembros de tu hogar que hayas invitado explícitamente por email.
- El desarrollador no tiene acceso al contenido de tus transacciones. Puede ver métricas agregadas y anonimizadas (por ejemplo, cantidad de usuarios activos) y logs de error sin datos personales.
- RevenueCat y Google Play Billing reciben solo un identificador de usuario y el estado de tu suscripción. **NUNCA** reciben tus datos financieros.

#### 4. Tus derechos (GDPR / CCPA / LFPDPPP / LGPD / Ley 25.326)
- **Acceso:** ver todos tus datos en la app, en cualquier momento.
- **Portabilidad / Export:** Ajustes → Datos → Backup. Genera un archivo descargable (JSON/CSV/PDF) con tu información.
- **Rectificación:** editar transacciones, cuentas, categorías y otros datos directamente en la app.
- **Eliminación:** Ajustes → (Cuenta/Avanzado) → **"Eliminar cuenta"** borra de forma permanente tu cuenta y todos tus datos. También podés eliminar un hogar individual desde Ajustes → Hogar → Eliminar hogar (irreversible, borra todo en cascada). El borrado se ejecuta dentro de la app, sin necesidad de mandar emails.
- **Restringir procesamiento:** podés no activar el asistente IA, o revocar el consentimiento desde Ajustes, para que ningún dato se envíe a Anthropic/ElevenLabs.
- **Retirar consentimiento:** podés cerrar tu cuenta o desactivar el asistente en cualquier momento.
- **Presentar quejas:** ante la autoridad de protección de datos de tu país.

#### 5. Seguridad
- **Cifrado en tránsito:** HTTPS + TLS obligatorio para toda comunicación.
- **Cifrado at-rest:** AES-256 en Postgres (Supabase). Tokens de sesión cifrados en Android Keystore / Keychain de iOS.
- **Row Level Security (RLS)** en el backend: tus datos no son accesibles por otros usuarios aunque conozcan tu identificador.
- **Biometría opcional** (huella / rostro) para abrir la app.
- Auditorías periódicas de seguridad.

#### 6. Terceros
Compartimos lo mínimo necesario con los siguientes proveedores, que actúan como procesadores de datos por instrucción nuestra:
- **Supabase** (base de datos Postgres + Edge Functions): backend principal. Política: https://supabase.com/privacy
- **RevenueCat** (gestión de suscripciones): solo identificador de usuario + estado de la suscripción. Política: https://www.revenuecat.com/privacy
- **Google Play Billing** (Android) / **Apple App Store** (iOS): procesan el pago de la suscripción. Nosotros no vemos tu medio de pago. Políticas: Google (https://policies.google.com/privacy) y Apple (https://www.apple.com/legal/privacy/).
- **Anthropic** (modelo de lenguaje Claude): solo si usás el asistente y aceptaste el consentimiento dentro de la app. Recibe el contenido de tus mensajes, las transcripciones de voz, un resumen de tu situación financiera y las fotos de recibos que elijas escanear, únicamente para responderte. Anthropic no entrena modelos de IA con tu data según su política. Detalle: https://www.anthropic.com/privacy
- **ElevenLabs** (síntesis de voz): solo si usás el modo voz. Recibe el **texto** de la respuesta del asistente para convertirlo a audio. ElevenLabs no entrena modelos de IA con tu data. Detalle: https://elevenlabs.io/privacy

El audio del asistente **no** se almacena en nuestros servidores. Las respuestas del modelo de IA tampoco se persisten del lado del servidor; solo el texto del intercambio queda guardado localmente en tu dispositivo, y se borra cuando eliminás tu cuenta.

#### 7. Menores
La app no está dirigida a menores de 13 años (COPPA) ni a menores de 16 años en jurisdicciones GDPR. No recolectamos conscientemente datos de menores. Si nos avisás que un menor cargó datos, los borramos.

#### 8. Retención de datos
Mantenemos tus datos mientras tu cuenta esté activa. Después de eliminar la cuenta, los backups de seguridad pueden retener datos hasta 90 días por razones técnicas; pasado ese plazo se eliminan permanentemente.

#### 9. Transferencias internacionales
Tus datos se procesan en EE.UU. (Supabase, región us-east-1). Si vivís en la Unión Europea / Reino Unido, esto constituye una transferencia internacional. Nos apoyamos en las Cláusulas Contractuales Tipo (Standard Contractual Clauses) de Supabase para legitimarla.

#### 10. Cambios
Podemos actualizar esta política. Los cambios se notificarán dentro de la app y en la versión publicada en la URL pública. El uso continuado implica aceptación.

#### 11. Contacto
Dudas o pedidos sobre privacidad: **vegaariel976@gmail.com** *(o el alias de soporte que definas — ver nota abajo).*

---

## Notas de implementación (NO van en el texto público)

1. **Email de contacto.** El iOS HTML usa `privacy@metacasa.app` y `metacasa.app`. **Esos dominios pueden no estar activos.** Decidir: (a) usar el email real del user `vegaariel976@gmail.com`, o (b) registrar `metacasa.app` y configurar `privacy@`/`support@`. **Acción del user — ver release-checklist.** El email en la ficha de Play y en la política DEBEN coincidir.

2. **URL pública.** El hosting es **Firebase Hosting** → `https://metacasa-app-cf592.web.app/`. La política vive en `/privacy.html` y los términos en `/terms.html`. Verificar que cargan por HTTPS antes de pegar la URL en Play.
   - ⚠️ **El consent sheet del código apunta a `https://metacasa.app/privacy`** (`consent_sheet.dart` línea 16), que **no coincide** con la URL real de Firebase. Hay que alinear: o se registra el dominio `metacasa.app` con un redirect, o se cambia la constante a la URL de `web.app`. **Blocker — ver checklist.**

3. **Naming.** La política dice "Home Finance" ✅. Pero el **consent sheet in-app dice "MetaCasa IA"** (`consent_sheet.dart` línea 116) → inconsistente con el nombre de tienda. Alinear a "Home Finance" para no repetir el rechazo 2.3.8 que ya pasó en iOS. **Blocker — ver checklist.**

4. **Diferencias iOS→Android ya aplicadas en este texto:** Keychain → "Android Keystore / Keychain de iOS"; "tu iPhone" → "tu dispositivo"; "Apple Speech" → "en tu propio dispositivo"; "App Store/StoreKit" → "Google Play Billing / App Store". Si publicás una sola política multiplataforma (recomendado), usá este texto. Si querés una página Android-only, quitá las menciones a iOS.

5. **Terms of Service.** Existe `public/terms.html`. Revisar que también diga "Home Finance" y que mencione la suscripción vía Google Play. No es estrictamente obligatorio para Play, pero sí recomendable y ya está enlazado desde la política.
