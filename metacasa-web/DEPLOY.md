# Deploy — Home Finance Web (Vercel)

La app **ya está lista para deployar** (`next build` pasa, 19 rutas). El deploy va a **tu** cuenta Vercel y requiere configurar variables de entorno (sin ellas la app rinde rota porque el cliente Supabase queda sin URL/key). Seguí estos pasos una vez.

## 1. Crear el proyecto en Vercel

**Opción A — Dashboard (recomendada):**
1. vercel.com → **Add New → Project** → importá este repo de GitHub.
2. **Root Directory: `metacasa-web`** ← clave (es un monorepo). Framework: Next.js (autodetectado).
3. Build & Output: dejar por defecto (`next build`).

**Opción B — CLI:**
```bash
cd metacasa-web
npx vercel            # primera vez: link/login; setear root = . (estás dentro de metacasa-web)
npx vercel --prod     # deploy a producción
```

## 2. Variables de entorno (Vercel → Project → Settings → Environment Variables)

Para **Production** y **Preview**:

| Variable | Valor |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://rgslvrxdppphzvqgcwbx.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `sb_publishable_Z7D-ijzkurR2BXCsTmfCsQ_YGRa1SbZ` (publishable, segura en cliente) |
| `NEXT_PUBLIC_APP_URL` | el dominio Vercel, ej. `https://metacasa-web.vercel.app` |

> La publishable key es pública por diseño. **No** pongas el `service_role` acá (solo vive en Edge Functions).

Re-deployá después de setear las env (Deployments → Redeploy).

## 3. Post-deploy (3 pasos en Supabase + iOS)

Una vez que tengas el dominio definitivo (ej. `https://metacasa-web.vercel.app`):

### a) Supabase Auth → URL Configuration
- **Redirect URLs**: agregá
  - `https://<tu-dominio>/auth/callback`
  - `https://<tu-dominio>/auth/handoff`
  - `https://<tu-dominio>/**` (wildcard, opcional)
- **Site URL**: poné el dominio web. ⚠️ **Sacá `localhost`** del Site URL antes de producción — si no, los emails de confirmación rompen a los usuarios (ERR_CONNECTION_FAILED; la cuenta igual queda confirmada).
- Activá **Leaked password protection** (Auth → Policies) — lo marcó el advisor de seguridad.

### b) Edge Function `web-handoff` → secret `WEB_APP_URL`
La función arma la URL del handoff con `WEB_APP_URL` (hoy fallback `metacasa-web.vercel.app`). Seteá el dominio real:
```bash
supabase secrets set WEB_APP_URL=https://<tu-dominio>
# o desde el dashboard: Edge Functions → web-handoff → Secrets
```

### c) iOS
- Actualizá `metacasa-ios/MetaCasa/Supporting/Info.plist` → `WEB_APP_URL` = `https://<tu-dominio>`.
- ⚠️ **Recién después de que la web esté LIVE**, buildeá y subí el update de iOS (el banner de Home y la fila de Ajustes abren la web; si la web no existe todavía, abrirían un dominio muerto). Antes de abrir Xcode: `cd metacasa-ios && xcodegen generate`.

## 4. Verificación end-to-end

1. Abrí `https://<tu-dominio>/login` → debe cargar el login premium.
2. Logueate con tu cuenta real → dashboard con tus datos (vía RLS).
3. Recorré Movimientos / Presupuesto / Reportes / Perfil.
4. Handoff: en la app iOS → Ajustes → "Abrir versión Web" → debe abrir el navegador **ya logueado** en el dashboard.

## Notas
- Hay dos `package-lock.json` (raíz del monorepo y `metacasa-web/`). Con Root Directory = `metacasa-web`, Vercel usa el de `metacasa-web/`. El `outputFileTracingRoot` ya está seteado en `next.config.ts`.
- Dominio propio: cuando lo tengas, agregalo en Vercel → Domains y repetí el paso 3 (a/b/c) con el dominio nuevo.
