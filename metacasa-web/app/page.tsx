import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { Landing } from "./(marketing)/landing";
import { MarketingShell } from "./(marketing)/marketing-shell";

/**
 * Raíz `/`: landing de marketing para visitantes sin sesión; con sesión,
 * derivamos al dashboard (mismo patrón getUser que usa el middleware).
 *
 * Nota: la landing no puede ser `force-static` porque este gate lee cookies
 * de sesión. El contenido en sí (`(marketing)/landing.tsx`) es 100% estático.
 */

export const metadata: Metadata = {
  title: {
    absolute: "Home Finance — Tu plata más clara, tu casa más tranquila",
  },
  description:
    "Presupuesto familiar con IA, multi-moneda y privacidad. La app de finanzas del hogar para toda la familia. Probala 7 días con todo Premium.",
};

export default async function Home() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) redirect("/dashboard");

  return (
    <MarketingShell>
      <Landing />
    </MarketingShell>
  );
}
