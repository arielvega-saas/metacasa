import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listInvitations, listMembers } from "@/lib/db/household-members";
import { getAccessState, daysUntil } from "@/lib/access";
import { getT } from "@/lib/i18n/server";
import { PageHeader } from "@/components/layout/page-header";
import { ProfileTabs } from "@/components/profile/profile-tabs";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("profile.title") };
}

/** Perfil y configuración del usuario + hogar activo. */
export default async function ProfilePage() {
  const supabase = await createClient();
  const t = await getT();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return <p className="text-text-muted">{t("profile.noHousehold")}</p>;
  }

  const [members, invitations, access] = await Promise.all([
    listMembers(supabase, active.id),
    listInvitations(supabase, active.id),
    getAccessState(),
  ]);

  const displayName =
    (user?.user_metadata?.display_name as string) ||
    user?.email?.split("@")[0] ||
    "";

  return (
    <div>
      <PageHeader
        title={t("profile.title")}
        description={t("profile.description")}
      />
      <ProfileTabs
        email={user?.email ?? ""}
        displayName={displayName}
        household={{
          id: active.id,
          name: active.name,
          defaultCurrency: active.default_currency,
        }}
        members={members}
        invitations={invitations}
        currentUserId={user?.id ?? ""}
        access={access}
        trialDaysLeft={daysUntil(access.trial_ends_at)}
      />
    </div>
  );
}
