import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.45.0";

// Edge Function: delete-account
//
// Permite que un usuario elimine su propia cuenta in-app, requerido por
// App Store Review Guideline 5.1.1(v): apps que permiten crear cuenta deben
// permitir borrarla también, sin obligar al user a contactar soporte.
//
// Flow:
//   1. El cliente iOS llama esta función con su JWT (Bearer token).
//   2. Validamos el JWT y extraemos el user_id.
//   3. Llamamos auth.admin.deleteUser(userId) usando service_role.
//   4. Las FK `ON DELETE CASCADE` se encargan de borrar:
//      - household_members rows del user
//      - chat_sessions, ai_usage_daily, etc. (cualquier tabla con FK a auth.users)
//   5. Si el user era el único miembro de un household, ese household queda
//      huérfano — un job nocturno los limpia. No es problema de seguridad
//      porque RLS impide acceso sin un miembro.
//
// Solo el dueño del JWT puede borrarse a sí mismo. Nunca aceptamos un
// userId arbitrario desde el cliente.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type, apikey",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonError("method not allowed", 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonError("missing bearer token", 401);
  }
  const userJwt = authHeader.slice(7);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userErr } = await supabase.auth.getUser(userJwt);
  if (userErr || !userData.user) {
    return jsonError("invalid jwt", 401);
  }
  const userId = userData.user.id;

  const { error: deleteErr } = await supabase.auth.admin.deleteUser(userId);
  if (deleteErr) {
    return jsonError(`delete_failed: ${deleteErr.message}`, 500);
  }

  return new Response(
    JSON.stringify({ ok: true, deleted_user_id: userId }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "no-store",
      },
    },
  );
});

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
