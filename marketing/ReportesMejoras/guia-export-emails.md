# 📥 Guía: ver y exportar los emails capturados (waitlist)

Los emails que la gente deja en la landing (`/get/`) se guardan en **Supabase**, tabla `public.email_waitlist`.

> 🔒 Por seguridad (RLS), la lista **NO se puede leer desde la API pública** — solo se inserta. Para verla necesitás entrar a tu cuenta de Supabase (service_role / dashboard). Esto es a propósito: que nadie pueda robarte la lista desde el navegador.

---

## Opción 1 — Dashboard (la más simple, recomendada)

1. Entrá a **https://supabase.com/dashboard** con tu cuenta.
2. Proyecto **METACASA** (`rgslvrxdppphzvqgcwbx`).
3. Menú izquierdo → **Table Editor** → tabla **`email_waitlist`**.
4. Ahí ves todos los emails con: `email`, `lang` (es/en/pt), `source` (landing), `created_at`.
5. Para descargar: botón **Export** (arriba a la derecha de la tabla) → **CSV**.

---

## Opción 2 — SQL (para filtrar o contar)

Supabase Dashboard → **SQL Editor** → pegá:

```sql
-- Todos los emails, más nuevos primero
select email, lang, source, created_at
from public.email_waitlist
order by created_at desc;

-- Cuántos por idioma
select lang, count(*) as total
from public.email_waitlist
group by lang
order by total desc;

-- Solo los de hoy
select email, lang
from public.email_waitlist
where created_at::date = current_date;
```

El resultado se exporta a CSV con el botón **Download** del editor.

---

## Opción 3 — Pedímelo a mí

Cuando quieras, decime *"¿cuántos emails hay en la waitlist?"* y lo consulto al instante (tengo acceso vía la herramienta de Supabase). Te puedo dar el conteo, el desglose por idioma, o exportarlo a un CSV/Excel dentro del proyecto.

---

## Estructura de la tabla (referencia)

| Columna | Tipo | Qué guarda |
|---|---|---|
| `id` | uuid | id único |
| `email` | text | el email (único, case-insensitive) |
| `lang` | text | idioma de la landing al enviar (es/en/pt) |
| `source` | text | de dónde vino (siempre `landing` por ahora) |
| `user_agent` | text | navegador (opcional, hoy no se llena) |
| `created_at` | timestamptz | cuándo se anotó |

> Migración: `supabase/migrations/20260530103339_create_email_waitlist.sql`. Hoy la tabla está en **0 filas** (limpié los tests). Empieza a llenarse sola cuando la gente use el form de `/get/`.

---

## 💡 Próximo paso sugerido (cuando haya lista)

Cuando juntes emails, lo natural es mandar el **"ya salió Android"** o un newsletter. Para eso conviene conectar un servicio de envío (Mailchimp/Beehiiv/Resend) e importar el CSV — o armar una Edge Function que mande desde Supabase. Decime cuando llegue ese momento y lo armamos.
