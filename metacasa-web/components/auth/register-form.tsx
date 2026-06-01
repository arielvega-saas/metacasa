"use client";

import { useState, type FormEvent } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { Loader2, CheckCircle2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PasswordInput } from "@/components/ui/password-input";
import { Label } from "@/components/ui/label";
import { useT } from "@/components/i18n/locale-provider";

export function RegisterForm() {
  const t = useT();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  const supabase = createClient();

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (password.length < 8) {
      toast.error(t("auth.passwordTooShort"));
      return;
    }
    setLoading(true);
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { display_name: name },
        emailRedirectTo: `${window.location.origin}/auth/callback?next=/dashboard`,
      },
    });
    setLoading(false);

    if (error) {
      toast.error(t("auth.registerErrorTitle"), { description: error.message });
      return;
    }

    // Supabase devuelve un user con `identities` vacío cuando el email YA tiene
    // cuenta (protección anti-enumeración). En ese caso NO se creó nada nuevo ni
    // se cambió la contraseña: hay que iniciar sesión o recuperar la contraseña.
    if (data.user && (data.user.identities?.length ?? 0) === 0) {
      toast.error(t("auth.emailTakenTitle"), {
        description: t("auth.emailTakenDescription"),
      });
      return;
    }

    setSent(true);
    toast.success(t("auth.almostThereTitle"), {
      description: t("auth.almostThereDescription"),
    });
  }

  if (sent) {
    const [bodyBefore, bodyAfter] = t("auth.checkEmailBody").split("{email}");
    return (
      <div className="text-center">
        <span className="bg-primary/12 text-primary mx-auto mb-5 flex size-14 items-center justify-center rounded-full">
          <CheckCircle2 className="size-7" />
        </span>
        <h2 className="text-2xl font-semibold tracking-tight">
          {t("auth.checkEmailTitle")}
        </h2>
        <p className="text-text-muted mt-2 text-sm leading-relaxed">
          {bodyBefore}
          <span className="text-foreground font-medium">{email}</span>
          {bodyAfter}
        </p>
        <Link
          href="/login"
          className="text-primary mt-6 inline-block text-sm font-medium hover:underline"
        >
          {t("auth.backToLogin")}
        </Link>
      </div>
    );
  }

  return (
    <div>
      <header className="mb-7">
        <h2 className="text-2xl font-semibold tracking-tight">
          {t("auth.registerTitle")}
        </h2>
        <p className="text-text-muted mt-1.5 text-sm">
          {t("auth.registerSubtitle")}
        </p>
      </header>

      <form onSubmit={onSubmit} className="space-y-4">
        <div className="space-y-1.5">
          <Label htmlFor="name">{t("auth.nameLabel")}</Label>
          <Input
            id="name"
            autoComplete="name"
            placeholder={t("auth.namePlaceholder")}
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
          />
        </div>
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
          <Label htmlFor="password">{t("auth.passwordLabel")}</Label>
          <PasswordInput
            id="password"
            autoComplete="new-password"
            placeholder={t("auth.passwordMinPlaceholder")}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>

        <Button type="submit" size="lg" className="w-full" disabled={loading}>
          {loading && <Loader2 className="animate-spin" />}
          {t("auth.createAccount")}
        </Button>
      </form>

      <p className="text-text-muted mt-7 text-center text-sm">
        {t("auth.haveAccount")}{" "}
        <Link href="/login" className="text-primary font-medium hover:underline">
          {t("auth.signIn")}
        </Link>
      </p>
    </div>
  );
}
