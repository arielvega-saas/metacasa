"use client";

import { useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PasswordInput } from "@/components/ui/password-input";
import { Label } from "@/components/ui/label";
import { useT } from "@/components/i18n/locale-provider";

export function LoginForm() {
  const t = useT();
  const router = useRouter();
  const params = useSearchParams();
  const rawReturnTo = params.get("returnTo") || "/dashboard";
  // Evitar open-redirect: solo rutas internas (no "//host" ni URLs absolutas).
  const returnTo =
    rawReturnTo.startsWith("/") && !rawReturnTo.startsWith("//")
      ? rawReturnTo
      : "/dashboard";

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const supabase = createClient();

  // El texto de ayuda incrusta un fragmento con estilo donde va {path}.
  const [helpBefore, helpAfter] = t("auth.loginHelp").split("{path}");

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);

    if (error) {
      toast.error(t("auth.loginErrorTitle"), { description: error.message });
      return;
    }
    toast.success(t("auth.loginSuccess"));
    router.push(returnTo);
    router.refresh();
  }

  return (
    <div>
      <header className="mb-7">
        <h2 className="text-2xl font-semibold tracking-tight">
          {t("auth.loginTitle")}
        </h2>
        <p className="text-text-muted mt-1.5 text-sm">
          {t("auth.loginSubtitle")}
        </p>
      </header>

      <form onSubmit={onSubmit} className="space-y-4">
        <div className="space-y-1.5">
          <Label htmlFor="email">{t("auth.emailLabel")}</Label>
          <Input
            id="email"
            type="email"
            inputMode="email"
            autoComplete="email"
            placeholder={t("auth.emailPlaceholder")}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>

        <div className="space-y-1.5">
          <div className="flex items-center justify-between">
            <Label htmlFor="password">{t("auth.passwordLabel")}</Label>
            <Link
              href="/forgot-password"
              className="text-text-muted hover:text-foreground text-xs transition-colors"
            >
              {t("auth.forgotLink")}
            </Link>
          </div>
          <PasswordInput
            id="password"
            autoComplete="current-password"
            placeholder={t("auth.passwordPlaceholder")}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>

        <Button type="submit" size="lg" className="w-full" disabled={loading}>
          {loading && <Loader2 className="animate-spin" />}
          {t("auth.signIn")}
        </Button>
      </form>

      <p className="text-text-dim mt-6 text-center text-xs leading-relaxed">
        {helpBefore}
        <span className="text-text-muted">{t("auth.loginHelpPath")}</span>
        {helpAfter}
      </p>

      <p className="text-text-muted mt-6 text-center text-sm">
        {t("auth.noAccount")}{" "}
        <Link href="/register" className="text-primary font-medium hover:underline">
          {t("auth.createFree")}
        </Link>
      </p>
    </div>
  );
}
