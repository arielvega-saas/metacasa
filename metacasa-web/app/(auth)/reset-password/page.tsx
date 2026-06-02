import type { Metadata } from "next";
import { UpdatePasswordForm } from "@/components/auth/update-password-form";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("auth.metaReset") };
}

export default async function ResetPasswordPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  // `/auth/confirm` nos manda acá con `?error=expired` si la verificación del
  // link de recovery falló (link vencido o ya usado).
  const { error } = await searchParams;
  return <UpdatePasswordForm linkError={error === "expired"} />;
}
