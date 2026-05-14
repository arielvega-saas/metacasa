# Disclosure del Asistente IA — MetaCasa

**Última actualización**: 2026-05-13

Este documento describe cómo funciona el Asistente IA de MetaCasa, qué datos procesa, dónde, y bajo qué bases legales. Es required reading para App Store Review (Guideline 5.1.1 + AI/ML transparency) y referencia para el usuario.

URL pública (al deploy): https://metacasa-app-cf592.web.app/assistant-ai.html

---

## ¿Qué es el Asistente IA?

Un coach financiero conversacional embebido en MetaCasa. Tres modos:

- **Chat de texto** — respuestas en lenguaje natural sobre tus finanzas.
- **Voz** — Apple Speech (STT on-device) + Anthropic Claude Haiku 4.5 (cloud) + ElevenLabs Malena (TTS streaming).
- **Vision multimodal** — escaneo de recibos con Apple Vision (OCR on-device) + Claude vision (parsing estructurado opcional).

20+ acciones agentic disponibles: cargar transacciones, marcar facturas pagadas, transferir entre cuentas, asignar presupuestos, comparar meses, proyectar balance, validar facturas electrónicas CFDI (México) y ARCA (Argentina), etc.

---

## Privacidad por capa — qué se procesa dónde

### 100% on-device (nunca sale del iPhone)

- Reconocimiento de voz (Apple Speech framework).
- OCR de recibos (Apple Vision framework).
- Statistical fallback (cuando elegís "Solo on-device").
- Persistencia de tu historial de chat (JSON encriptado con `completeFileProtection`).
- Categorización heurística (`categorize_transaction`).

### En la nube (solo con tu consentimiento explícito)

Cuando aceptás el sheet de consentimiento al primer uso, las siguientes piezas se procesan en la nube vía proxies seguros:

**Anthropic Claude Haiku 4.5** (LLM principal):
- Lo que se envía: tu pregunta + un resumen JSON compacto de tu estado financiero (montos, categorías, fechas, IDs internos).
- Lo que NO se envía: tu email, contraseña, tarjetas de crédito, datos biométricos, ubicación.
- Procesamiento: vía nuestro Edge Function `ai-proxy` (Supabase) que valida tu JWT antes de forwardear. La API key de Anthropic nunca se expone al cliente.
- Política de Anthropic: **NO entrenan modelos con consultas de API**. Logs de la API se retienen 30 días para detección de abuso y se eliminan después.

**ElevenLabs** (TTS — solo voice mode):
- Lo que se envía: el texto de la respuesta del asistente para ser convertido a audio.
- Lo que NO se envía: tu identidad personal.
- Voz: Malena rioplatense (voice_id `p7AwDmKvTdoHTBuueGvP`).

### Datos persistidos

- **Chat sessions**: guardados en `Documents/chat-sessions/{householdId}/` con `completeFileProtection`. Encriptados a nivel sistema cuando el iPhone está bloqueado.
- **Resúmenes de sesiones**: generados por Claude Haiku al cerrar el chat. Sirven para memoria entre sesiones. También locales.
- **Backups**: si exportás JSON, vos controlás dónde lo guardás.

---

## Control del usuario

Podés gestionar todo desde **Ajustes → Avanzado → Privacidad del Asistente IA**:

1. **Toggle "Procesamiento en la nube"** — alterna el consentimiento global. Si está OFF, el asistente solo usa modos on-device o el fallback estadístico.
2. **Toggle "Forzar solo on-device"** — incluso con consent ON, podés forzar que esa sesión no use cloud. Más lento, pero garantizado privado.
3. **Botón "Revocar consentimiento y borrar historial"** — revoca consent + elimina todos los chat sessions y resúmenes persistidos del hogar activo.

Estos controles son **inmediatos y persistentes**. La próxima vez que abras el chat, te pedimos consent de nuevo.

---

## Base legal

- **Consentimiento explícito**: requerido por GDPR (UE), LGPD (Brasil), LFPDPPP (México), Habeas Data (Argentina). El sheet de consent al primer uso es la base legal primaria.
- **Interés legítimo**: para detección de abuso y observabilidad básica (Sentry — captura solo stack traces, no datos personales identificables).
- **Cumplimiento contractual**: Anthropic y ElevenLabs operan bajo DPAs (Data Processing Agreements) que requieren cumplir las regulaciones de tu jurisdicción.

---

## Lo que el asistente NO hace

- ❌ No usa tu data para entrenar modelos (Anthropic NO entrena con consultas API).
- ❌ No vende ni comparte tu información con terceros para publicidad.
- ❌ No accede a tus cuentas bancarias reales — solo procesa lo que vos cargás manualmente o importás.
- ❌ No ejecuta transferencias bancarias reales fuera de la app. Las "transferencias" son anotaciones contables entre cuentas internas de tu hogar.
- ❌ No da consejos de inversión específicos ("comprá Bitcoin", "vendé tales acciones"). Solo asesoría general (asset allocation, emergency fund, debt strategies).
- ❌ No invierte por vos.

---

## ¿Qué pasa si rechazás el consent?

Podés seguir usando MetaCasa al 100%. El asistente cae al **Tier 3 statistical fallback** (motor determinístico local) que responde preguntas simples sobre tus datos sin LLM. Las funciones nativas de la app (cargar transacciones, presupuesto, metas, reportes, etc.) no se afectan.

---

## Cambios

Si actualizamos los modelos, proveedores o políticas, te lo notificamos in-app y te pedimos consent de nuevo. La versión actual de los proveedores:

| Servicio | Proveedor | Modelo / Voz | Contexto |
|---|---|---|---|
| LLM principal | Anthropic | claude-haiku-4-5-20251001 | 200K tokens, tools nativas, vision |
| TTS streaming | ElevenLabs | Malena rioplatense (`p7AwDmKvTdoHTBuueGvP`) | eleven_flash_v2_5, ~75ms latency |
| STT | Apple | Speech framework | On-device, multilenguaje |
| Vision OCR | Apple | Vision framework | On-device |

---

## Contacto

Para revocar consent fuera de la app, ejercer derechos GDPR/LGPD/LFPDPPP, o reportar un incidente de privacidad:

- Email: privacidad@metacasa.app
- Política de Privacidad completa: https://metacasa-app-cf592.web.app/privacy.html
- Términos de Servicio: https://metacasa-app-cf592.web.app/terms.html

---

*Este documento es parte del compromiso de transparencia de MetaCasa con sus usuarios y con App Store Review Guideline 5.1.1.*
