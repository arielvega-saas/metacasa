import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import type { User } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";

function envClient(request: NextRequest, onSet?: (set: { name: string; value: string; options: Record<string, unknown> }[]) => void) {
  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          onSet?.(cookiesToSet as never);
        },
      },
    },
  );
}

/**
 * Refresca la sesión de Supabase en cada request (rotación de tokens) y
 * devuelve el usuario actual + la respuesta con las cookies actualizadas.
 */
export async function updateSession(request: NextRequest): Promise<{
  response: NextResponse;
  user: User | null;
}> {
  let response = NextResponse.next({ request });

  const supabase = createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          );
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // IMPORTANTE: getUser() valida el JWT contra el servidor de Auth (no confiar
  // en getSession() en el server). No insertar lógica entre createServerClient
  // y getUser() para evitar cierres de sesión difíciles de depurar.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return { response, user };
}

/**
 * ¿El acceso del usuario está 'locked' (trial vencido + sin suscripción)?
 * Se usa para gatear MUTACIONES (Server Actions) en el borde — el layout solo
 * gatea la navegación, y las Server Actions no ejecutan el layout.
 */
export async function isAccessLocked(request: NextRequest): Promise<boolean> {
  const supabase = envClient(request);
  const { data } = await supabase.rpc("web_access_state");
  const state = (data as { state?: string } | null)?.state;
  return state === "locked";
}
