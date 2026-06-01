import { type NextRequest, NextResponse } from "next/server";
import { updateSession, isAccessLocked } from "@/lib/supabase/middleware";

/** Rutas públicas (no requieren sesión). */
const PUBLIC_PREFIXES = [
  "/login",
  "/register",
  "/forgot-password",
  "/auth", // /auth/handoff, /auth/callback, /auth/confirm
];

function isPublic(pathname: string) {
  return PUBLIC_PREFIXES.some(
    (p) => pathname === p || pathname.startsWith(p + "/"),
  );
}

export async function middleware(request: NextRequest) {
  const { response, user } = await updateSession(request);
  const { pathname } = request.nextUrl;

  // Sin sesión + ruta protegida → al login (con returnTo).
  if (!user && !isPublic(pathname)) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    if (pathname !== "/") url.searchParams.set("returnTo", pathname);
    return NextResponse.redirect(url);
  }

  // Con sesión + en una página de auth → al dashboard.
  if (user && (pathname === "/login" || pathname === "/register")) {
    const url = request.nextUrl.clone();
    url.pathname = "/dashboard";
    url.search = "";
    return NextResponse.redirect(url);
  }

  // Gate de MUTACIONES: las Server Actions (POST con header next-action) no
  // ejecutan el layout, así que el gate de acceso se aplica acá. Un usuario
  // 'locked' (trial vencido + sin sub) no puede crear/editar/borrar nada.
  if (
    user &&
    request.method === "POST" &&
    request.headers.has("next-action") &&
    !isPublic(pathname)
  ) {
    if (await isAccessLocked(request)) {
      return NextResponse.redirect(new URL("/locked", request.url));
    }
  }

  return response;
}

export const config = {
  matcher: [
    // Todo excepto assets estáticos de Next, el manifest PWA y archivos con
    // extensión de imagen (iconos incluidos). El manifest debe ser público para
    // que el prompt de instalación de Android/iOS funcione sin sesión.
    "/((?!_next/static|_next/image|favicon.ico|robots.txt|sitemap.xml|manifest.webmanifest|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|avif|webmanifest)$).*)",
  ],
};
