"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { PasswordInput } from "@/components/ui/password-input";
import { Label } from "@/components/ui/label";
import { useT } from "@/components/i18n/locale-provider";

/**
 * Pantalla para fijar una nueva contraseña tras el link de recuperación.
 * El link de "reset password" abre /auth/callback (que establece la sesión de
 * recovery) y redirige acá. Acá llamamos updateUser({ password }).
 */
export function UpdatePasswordForm() {
  const t = useT();
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [loading, setLoading] = useState(false);
  const supabase = createClient();

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (password.length < 8) {
      toast.error(t("auth.passwordTooShort"));
      return;
    }
    if (password !== confirm) {
      toast.error(t("auth.passwordsDontMatch"));
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.updateUser({ password });
    setLoading(false);
    if (error) {
      toast.error(t("auth.updatePasswordErrorTitle"), {
        description: error.message,
      });
      return;
    }
    toast.success(t("auth.passwordUpdatedTitle"), {
      description: t("auth.passwordUpdatedDescription"),
    });
    router.push("/dashboard");
    router.refresh();
  }

  return (
    <div>
      <header className="mb-7">
        <h2 className="text-2xl font-semibold tracking-tight">
          {t("auth.newPasswordTitle")}
        </h2>
        <p className="text-text-muted mt-1.5 text-sm">
          {t("auth.newPasswordSubtitle")}
        </p>
      </header>

      <form onSubmit={onSubmit} className="space-y-4">
        <div className="space-y-1.5">
          <Label htmlFor="new-password">{t("auth.newPasswordLabel")}</Label>
          <PasswordInput
            id="new-password"
            autoComplete="new-password"
            placeholder={t("auth.passwordMinPlaceholder")}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="confirm-password">{t("auth.repeatPasswordLabel")}</Label>
          <PasswordInput
            id="confirm-password"
            autoComplete="new-password"
            placeholder={t("auth.passwordPlaceholder")}
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            required
          />
        </div>
        <Button type="submit" size="lg" className="w-full" disabled={loading}>
          {loading && <Loader2 className="animate-spin" />}
          {t("auth.savePassword")}
        </Button>
      </form>
    </div>
  );
}
