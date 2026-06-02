# Plantillas de email branded — Home Finance

Diseño "Home Finance" para los correos de Supabase Auth (header oscuro + logo +
botón sage), en reemplazo del default sin marca.

El logo sale de `https://usehomefinance.com/logo.png` (servido desde `public/logo.png`).

## Importante: links `token_hash` + dominio propio (deep linking)

Las plantillas **ya no usan `{{ .ConfirmationURL }}`**. Ese link apuntaba al
endpoint `/auth/v1/verify` de Supabase y hacía un **302** — y un 302 **no
dispara** Universal Links (iOS) ni App Links (Android), así que el mail abría la
web en vez de la app. Ahora cada link se arma a mano con `{{ .TokenHash }}`
apuntando **directo al dominio propio**, que es lo que las apps reclaman:

- **Confirm signup / Magic link** → `{{ .SiteURL }}/auth/confirm?token_hash=…&type=…&next=/dashboard`
  La ruta `/auth/confirm` la reclaman iOS (Universal Links) y Android (App
  Links): si la app está instalada se abre y loguea; si no, cae a la web.
- **Reset password** → `{{ .SiteURL }}/auth/reset?token_hash=…&type=recovery&next=/reset-password`
  Ruta que las apps **no** reclaman a propósito: el reset se hace en la web
  (`/reset-password`, cross-device), no en la app.

### Requisitos en el dashboard (una vez)
- **Authentication → URL Configuration → Site URL** = `https://usehomefinance.com`
  (las plantillas usan `{{ .SiteURL }}` como base).
- **Redirect URLs** (allow-list) deben incluir:
  - `https://usehomefinance.com/auth/confirm`
  - `https://usehomefinance.com/auth/reset`
  - `https://usehomefinance.com/reset-password`
  - `https://usehomefinance.com/dashboard`
  - (o simplemente `https://usehomefinance.com/**`)

## Estado (RE-PEGAR las tres con el nuevo HTML `token_hash`)
- ⏳ **Confirm sign up** — pegar `confirm-signup.html`. Asunto: `Confirmá tu cuenta · Home Finance`.
- ⏳ **Reset password** — pegar `reset-password.html`. Asunto: `Restablecé tu contraseña · Home Finance`.
- ⏳ **Magic link** — pegar `magic-link.html`. Asunto: `Tu acceso a Home Finance`.

## Cómo aplicarlas (2 min c/u)
1. Dashboard → Authentication → **Emails** → Templates → elegí la plantilla.
2. En **Subject** poné el asunto sugerido.
3. En **Body** (pestaña *Source*): seleccioná todo (Cmd+A), borrá, y **pegá** el HTML del archivo correspondiente.
4. **Save changes**. Verificá con la pestaña *Preview*.

> Nota: el remitente sigue siendo "Supabase Auth" hasta configurar **SMTP propio**
> (Brevo). Eso cambia el nombre del remitente a "Home Finance" y saca los límites
> del servicio built-in.
