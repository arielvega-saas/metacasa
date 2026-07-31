# Home Finance — handoff para Ariel (30-jul-2026)

## Estado automático

- App Store pública: `1.0.3` (4-jun-2026).
- Código local iOS: `1.0.3` build `12`, con cambios posteriores todavía no publicados.
- Supabase Auth: operativo.
- Firebase legal: privacy, terms y account deletion responden HTTP 200.
- `usehomefinance.com`: HTTP 402 `DEPLOYMENT_DISABLED` por suspensión de Vercel.
- Netlify: configuración lista en `netlify.toml`, pero esta Mac no tiene sesión iniciada ni sitio vinculado.
- iOS: build verde y 31/31 tests verdes.
- Web: 132/132 tests verdes usando un worker.

## Orden obligatorio

### 1. Facturación y continuidad

1. Entrar a Supabase Billing y pagar la factura vencida de la organización MetaCasa.
2. Confirmar que el proyecto `rgslvrxdppphzvqgcwbx` no tenga fecha de suspensión.
3. Decidir Vercel:
   - Si se paga Vercel, reactivar el team y verificar `usehomefinance.com`.
   - Si no se paga, continuar con Netlify. No usar Vercel Hobby para una app comercial.

### 2. Publicar la web en Netlify

1. Iniciar sesión:

   ```bash
   cd /Users/arielvega/Desktop/Proyectos/metacasa-app
   npx netlify-cli login
   ```

2. Crear/importar el sitio desde el repositorio `arielvega-saas/metacasa`.
3. Netlify debe tomar automáticamente:
   - Base: `metacasa-web`
   - Build: `npm run build`
   - Publish: `.next`
4. Configurar en Production y Deploy Previews:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `NEXT_PUBLIC_APP_URL=https://usehomefinance.com`
   - `NEXT_PUBLIC_SITE_URL=https://usehomefinance.com`
5. Hacer deploy primero con el subdominio temporal de Netlify.
6. Probar `/`, `/login`, `/auth/confirm`, `/privacy` y `/~offline`.

### 3. Mover el dominio

1. Agregar `usehomefinance.com` y `www.usehomefinance.com` al sitio de Netlify.
2. Aplicar los registros DNS que indique Netlify.
3. Esperar HTTPS activo.
4. Ejecutar:

   ```bash
   npm run release:preflight
   ```

   El dominio debe pasar con HTTP 200 antes de continuar.

### 4. Alinear Supabase y servicios externos

En Supabase Auth:

- Site URL: `https://usehomefinance.com`
- Redirect URLs:
  - `https://usehomefinance.com/auth/callback`
  - `https://usehomefinance.com/auth/confirm`
  - `https://usehomefinance.com/auth/reset`
  - `https://usehomefinance.com/auth/handoff`
  - `https://usehomefinance.com/**`

En Edge Functions:

- `WEB_APP_URL=https://usehomefinance.com`

En Mercado Pago Developers:

- `https://usehomefinance.com/wallets/callback`
- `http://localhost:3000/wallets/callback` para desarrollo.

### 5. Apple Developer

1. Crear App Group `group.com.metacasa.shared`.
2. Habilitarlo para:
   - `com.metacasa.app`
   - `com.metacasa.app.widgets`
3. Crear/configurar credenciales para Sign in with Apple si se incluirá en esta versión.
4. Crear APNs key si se habilitarán push notifications.
5. Confirmar productos e identificadores de RevenueCat.

### 6. Preparar la nueva versión

Después de validar TestFlight:

- Versión recomendada: `1.1.0`.
- Build recomendado inicial: `13`.
- No subir un binario nuevo manteniendo `1.0.3`.
- Verificar Restore Purchases, trial, paywall y cuenta demo de App Review.

### 7. Espacio en disco

Quedan aproximadamente 17 GB. Antes de generar Archive conviene liberar al
menos 20–30 GB desde Xcode Storage/Derived Data o moviendo archivos grandes.
No borrar manualmente datos del proyecto.

