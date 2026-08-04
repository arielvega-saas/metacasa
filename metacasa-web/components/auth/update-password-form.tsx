"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { toast } from "sonner";
import { CheckCircle2, Loader2, ShieldAlert } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { PasswordInput } from "@/components/ui/password-input";
import { Label } from "@/components/ui/label";
import { useT } from "@/components/i18n/locale-provider";

const MIN_LENGTH = 8;

/** Estado de la pantalla de nueva contraseña. */
type Phase = "checking" | "ready" | "invalid" | "success";

/**
 * Pantalla para fijar una nueva contraseña tras el link de recuperación.
 *
 * Flujo: el link del email pega en `/auth/confirm` (server-side), que verifica
 * el `token_hash` con `verifyOtp({ type: 'recovery' })` y deja la sesión de
 * recovery en cookies — funciona en cualquier dispositivo. De ahí redirige acá.
 *
 * Acá:
 *  - Verificamos que EXISTA una sesión (de recovery) antes de mostrar el form.
 *    Si no hay sesión, o `/auth/confirm` nos mandó con `?error=expired`,
 *    mostramos un estado amigable de "link vencido" con acción de reenvío.
 *  - El form valida (mín. 8 + coincidencia) con errores inline y llama
 *    `updateUser({ password })`, que la sesión de recovery permite.
 *  - En éxito mostramos confirmación inline y redirigimos al dashboard.
 */
export function UpdatePasswordForm({ linkError }: { linkError?: boolean }) {
  const t = useT();
  const router = useRouter();
  const supabase = useRef(createClient()).current;

  const [phase, setPhase] = useState<Phase>(linkError ? "invalid" : "checking");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // Verificar que haya una sesión de recovery al montar. La verificación del
  // link ocurre en el server (`/auth/confirm`), así que la cookie ya debería
  // estar; igual escuchamos PASSWORD_RECOVERY por si el SDK la procesa tarde.
  useEffect(() => {
    if (linkError) return; // ya sabemos que el link falló
    let active = true;

    const { data: sub } = supabase.auth.onAuthStateChange((event, session) => {
      if (!active) return;
      if (event === "PASSWORD_RECOVERY" || session) setPhase("ready");
    });

    supabase.auth.getSession().then(({ data }) => {
      if (!active) return;
      setPhase(data.session ? "ready" : "invalid");
    });

    return () => {
      active = false;
      sub.subscription.unsubscribe();
    };
  }, [supabase, linkError]);

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);

    if (password.length < MIN_LENGTH) {
      setError(t("auth.passwordTooShort"));
      return;
    }
    if (password !== confirm) {
      setError(t("auth.passwordsDontMatch"));
      return;
    }

    setLoading(true);
    const { error: updateError } = await supabase.auth.updateUser({ password });
    setLoading(false);

    if (updateError) {
      // Si la sesión de recovery expiró entre que cargó la página y el submit,
      // tratamos como link inválido (acción clara) en vez de un error opaco.
      if (isAuthSessionError(updateError.message)) {
        setPhase("invalid");
        return;
      }
      setError(updateError.message);
      toast.error(t("auth.updatePasswordErrorTitle"), {
        description: updateError.message,
      });
      return;
    }

    setPhase("success");
    toast.success(t("auth.passwordUpdatedTitle"), {
      description: t("auth.passwordUpdatedDescription"),
    });
    // Antes acá había un `router.push("/dashboard")` inmediato. El reset de contraseña se hace
    // en la web A PROPÓSITO (el link tiene que funcionar cross-device, en un aparato donde la app
    // puede no estar instalada), pero redirigir sin preguntar deja a quien abrió el mail en el
    // teléfono metido en la web, sin señal de que ya puede entrar a la app. Ahora la pantalla de
    // éxito lo dice y el usuario elige.
    router.refresh();
  }

  if (phase === "checking") {
    return (
      <div className="flex flex-col items-center py-10 text-center">
        <Loader2 className="text-primary size-7 animate-spin" />
        <p className="text-text-muted mt-4 text-sm">{t("auth.resetCheckingLink")}</p>
      </div>
    );
  }

  if (phase === "invalid") {
    return (
      <div className="text-center">
        <span className="bg-expense/12 text-expense mx-auto mb-5 flex size-14 items-center justify-center rounded-full">
          <ShieldAlert className="size-7" />
        </span>
        <h2 className="text-2xl font-semibold tracking-tight">
          {t("auth.resetLinkInvalidTitle")}
        </h2>
        <p className="text-text-muted mt-2 text-sm leading-relaxed">
          {t("auth.resetLinkInvalidBody")}
        </p>
        <Button asChild size="lg" className="mt-6 w-full">
          <Link href="/forgot-password">{t("auth.resetRequestNewLink")}</Link>
        </Button>
        <Link
          href="/login"
          className="text-text-muted hover:text-foreground mt-5 inline-block text-sm transition-colors"
        >
          {t("auth.backToLogin")}
        </Link>
      </div>
    );
  }

  if (phase === "success") {
    return (
      <div className="text-center">
        <span className="bg-primary/12 text-primary mx-auto mb-5 flex size-14 items-center justify-center rounded-full">
          <CheckCircle2 className="size-7" />
        </span>
        <h2 className="text-2xl font-semibold tracking-tight">
          {t("auth.resetSuccessTitle")}
        </h2>
        <p className="text-text-muted mt-2 text-sm leading-relaxed">
          {t("auth.resetSuccessBody")}
        </p>
        <Button asChild size="lg" className="mt-6 w-full">
          <Link href="/dashboard">{t("auth.resetSuccessGoWeb")}</Link>
        </Button>
        <p className="text-text-muted mt-5 text-xs leading-relaxed">
          {t("auth.resetSuccessAppHint")}
        </p>
      </div>
    );
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

      <form onSubmit={onSubmit} className="space-y-4" noValidate>
        <div className="space-y-1.5">
          <Label htmlFor="new-password">{t("auth.newPasswordLabel")}</Label>
          <PasswordInput
            id="new-password"
            autoComplete="new-password"
            placeholder={t("auth.passwordMinPlaceholder")}
            value={password}
            onChange={(e) => {
              setPassword(e.target.value);
              if (error) setError(null);
            }}
            aria-invalid={!!error}
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
            onChange={(e) => {
              setConfirm(e.target.value);
              if (error) setError(null);
            }}
            aria-invalid={!!error}
            required
          />
        </div>

        {error && (
          <p role="alert" className="text-expense text-sm">
            {error}
          </p>
        )}

        <Button type="submit" size="lg" className="w-full" disabled={loading}>
          {loading && <Loader2 className="animate-spin" />}
          {t("auth.savePassword")}
        </Button>
      </form>
    </div>
  );
}

/** ¿El error de `updateUser` indica que la sesión de recovery ya no es válida? */
function isAuthSessionError(message: string): boolean {
  const m = message.toLowerCase();
  return (
    m.includes("session") ||
    m.includes("jwt") ||
    m.includes("token") ||
    m.includes("not authenticated") ||
    m.includes("auth session missing")
  );
}
