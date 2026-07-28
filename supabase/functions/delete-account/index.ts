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
//   3. Borramos los households donde el user es el ÚNICO miembro (el cascade de
//      household_id limpia transactions, bills, accounts, goals, budgets, etc.).
//      Sin esto, el hogar quedaba huérfano con toda la PII financiera adentro
//      para siempre — invisible por RLS pero retenida (riesgo GDPR / 5.1.1(v)).
//   4. Llamamos auth.admin.deleteUser(userId) usando service_role. Las FK
//      `ON DELETE CASCADE` y `SET NULL` limpian el resto (memberships,
//      subscriptions, entitlements, wallets, recurring, bills propios, auth.*).
//
// Hogares COMPARTIDOS: se conservan (los datos pertenecen al hogar). Las filas
// de transactions/budgets/categories/strategy del user borrado conservan su
// user_id como uuid colgante A PROPÓSITO: la PII real (email, identidad) muere
// con auth.users, así el dato queda pseudonimizado; ponerlos en NULL rompería
// el decode de modelos no-opcionales en la app iOS ya publicada.
//
// Solo el dueño del JWT puede borrarse a sí mismo. Nunca aceptamos un
// userId arbitrario desde el cliente.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// CORS allowlist — copia inline de supabase/functions/_shared/cors.ts.
const ALLOWED_ORIGINS = new Set([
  "https://usehomefinance.com",
  "https://www.usehomefinance.com",
  "https://metacasa-app-cf592.web.app",
  "https://metacasa-app-cf592.firebaseapp.com",
  "http://localhost:3000",
  "http://localhost:5173",
]);

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin");
  let allowed: string | null = null;
  if (origin) {
    if (ALLOWED_ORIGINS.has(origin)) {
      allowed = origin;
    } else {
      try {
        const host = new URL(origin).hostname;
        if (host.endsWith(".vercel.app") && host.startsWith("metacasa-web")) {
          allowed = origin;
        }
      } catch { /* origen malformado → sin CORS */ }
    }
  }
  const base: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, content-type, apikey",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (allowed) {
    base["Access-Control-Allow-Origin"] = allowed;
    base["Vary"] = "Origin";
  }
  return base;
}

Deno.serve(async (req: Request) => {
  const cors = corsHeaders(req);
  const jsonError = (message: string, status: number): Response =>
    new Response(JSON.stringify({ error: message }), {
      status,
      headers: { "Content-Type": "application/json", ...cors },
    });

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: cors });
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

  // 1) Households donde el user es miembro.
  const { data: mine, error: mineErr } = await supabase
    .from("household_members")
    .select("household_id")
    .eq("user_id", userId);
  if (mineErr) {
    return jsonError(`delete_failed: ${mineErr.message}`, 500);
  }
  const myHouseholdIds = [...new Set((mine ?? []).map((r) => r.household_id))];

  // 2) De esos, cuáles tienen OTROS miembros (esos hogares se conservan).
  let soloHouseholdIds: string[] = [];
  if (myHouseholdIds.length > 0) {
    const { data: others, error: othersErr } = await supabase
      .from("household_members")
      .select("household_id")
      .in("household_id", myHouseholdIds)
      .neq("user_id", userId);
    if (othersErr) {
      return jsonError(`delete_failed: ${othersErr.message}`, 500);
    }
    const shared = new Set((others ?? []).map((r) => r.household_id));
    soloHouseholdIds = myHouseholdIds.filter((id) => !shared.has(id));
  }

  // 3) Borrar los hogares solo-owned ANTES del user. Si esto falla, abortamos
  //    sin borrar el user (mejor un retry completo que un borrado a medias).
  if (soloHouseholdIds.length > 0) {
    const { error: hhErr } = await supabase
      .from("households")
      .delete()
      .in("id", soloHouseholdIds);
    if (hhErr) {
      return jsonError(`delete_failed: ${hhErr.message}`, 500);
    }
  }

  // 4) Borrar el usuario (cascade limpia el resto).
  const { error: deleteErr } = await supabase.auth.admin.deleteUser(userId);
  if (deleteErr) {
    return jsonError(`delete_failed: ${deleteErr.message}`, 500);
  }

  return new Response(
    JSON.stringify({
      ok: true,
      deleted_user_id: userId,
      deleted_households: soloHouseholdIds.length,
    }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
        ...cors,
      },
    },
  );
});
