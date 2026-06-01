"use client";

import { useState, type FormEvent } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { Loader2, MailCheck } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useT } from "@/components/i18n/locale-provider";

export function ForgotPasswordForm() {
  const t = useT();
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  const supabase = createClient();

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback?next=/reset-password`,
    });
    setLoading(false);
    if (error) {
      toast.error(t("auth.forgotErrorTitle"), { description: error.message });
      return;
    }
    setSent(true);
  }

  if (sent) {
    const [bodyBefore, bodyAfter] = t("auth.emailSentBody").split("{email}");
    return (
      <div className="text-center">
        <span className="bg-primary/12 text-primary mx-auto mb-5 flex size-14 items-center justify-center rounded-full">
          <MailCheck className="size-7" />
        </span>
        <h2 className="text-2xl font-semibold tracking-tight">
          {t("auth.emailSentTitle")}
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
          {t("auth.forgotTitle")}
        </h2>
        <p className="text-text-muted mt-1.5 text-sm">
          {t("auth.forgotSubtitle")}
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
        <Button type="submit" size="lg" className="w-full" disabled={loading}>
          {loading && <Loader2 className="animate-spin" />}
          {t("auth.sendLink")}
        </Button>
      </form>

      <p className="text-text-muted mt-7 text-center text-sm">
        <Link href="/login" className="text-primary font-medium hover:underline">
          {t("common.back")}
        </Link>
      </p>
    </div>
  );
}
