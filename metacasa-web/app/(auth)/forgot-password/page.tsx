import type { Metadata } from "next";
import { ForgotPasswordForm } from "@/components/auth/forgot-password-form";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("auth.metaForgot") };
}

export default function ForgotPasswordPage() {
  return <ForgotPasswordForm />;
}
