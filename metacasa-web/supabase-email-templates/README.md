# Plantillas de email branded — Home Finance

Diseño "Home Finance" para los correos de Supabase Auth (header oscuro + logo +
botón sage), en reemplazo del default sin marca.

El logo sale de `https://metacasa-web.vercel.app/logo.png` (ya hosteado).

## Estado
- ✅ **Confirm sign up** — YA aplicada en el dashboard (Authentication → Emails → Confirm sign up). Asunto: `Confirmá tu cuenta · Home Finance`.
- ⏳ **Reset password** — pendiente de pegar (`reset-password.html`). Asunto sugerido: `Restablecé tu contraseña · Home Finance`.
- ⏳ **Magic link** — pendiente de pegar (`magic-link.html`). Asunto sugerido: `Tu acceso a Home Finance`.

## Cómo aplicarlas (2 min c/u)
1. Dashboard → Authentication → **Emails** → Templates → elegí la plantilla.
2. En **Subject** poné el asunto sugerido.
3. En **Body** (pestaña *Source*): seleccioná todo (Cmd+A), borrá, y **pegá** el HTML del archivo correspondiente.
4. **Save changes**. Verificá con la pestaña *Preview*.

> Nota: el remitente sigue siendo "Supabase Auth" hasta configurar **SMTP propio**
> (Authentication → Emails → SMTP Settings, ej. Resend/SendGrid). Eso cambia el
> nombre del remitente a "Home Finance" y saca los límites del servicio built-in.

Todas las plantillas usan la variable `{{ .ConfirmationURL }}` de Supabase.
