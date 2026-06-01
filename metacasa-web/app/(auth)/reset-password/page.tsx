import type { Metadata } from "next";
import { UpdatePasswordForm } from "@/components/auth/update-password-form";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("auth.metaReset") };
}

export default function ResetPasswordPage() {
  return <UpdatePasswordForm />;
}
