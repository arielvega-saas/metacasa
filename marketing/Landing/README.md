# 🌐 Landing Page — Home Finance

Landing **trilingüe (ES/EN/PT)**, self-contained (1 archivo HTML + assets), sin build step, sin dependencias. Verificada localmente: render OK, 0 errores de consola, toggle de idioma y validación de form funcionando.

## Qué incluye

- Hero con logo, claim por idioma y botones de descarga (App Store activo, Google Play "muy pronto")
- 6 features (los diferenciadores reales)
- Showcase con 4 screenshots reales de la app
- Tabla comparativa honesta (vs YNAB / Monarch / Honeydue)
- Captura de email (waitlist Android + newsletter)
- Footer con links legales reales
- Auto-detección de idioma del navegador + toggle manual ES/EN/PT

## 👀 Previsualizar localmente

```bash
cd marketing/Landing
python3 -m http.server 8899
# abrir http://localhost:8899/index.html
```

## 🔧 2 cosas que necesito de Ariel (no las puedo hacer yo)

1. ✅ **Link real del App Store (iOS) — RESUELTO.** Detectado vía iTunes Search API:
   `https://apps.apple.com/app/id6769792040` (app id `6769792040`, dev ARIEL JOSUE VEGA GUERRERO).
   Ya está cableado en el HTML (`IOS_URL`). **Verificá que sea la tuya** (abrilo en el iPhone) y avisame si hay otro id.

2. **Re-login de Firebase** para el deploy (`firebase login --reauthenticate`) — ver sección Deploy.

3. **Backend del formulario de email** — elegí uno (hoy degrada a abrir el mail del usuario):
   - **A) Supabase (recomendado, ya es tu stack):** creo una tabla `email_waitlist` + RLS de insert anónimo, y conecto el form vía REST con la anon key. Necesita tu OK para tocar la DB de producción.
   - **B) Formspree / Mailchimp / Beehiiv:** te registrás (5 min), me pasás el endpoint, lo pego en `EMAIL_ENDPOINT`.
   - **C) Dejarlo en mailto** por ahora (funciona, pero no escala ni arma lista).

## 🚀 Deploy → `metacasa-app-cf592.web.app/get/`

**Todo listo. Un solo comando** (script ya armado, `deploy.sh`):

```bash
bash marketing/Landing/deploy.sh
```

El script stagea la landing en `dist/get/` y corre `firebase deploy --only hosting`, verificando antes que las páginas legales no se pisen.

### ⚠️ Bloqueante actual: re-login de Firebase
Las credenciales del Firebase CLI **expiraron** (`Failed to authenticate`). Antes de deployar, corré **vos** (abre el navegador, login con tu cuenta Google):

```bash
firebase login --reauthenticate
```

Una vez logueado, corré el `deploy.sh` (o decime y lo corro yo).

### Por qué NO uso `npm run build` para esto
`scripts/copy-public.mjs` copia una **lista fija** de archivos que **NO incluye `account-deletion.html`** (página legal que pide Google Play). Un rebuild podría dejarla afuera. Por eso el deploy solo **agrega** la landing a `dist/` sin reconstruir la PWA. (Esto también es un mini-bug a futuro: conviene que `copy-public.mjs` incluya `account-deletion.html` — ver ticket sugerido.)

> Alternativa: deploy independiente en **Vercel** (hay MCP de Vercel) para un dominio propio tipo `homefinance.app`. Decímelo y lo armo.

## Editar textos

Todo el copy de los 3 idiomas vive en el objeto `I18N` dentro del `<script>`. Editás ahí y se actualiza solo.
