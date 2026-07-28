"use client";

import { useEffect, useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Crown,
  Loader2,
  LogOut,
  Mail,
  Plus,
  Sparkles,
  Trash2,
  UserCircle2,
  Users,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { SectionHeader } from "@/components/finance/section-header";
import { ManageSubscriptionCTA } from "@/components/app-links/manage-subscription-cta";
import {
  useAmountsHidden,
  setAmountsHidden,
} from "@/components/finance/amounts-visibility";
import { SUPPORTED_CURRENCIES } from "@/lib/constants";
import { signOut } from "@/lib/actions/auth";
import {
  createInvitation,
  updateHouseholdSettings,
  updateProfileName,
  updateMemberRole,
  removeMember,
} from "@/lib/actions/profile";
import type { Tables } from "@/lib/database.types";
import type { WebAccess } from "@/lib/access";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import { setLocale } from "@/lib/actions/i18n";
import { LOCALE_LABEL, LOCALES, type Locale } from "@/lib/i18n/config";
import { ThemeToggle } from "@/components/profile/theme-toggle";
import type { Theme } from "@/lib/theme";

interface Props {
  email: string;
  displayName: string;
  household: { id: string; name: string; defaultCurrency: string };
  members: Tables<"household_members">[];
  invitations: Tables<"household_invitations">[];
  /** Id del usuario actual: gobierna qué controles de miembro se muestran. */
  currentUserId: string;
  access: WebAccess;
  trialDaysLeft: number;
  /** Preferencia de tema vigente (cookie `mc_theme`). */
  theme: Theme;
}

export function ProfileTabs(props: Props) {
  const t = useT();
  return (
    <Tabs defaultValue="perfil">
      <TabsList className="flex w-full sm:w-auto">
        <TabsTrigger value="perfil" className="flex-1 sm:flex-none">
          {t("profile.tabProfile")}
        </TabsTrigger>
        <TabsTrigger value="hogar" className="flex-1 sm:flex-none">
          {t("profile.tabHousehold")}
        </TabsTrigger>
        <TabsTrigger value="preferencias" className="flex-1 sm:flex-none">
          {t("profile.tabPreferences")}
        </TabsTrigger>
        <TabsTrigger value="plan" className="flex-1 sm:flex-none">
          {t("profile.tabPlan")}
        </TabsTrigger>
      </TabsList>

      <TabsContent value="perfil">
        <PerfilTab email={props.email} displayName={props.displayName} />
      </TabsContent>
      <TabsContent value="hogar">
        <HogarTab
          household={props.household}
          members={props.members}
          invitations={props.invitations}
          currentUserId={props.currentUserId}
        />
      </TabsContent>
      <TabsContent value="preferencias">
        <PreferenciasTab theme={props.theme} />
      </TabsContent>
      <TabsContent value="plan">
        <PlanTab access={props.access} trialDaysLeft={props.trialDaysLeft} />
      </TabsContent>
    </Tabs>
  );
}

/* ------------------------------- Perfil ------------------------------- */

function PerfilTab({
  email,
  displayName,
}: {
  email: string;
  displayName: string;
}) {
  const t = useT();
  const router = useRouter();
  const [name, setName] = useState(displayName);
  const [pending, startTransition] = useTransition();
  const dirty = name.trim() !== displayName.trim();

  function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    startTransition(async () => {
      try {
        await updateProfileName(name);
        toast.success(t("profile.profileUpdated"));
        router.refresh();
      } catch (err) {
        toast.error(t("profile.profileUpdateError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Card className="max-w-xl p-5 sm:p-6">
      <SectionHeader
        title={t("profile.yourProfileTitle")}
        subtitle={t("profile.yourProfileSubtitle")}
      />
      <form onSubmit={onSubmit} className="space-y-4">
        <div className="space-y-1.5">
          <Label htmlFor="display-name">{t("profile.nameLabel")}</Label>
          <Input
            id="display-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder={t("profile.namePlaceholder")}
            maxLength={60}
            required
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="email">{t("profile.emailLabel")}</Label>
          <div className="bg-inset hairline flex h-11 items-center gap-2 rounded-[var(--radius-md)] px-3.5 text-sm text-text-muted">
            <Mail className="size-4 shrink-0" />
            <span className="truncate">{email}</span>
          </div>
          <p className="text-text-dim text-xs">
            {t("profile.emailHint")}
          </p>
        </div>
        <Button type="submit" disabled={pending || !dirty}>
          {pending && <Loader2 className="animate-spin" />}
          {t("common.saveChanges")}
        </Button>
      </form>
    </Card>
  );
}

/* -------------------------------- Hogar ------------------------------- */

function HogarTab({
  household,
  members,
  invitations,
  currentUserId,
}: {
  household: Props["household"];
  members: Props["members"];
  invitations: Props["invitations"];
  currentUserId: string;
}) {
  const t = useT();
  const router = useRouter();
  const [name, setName] = useState(household.name);
  const [currency, setCurrency] = useState(household.defaultCurrency);
  const [savingHh, startSaveHh] = useTransition();

  // Invitación
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteRole, setInviteRole] = useState("member");
  const [inviting, startInvite] = useTransition();

  // Gestión de miembros: el usuario actual solo puede administrar si es
  // owner/admin (mismo criterio que los guards server-side + RLS).
  const myRole = members.find((m) => m.user_id === currentUserId)?.role;
  const canManage = myRole === "owner" || myRole === "admin";
  const [memberToRemove, setMemberToRemove] =
    useState<Props["members"][number] | null>(null);

  const hhDirty =
    name.trim() !== household.name.trim() ||
    currency !== household.defaultCurrency;

  function saveHousehold(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    startSaveHh(async () => {
      try {
        await updateHouseholdSettings({
          householdId: household.id,
          name,
          defaultCurrency: currency,
        });
        toast.success(t("profile.householdUpdated"));
        router.refresh();
      } catch (err) {
        toast.error(t("profile.householdUpdateError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  function sendInvite(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    startInvite(async () => {
      try {
        await createInvitation({
          householdId: household.id,
          email: inviteEmail,
          role: inviteRole,
        });
        toast.success(t("profile.invitationSent"), {
          description: t("profile.invitationSentDesc", {
            email: inviteEmail.trim().toLowerCase(),
          }),
        });
        setInviteEmail("");
        router.refresh();
      } catch (err) {
        toast.error(t("profile.inviteError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      {/* Ajustes del hogar */}
      <Card className="p-5 sm:p-6">
        <SectionHeader
          title={t("profile.householdSettingsTitle")}
          subtitle={t("profile.householdSettingsSubtitle")}
        />
        <form onSubmit={saveHousehold} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="hh-name">{t("profile.householdNameLabel")}</Label>
            <Input
              id="hh-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder={t("profile.householdNamePlaceholder")}
              maxLength={60}
              required
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="hh-currency">{t("profile.currencyLabel")}</Label>
            <Select value={currency} onValueChange={setCurrency}>
              <SelectTrigger id="hh-currency">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {SUPPORTED_CURRENCIES.map((c) => (
                  <SelectItem key={c.code} value={c.code}>
                    {c.code} — {t(`domain.currencies.${c.code}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-text-dim text-xs">
              {t("profile.currencyHint")}
            </p>
          </div>
          <Button type="submit" disabled={savingHh || !hhDirty}>
            {savingHh && <Loader2 className="animate-spin" />}
            {t("profile.saveHousehold")}
          </Button>
        </form>
      </Card>

      {/* Miembros + invitaciones */}
      <Card className="p-5 sm:p-6">
        <SectionHeader
          title={t("profile.membersTitle")}
          subtitle={t(
            members.length === 1
              ? "profile.membersCountOne"
              : "profile.membersCountOther",
            { count: members.length },
          )}
        />

        <ul className="divide-y divide-border">
          {members.map((m) => (
            <MemberRow
              key={m.user_id}
              member={m}
              householdId={household.id}
              isSelf={m.user_id === currentUserId}
              canManage={canManage}
              onRemove={() => setMemberToRemove(m)}
            />
          ))}
        </ul>

        {invitations.length > 0 && (
          <>
            <Separator className="my-4" />
            <p className="text-text-muted mb-2 text-xs font-semibold uppercase tracking-wider">
              {t("profile.pendingInvitations")}
            </p>
            <ul className="divide-y divide-border">
              {invitations.map((inv) => (
                <li key={inv.id} className="flex items-center gap-3 py-2.5">
                  <span className="bg-champagne/12 text-champagne flex size-9 items-center justify-center rounded-[var(--radius-md)]">
                    <Mail className="size-[18px]" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">{inv.email}</p>
                    <p className="text-text-dim text-xs">
                      {t(`domain.roles.${inv.role}`)}
                    </p>
                  </div>
                  <Badge variant="warning">{t("profile.statusPending")}</Badge>
                </li>
              ))}
            </ul>
          </>
        )}

        <Separator className="my-4" />

        {/* Invitar por email */}
        <form onSubmit={sendInvite} className="space-y-3">
          <Label htmlFor="invite-email" className="flex items-center gap-1.5">
            <Users className="size-3.5" /> {t("profile.inviteSomeone")}
          </Label>
          <div className="flex flex-col gap-2 sm:flex-row">
            <Input
              id="invite-email"
              type="email"
              inputMode="email"
              autoComplete="off"
              placeholder={t("profile.invitePlaceholder")}
              value={inviteEmail}
              onChange={(e) => setInviteEmail(e.target.value)}
              required
              className="flex-1"
            />
            <Select value={inviteRole} onValueChange={setInviteRole}>
              <SelectTrigger className="sm:w-40">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="member">{t("profile.roleMember")}</SelectItem>
                <SelectItem value="admin">{t("profile.roleAdmin")}</SelectItem>
                <SelectItem value="viewer">{t("profile.roleViewer")}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <Button type="submit" variant="secondary" disabled={inviting}>
            {inviting ? <Loader2 className="animate-spin" /> : <Plus />}
            {t("profile.sendInvitation")}
          </Button>
        </form>
      </Card>

      {/* Confirmación de baja de miembro */}
      {memberToRemove && (
        <RemoveMemberDialog
          open
          onOpenChange={(o) => !o && setMemberToRemove(null)}
          householdId={household.id}
          userId={memberToRemove.user_id}
          name={
            memberToRemove.display_name?.trim() ||
            t("profile.memberFallbackName")
          }
        />
      )}
    </div>
  );
}

/** Roles asignables desde la web (no permitimos crear nuevos "owner" acá). */
const ASSIGNABLE_ROLES = ["admin", "member", "viewer"] as const;

/**
 * Fila de un miembro del hogar. Si el caller es owner/admin, muestra un Select
 * de rol editable + botón de baja; si no, solo el badge de rol (read-only).
 * El propio usuario no se auto-edita el rol ni se quita desde acá.
 */
function MemberRow({
  member,
  householdId,
  isSelf,
  canManage,
  onRemove,
}: {
  member: Tables<"household_members">;
  householdId: string;
  isSelf: boolean;
  canManage: boolean;
  onRemove: () => void;
}) {
  const t = useT();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  // Editable solo si administro y no soy yo mismo. Owners no se degradan desde
  // la web (el Select solo lista admin/member/viewer); si el miembro YA es
  // owner, queda read-only para no romper la protección del último propietario.
  const editable = canManage && !isSelf && member.role !== "owner";
  const removable = canManage && !isSelf && member.role !== "owner";

  function changeRole(role: string) {
    if (role === member.role) return;
    startTransition(async () => {
      try {
        await updateMemberRole({ householdId, userId: member.user_id, role });
        toast.success(t("profile.roleUpdated"));
        router.refresh();
      } catch (err) {
        toast.error(t("profile.roleUpdateError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <li className="flex items-center gap-3 py-2.5">
      <span className="bg-primary/10 text-primary flex size-9 shrink-0 items-center justify-center rounded-[var(--radius-md)]">
        <UserCircle2 className="size-[18px]" />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium">
          {member.display_name?.trim() || t("profile.memberFallbackName")}
          {isSelf && (
            <span className="text-text-dim ml-1.5 font-normal">
              · {t("profile.memberYou")}
            </span>
          )}
        </p>
      </div>

      {editable ? (
        <Select
          value={member.role}
          onValueChange={changeRole}
          disabled={pending}
        >
          <SelectTrigger
            className="h-9 w-36"
            aria-label={t("profile.memberRoleLabel", {
              name: member.display_name?.trim() || t("profile.memberFallbackName"),
            })}
          >
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {ASSIGNABLE_ROLES.map((r) => (
              <SelectItem key={r} value={r}>
                {t(`domain.roles.${r}`)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      ) : (
        <Badge variant={member.role === "owner" ? "default" : "neutral"}>
          {t(`domain.roles.${member.role}`)}
        </Badge>
      )}

      {removable && (
        <Button
          type="button"
          variant="ghost"
          size="icon"
          className="text-text-muted hover:text-expense size-9 min-h-11 min-w-11 shrink-0"
          onClick={onRemove}
          disabled={pending}
          aria-label={t("profile.removeMember")}
        >
          <Trash2 className="size-4" />
        </Button>
      )}
    </li>
  );
}

/** Confirmación de baja de un miembro del hogar. */
function RemoveMemberDialog({
  open,
  onOpenChange,
  householdId,
  userId,
  name,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  householdId: string;
  userId: string;
  name: string;
}) {
  const t = useT();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function onConfirm() {
    startTransition(async () => {
      try {
        await removeMember({ householdId, userId });
        toast.success(t("profile.memberRemoved"));
        // Refrescar ANTES de cerrar: el padre monta este diálogo de forma
        // condicional ({memberToRemove && ...}); cerrar lo desmonta y abortaría
        // el refresh si fuera después. Con este orden la lista de miembros se
        // actualiza sin recargar.
        router.refresh();
        onOpenChange(false);
      } catch (err) {
        toast.error(t("profile.memberRemoveError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t("profile.removeMemberConfirmTitle")}</DialogTitle>
          <DialogDescription>
            {t("profile.removeMemberConfirm", { name })}
          </DialogDescription>
        </DialogHeader>
        <DialogFooter className="pt-2">
          <DialogClose asChild>
            <Button type="button" variant="ghost" disabled={pending}>
              {t("profile.removeMemberCancel")}
            </Button>
          </DialogClose>
          <Button
            type="button"
            variant="destructive"
            onClick={onConfirm}
            disabled={pending}
          >
            {pending && <Loader2 className="animate-spin" />}
            {t("profile.removeMemberAction")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

/* ---------------------------- Preferencias ---------------------------- */

const REDUCE_MOTION_KEY = "mc_pref_reduce_motion";

/** Aplica/quita la preferencia de reducir animaciones en <html>. */
function applyReduceMotion(on: boolean) {
  if (typeof document === "undefined") return;
  if (on) document.documentElement.dataset.reduceMotion = "1";
  else delete document.documentElement.dataset.reduceMotion;
}

function PreferenciasTab({ theme }: { theme: Theme }) {
  const t = useT();
  const currentLocale = useLocale();
  // Reducir-movimiento es preferencia SOLO local (localStorage + <html> attr).
  // Idioma y tema sí se persisten server-side (cookies mc_locale / mc_theme).
  const [reduceMotion, setReduceMotion] = useState(false);
  const [ready, setReady] = useState(false);
  const [savingLocale, startSaveLocale] = useTransition();
  // Ocultar montos vive en un store global (compartido con la topbar).
  const amountsHidden = useAmountsHidden();

  useEffect(() => {
    const rm = localStorage.getItem(REDUCE_MOTION_KEY) === "1";
    setReduceMotion(rm);
    applyReduceMotion(rm);
    setReady(true);
  }, []);

  function changeLocale(v: string) {
    if (v === currentLocale) return;
    startSaveLocale(async () => {
      await setLocale(v);
      toast.success(t("profile.languageChanged"));
    });
  }
  function persistMotion(v: boolean) {
    setReduceMotion(v);
    localStorage.setItem(REDUCE_MOTION_KEY, v ? "1" : "0");
    applyReduceMotion(v);
  }

  return (
    <Card className="max-w-xl p-5 sm:p-6">
      <SectionHeader
        title={t("profile.preferencesTitle")}
        subtitle={t("profile.preferencesSubtitle")}
      />

      <div className="space-y-1">
        {/* Tema — cookie `mc_theme`, aplicado en SSR (sin flash al cargar). */}
        <div className="flex items-center justify-between gap-4 py-3">
          <div className="min-w-0">
            <p className="text-sm font-medium">{t("profile.themeLabel")}</p>
            <p className="text-text-dim text-xs">
              {t("profile.themeHint")}
            </p>
          </div>
          <ThemeToggle value={theme} />
        </div>

        <Separator />

        {/* Idioma — cambia el idioma real de la web (cookie + refresh del layout). */}
        <div className="flex items-center justify-between gap-4 py-3">
          <div className="min-w-0">
            <p className="text-sm font-medium">{t("profile.languageLabel")}</p>
            <p className="text-text-dim text-xs">
              {t("profile.languageHint")}
            </p>
          </div>
          <Select
            value={currentLocale}
            onValueChange={changeLocale}
            disabled={savingLocale}
          >
            <SelectTrigger className="w-40" aria-label={t("profile.languageLabel")}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {LOCALES.map((loc: Locale) => (
                <SelectItem key={loc} value={loc}>
                  {LOCALE_LABEL[loc]}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <Separator />

        {/* Ocultar montos (modo privacidad) — store global compartido con topbar. */}
        <div className="flex items-center justify-between gap-4 py-3">
          <div className="min-w-0">
            <p className="text-sm font-medium">{t("privacy.hideAmounts")}</p>
            <p className="text-text-dim text-xs">
              {t("privacy.hideAmountsHint")}
            </p>
          </div>
          <Switch
            checked={amountsHidden}
            onCheckedChange={setAmountsHidden}
            aria-label={t("privacy.hideAmounts")}
          />
        </div>

        <Separator />

        {/* Reducir movimiento */}
        <div className="flex items-center justify-between gap-4 py-3">
          <div className="min-w-0">
            <p className="text-sm font-medium">{t("profile.reduceMotionLabel")}</p>
            <p className="text-text-dim text-xs">
              {t("profile.reduceMotionHint")}
            </p>
          </div>
          <Switch
            checked={reduceMotion}
            onCheckedChange={persistMotion}
            disabled={!ready}
            aria-label={t("profile.reduceMotionLabel")}
          />
        </div>
      </div>
    </Card>
  );
}

/* -------------------------------- Plan -------------------------------- */

function PlanTab({
  access,
  trialDaysLeft,
}: {
  access: WebAccess;
  trialDaysLeft: number;
}) {
  const t = useT();
  const isTrial = access.state === "trial";
  const isActive = access.state === "active";

  return (
    <div className="grid gap-4 lg:grid-cols-[1.4fr_1fr]">
      <Card glass className="sage-glow border-primary/20 p-6">
        <div className="flex items-start justify-between gap-3">
          <div>
            <span className="bg-primary/15 text-primary mb-3 inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wider">
              {isActive ? <Crown className="size-3.5" /> : <Sparkles className="size-3.5" />}
              {isActive
                ? t("profile.planPremium")
                : isTrial
                  ? t("profile.planTrial")
                  : t("profile.planLimited")}
            </span>
            <h2 className="font-num text-2xl text-foreground">
              {isActive
                ? t("profile.planActiveTitle")
                : isTrial
                  ? t(
                      trialDaysLeft === 1
                        ? "profile.planTrialTitleOne"
                        : "profile.planTrialTitleOther",
                      { days: trialDaysLeft },
                    )
                  : t("profile.planExpiredTitle")}
            </h2>
            <p className="text-text-muted mt-1.5 text-sm">
              {isActive
                ? t("profile.planActiveDesc")
                : isTrial
                  ? t("profile.planTrialDesc")
                  : t("profile.planExpiredDesc")}
            </p>
          </div>
        </div>

        <Separator className="my-5" />

        <ul className="space-y-2.5 text-sm">
          {[
            t("profile.featUnlimitedHouseholds"),
            t("profile.featEnvelopesGoals"),
            t("profile.featAdvancedReports"),
            t("profile.featRealtimeSync"),
          ].map((feat) => (
            <li key={feat} className="flex items-center gap-2.5 text-text-muted">
              <span className="bg-income/15 text-income flex size-5 items-center justify-center rounded-full">
                <Sparkles className="size-3" />
              </span>
              {feat}
            </li>
          ))}
        </ul>
      </Card>

      <Card className="flex flex-col justify-between p-6">
        <div>
          <SectionHeader
            title={t("profile.subscriptionTitle")}
            subtitle={t("profile.subscriptionSubtitle")}
          />
          <p className="text-text-muted text-sm leading-relaxed">
            {t("profile.subscriptionBody")}
          </p>
        </div>

        <div className="mt-6 space-y-3">
          <ManageSubscriptionCTA />
          <LogoutButton />
        </div>
      </Card>
    </div>
  );
}

function LogoutButton() {
  const t = useT();
  const [pending, startTransition] = useTransition();
  return (
    <Button
      type="button"
      variant="outline"
      size="lg"
      className="w-full"
      disabled={pending}
      onClick={() => startTransition(() => signOut())}
    >
      {pending ? <Loader2 className="animate-spin" /> : <LogOut />}
      {t("profile.signOut")}
    </Button>
  );
}
