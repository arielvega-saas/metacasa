# Home Finance — estado vivo

> Última actualización: **2026-07-31**.
> Este archivo es lo primero que tiene que leer cualquier IA que entre al proyecto.
> Si trabajaste acá y algo de esto cambió, **actualizalo antes de cerrar la sesión**.

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

1. **Migración a Netlify — EN CURSO (2026-07-31).** Vercel queda descartado: su Hobby prohíbe uso comercial
   y Home Finance cobra suscripciones; ⚠️ **no tocar "Reactivate Plan"**, reintenta la prepaga que rebotó.
   Ya hecho: sitio **`home-finance-web`** creado y vinculado (`home-finance-web.netlify.app`), las 7
   variables de entorno cargadas, `main` al día y pusheado.
   **La web YA está sirviendo en `https://home-finance-web.netlify.app`** (verificado: 5 rutas en 200,
   sin errores de consola, y `/dashboard` sin sesión redirige 307 a `/login`, o sea que el middleware
   levanta bien el cliente de Supabase). El dominio ya está registrado como `custom_domain` del sitio.

   **Falta mover el DNS.** Situación: los nameservers de `usehomefinance.com` son **de Vercel**
   (`ns1/ns2.vercel-dns.com`) — la zona la administra la cuenta suspendida. Registrador: **name.com**.
   Averiguado antes de tocar nada: **no hay MX** (ningún email en riesgo) y los subdominios que parecen
   existir (`api`, `app`, `mail`, `staging`, `admin`) son **wildcard de Vercel**, no registros reales —
   verificado porque un subdominio inventado también resuelve. Lo ÚNICO real a preservar es un TXT:
   `brevo-code:7f2d14c668fc97c9bfa98356551e7a14`.

   Pasos (en name.com):
   1. Cambiar los nameservers de Vercel a los propios de name.com.
   2. `usehomefinance.com` → registro **A** a `75.2.60.5` (balanceador apex de Netlify).
   3. `www` → **CNAME** a `home-finance-web.netlify.app`.
   4. Volver a crear el **TXT de Brevo** de arriba.

   Netlify DNS no es opción: la cuenta es plan Free y `createDnsZone` devuelve 500.

   **Cuando el DNS resuelva**, en el mismo movimiento: actualizar `NEXT_PUBLIC_APP_URL`,
   `NEXT_PUBLIC_SITE_URL` y `MP_OAUTH_REDIRECT_URI` (hoy apuntan al subdominio temporal **a propósito**,
   para que el smoke test fuera real), redeployar, y cargar las URLs en Supabase Auth (Site URL +
   allowlist de redirects) o los magic links y la confirmación de email no van a funcionar.
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
