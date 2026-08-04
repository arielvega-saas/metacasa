import { type NextRequest, NextResponse } from "next/server";
import { updateSession, isAccessLocked } from "@/lib/supabase/middleware";

/** Rutas públicas (no requieren sesión). */
const PUBLIC_PREFIXES = [
  // Raíz: landing de marketing. `isPublic` la matchea solo de forma EXACTA
  // (ningún pathname empieza con "//"), así que el resto sigue protegido.
  // Con sesión, `app/page.tsx` redirige a /dashboard.
  "/",
  "/login",
  "/register",
  "/forgot-password",
  // El link de recovery puede abrirse en un dispositivo SIN sesión previa
  // (cross-device). `/auth/confirm` setea la sesión y redirige acá; en fallo
  // redirige a `/reset-password?error=expired`. Ambos casos deben ser públicos
  // para no rebotar al login. El form valida la sesión de recovery por su cuenta.
  "/reset-password",
  "/auth", // /auth/handoff, /auth/callback, /auth/confirm
  // Páginas legales estáticas (en public/): públicas, para que el link de
  // Privacidad/Términos de las apps abra sin rebotar al login.
  //
  // Van las DOS formas. Las apps enlazan la versión con `.html`, pero la forma sin
  // extensión también tiene que ser pública: es la que escribe una persona, la que
  // indexa un buscador y la que suele pedir un formulario de tienda. Mandar la
  // política de privacidad a una pantalla de login es exactamente el tipo de cosa
  // que App Review marca, y el redirect ni siquiera se ve como un error.
  "/privacy.html",
  "/terms.html",
  "/privacy",
  "/terms",
  // Fallback offline del PWA. Tiene que ser público: el service worker lo
  // precachea al instalarse (puede pasar con el usuario deslogueado) y, si el
  // middleware lo redirigiera a /login, guardaríamos el login como "página
  // offline". No muestra ningún dato del hogar.
  "/~offline",
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
    // Todo excepto assets estáticos de Next, el manifest PWA, el service worker
    // del PWA, los archivos de verificación de deep links (.well-known:
    // apple-app-site-association + assetlinks.json) y archivos con extensión de
    // imagen (iconos incluidos).
    // El manifest y .well-known deben ser públicos: sin esto el middleware
    // redirige /.well-known/* a /login y Apple/Google no pueden verificar los
    // Universal Links / App Links.
    // `sw.js` (+ su sourcemap y los workers auxiliares `swe-worker-*.js`) también
    // tiene que salir del matcher: si el middleware lo redirige a /login para un
    // usuario sin sesión, el navegador no puede registrar el service worker y el
    // PWA se queda sin offline.
    "/((?!_next/static|_next/image|favicon.ico|robots.txt|sitemap.xml|manifest.webmanifest|sw\\.js|sw\\.js\\.map|swe-worker-[^/]+\\.js|\\.well-known|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|avif|webmanifest)$).*)",
  ],
};
