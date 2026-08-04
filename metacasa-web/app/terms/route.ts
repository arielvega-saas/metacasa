import { redirect } from "next/navigation";

/** `/terms` → `/terms.html`. Ver la nota en `app/privacy/route.ts`. */
export function GET() {
  redirect("/terms.html");
}
