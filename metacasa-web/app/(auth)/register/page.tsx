import type { Metadata } from "next";
import { RegisterForm } from "@/components/auth/register-form";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("auth.metaRegister") };
}

export default function RegisterPage() {
  return <RegisterForm />;
}
