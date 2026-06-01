import { redirect } from "next/navigation";

/**
 * Raíz: el middleware ya manda a /login si no hay sesión. Si hay sesión,
 * derivamos al dashboard.
 */
export default function Home() {
  redirect("/dashboard");
}
