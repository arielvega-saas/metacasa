# Home Finance — estado vivo

> Última actualización: **2026-08-01**.
> Este archivo es lo primero que tiene que leer cualquier IA que entre al proyecto.
> Si trabajaste acá y algo de esto cambió, **actualizalo antes de cerrar la sesión**.

## ✅ MIGRACIÓN CERRADA (2026-08-01)

`https://usehomefinance.com` está **EN LÍNEA**. La migración de Vercel a Netlify terminó completa:

- DNS en Netlify (zona `6a6e0d97c08a56003cef888e`), nameservers `dns1..4.p08.nsone.net`
- Certificado SSL emitido. Verificado por HTTPS: `/`, `/login`, `/privacy`, `/~offline`, `/register`
  devuelven 200; `/dashboard` sin sesión hace 307 a `/login`; `www` hace 301 al apex
- **El email de Brevo nunca se cortó**: los 4 registros (DKIM x2, DMARC, TXT) se espejaron ANTES de
  mover los nameservers, así que durante la propagación ambas zonas decían lo mismo
- `web-handoff` desplegado apuntando al dominio propio → el handoff desde la app vuelve a abrir la web
  YA CON SESIÓN, en vez de mandar a la PWA vieja a loguearse a mano
- Supabase Auth ya estaba correcto: Site URL `https://usehomefinance.com` y allowlist con
  `https://usehomefinance.com/**`
- Sin pagarle nada a Vercel y sin crear cuentas nuevas

**Pendiente menor:** `ai-proxy` en prod no tiene `home-finance-web.netlify.app` en su allowlist de CORS
(sí tiene el dominio propio, que es el que importa). Sólo haría falta si se usa el subdominio temporal.

⚠️ **Para junio 2027:** el dominio **sigue registrado en Vercel** y auto-renueva el 1-jun-2027 a
US$ 11,25. Si esa cuenta sigue suspendida, la renovación puede fallar. Conviene transferirlo a otro
registrador en algún momento tranquilo.

**Lo que sigue en el producto:** 9 hallazgos de auditoría en `AUDITORIA-2026-08-01.md`, ordenados por
gravedad. Los grandes: rollover de sobres que nunca se calcula, transferencias que inflan los KPIs, y el
preview del import que debería preguntar cuenta y moneda.

---

## En una línea

App de finanzas del hogar para LATAM. iOS publicada y funcionando; la web está **caída** por facturación
de Vercel; el plan de nivel pro (`app/PLAN_NIVEL_PRO.md`) tiene las Fases 1-4 casi completas y lo que
queda está mayormente bloqueado por credenciales de Ariel, no por código.

## Qué está vivo y qué no

| Frente | Estado | Dónde |
|---|---|---|
| iOS | **Publicada** en App Store `1.0.3` (4-jun-2026). Local va `1.0.3` build `12` con cambios sin publicar. | `app/metacasa-ios` |
| Android | `.aab` generados, sin publicar. | `app/metacasa-flutter`, binarios en `builds/` |
| Web (futuro) | Next.js 15, código listo. **Caída: `usehomefinance.com` da HTTP 402.** | `app/metacasa-web` |
| Web (legacy) | PWA en Vite. **Se retira.** No invertir UI acá. Sus wallets LatAm ya fueron portadas. | `app/src` |
| Backend | Supabase `rgslvrxdppphzvqgcwbx`, **ACTIVE_HEALTHY**, org en plan **pro**. | `app/supabase` |

## Bloqueos abiertos (necesitan a Ariel, no a una IA)

1. **Migración a Netlify — DNS HECHO, falta el certificado SSL (2026-08-01).**

   **Hecho y verificado:**
   - Zona DNS creada en Netlify (`zone_id 6a6e0d97c08a56003cef888e`) con los 4 registros de email de
     Brevo espejados ANTES de tocar los nameservers, así que **el email nunca dejó de funcionar**:
     `brevo1._domainkey`, `brevo2._domainkey` (DKIM), `_dmarc` y el TXT de verificación del apex.
   - Nameservers cambiados en Vercel a `dns1..4.p08.nsone.net`. **Ya propagaron.**
   - `usehomefinance.com` resuelve a `75.2.60.5` y **responde 200 por HTTP**.
   - Las 3 variables de Netlify apuntan al dominio real y el sitio está redeployado.

   **Bloqueado del lado de Netlify:** el panel dice "Netlify DNS propagating..." para el apex y el
   certificado queda en "Waiting on DNS propagation". La causa: el registro **ALIAS (`NETLIFY`) que
   ellos autogeneran para el apex nunca resolvió** — el del `www`, creado igual y al mismo tiempo, sí
   funciona. Descartado que fuera conflicto con el registro A manual (se quitó y se esperó 7 min: el
   ALIAS siguió mudo). La API rechaza crear registros `NETLIFY` a mano (`Unprocessable Entity`) y
   también rechaza `provisionSiteTLSCertificate`. Resetear `custom_domain` no lo regeneró.

   **El apex hoy usa un registro A explícito a `75.2.60.5`**, que es la configuración documentada de
   Netlify para DNS externo y funciona: por eso HTTP responde 200 — que es justo lo que Let's Encrypt
   necesita para validar por HTTP-01.

   **Siguiente paso si no sale solo:** ticket a soporte de Netlify por el ALIAS defectuoso del apex en
   la zona. La verificación de DNS puede tardar hasta 24 h según su documentación.

   **Cuando el certificado salga**, queda por hacer: desplegar `web-handoff` apuntado a la web nueva
   (hasta entonces sigue mandando a la PWA de Firebase, que funciona), el CORS de `ai-proxy`, y cargar
   en Supabase Auth la Site URL y la allowlist de redirects con el dominio nuevo.

   ⚠️ **Para el futuro:** el dominio **sigue registrado en Vercel** y auto-renueva el 1-jun-2027 a
   US$ 11,25. Si la cuenta sigue suspendida para entonces, esa renovación puede fallar y perder el
   dominio sería catastrófico. Conviene transferirlo a otro registrador en algún momento tranquilo.

2. **App Group `group.com.metacasa.shared`** sin crear en el Developer Portal → los widgets compilan e
   instalan pero muestran estado vacío.
3. **Redirect URI de Mercado Pago** sin registrar (app `2693470312497962`) → las wallets no se pueden
   conectar. Falta `https://usehomefinance.com/wallets/callback` + `http://localhost:3000/wallets/callback`.
4. **Sign in with Apple** (4.6), **push APNs** (4.10) y **CI** (4.9) — esperan credenciales / repo en GitHub.

**El dominio NO corre riesgo**: `usehomefinance.com` renueva el 1-jun-2027.

## Mitigación que está aplicada ahora mismo

El banner de handoff de la app iOS **no** apunta a `usehomefinance.com` (que está muerto): la edge function
`web-handoff` devuelve la PWA de Firebase, y detecta destinos sin soporte de handoff para devolver la URL
pelada en vez de quemar un magic link. **Revertir a `usehomefinance.com` (o setear el secret `WEB_APP_URL`)
cuando Netlify esté sirviendo el dominio.**

## Reglas de este proyecto que ya costaron caro

- La app publicada lee la URL que devuelve la **edge function**, no la del `Info.plist`. Se puede cambiar el
  destino web sin release de iOS.
- **Drift de migraciones**: una migración en el repo ≠ aplicada en prod. Comparar el ledger vivo contra
  `app/supabase/migrations/` antes de razonar sobre el backend. Todo cambio por CLI, nada por dashboard.
- `parseMoney` ya tuvo un bug que convertía 1.234.567 en 1,23. Cualquier toque a dinero va con tests.
- No dejar features a medio cablear. Si el código de una vista existe pero no hay target/entitlement/call
  site, **no está hecho**.

## Dónde seguir

`app/PLAN_NIVEL_PRO.md` es la hoja de ruta. Lo que queda sin bloqueo externo:

- Patrones de mercado ❌ del plan: anillos de presupuesto con semáforo + proyección, metas como cajitas con
  gesto de fondeo, grilla de acciones rápidas, onboarding de confianza gradual, feed con logos de comercio.
- Fase 4.11: iPad con `NavigationSplitView`, Tab API iOS 18+, `.tabViewBottomAccessory` iOS 26.
- Enganchar los tests pgTAP a CI (cuando haya CI).

## Bitácora

- **2026-08-01 (tarde)** — **DNS migrado de Vercel a Netlify.** Vercel bloqueaba la escritura de DNS por
  la cuenta suspendida, así que se cambiaron los nameservers. Los 4 registros de email de Brevo se
  espejaron ANTES del cambio: el correo nunca se cortó. Apex y www resuelven a Netlify, HTTP 200.
  Falta sólo el certificado SSL, trabado del lado de Netlify. Sin pagar Vercel ni crear cuentas nuevas.
- **2026-08-01** — Auditoría de tres frentes (producto, seguridad, App Store) + arreglos. **16 de 27
  hallazgos cerrados**, cada uno verificado a mano antes de tocar y contra producción después.
  Cerrados en prod: bypass del app lock, auto-inscripción en hogares ajenos, `wallet-proxy` que
  filtraba el `MP_CLIENT_SECRET`, CORS que rompía borrar-cuenta desde la web, sobres que ignoraban
  subcategorías. Bugs de dinero: patrimonio neto multi-moneda, fecha que corría el mes, cuotas sin
  residuo, paywall que podía cobrar sin desbloquear, y el selector de cuenta (51 de 61 transacciones
  no tenían cuenta). **Tests: 31 → 85.** Detalle en `AUDITORIA-2026-08-01.md`.

- **2026-07-31 (tarde)** — Web **en línea** en `home-finance-web.netlify.app` (verificado: 5 rutas en 200,
  cero errores de consola, claro y oscuro sin fallos de contraste AA, `/dashboard` redirige 307 a `/login`).
  iOS: anillos de presupuesto con proyección de ritmo, metas con fondeo de un toque, Tab API iOS 18.
  **54/54 tests.** Healthcheck ajustado para vigilar el sitio de Netlify y no notificar por el DNS pendiente.

- **2026-07-31** — Consolidación: todo el producto pasó de 7 carpetas desparramadas en `~/Desktop/Proyectos`
  (más `~/metacasa-supabase` y un `.aab` suelto en el Escritorio) a `~/dev/HomeFinance/`, **fuera de iCloud**.
  Se borraron 56.725 archivos de worktrees muertos de Claude y las 5 copias `MetaCasa N.xcodeproj`.
  Ver `../README.md` y `../archive/README.md`.
- **2026-07-28** — Fase 4 al 8/11. Light mode "Daylight Sage", PWA offline, wallets LatAm portadas, FX
  automático con dólar blue, pgTAP 14/14 contra prod.
- **2026-07-27** — Se generó `PLAN_NIVEL_PRO.md` a partir de 4 auditorías en paralelo.
