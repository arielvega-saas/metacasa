-- Migration: rpc_accept_household_invitation
-- Aplicada: 2026-04-19
--
-- RPC para aceptar una invitación de hogar via token.
-- Usado por el cliente iOS (y futuro Android) en CreateJoinHouseholdView.
-- Valida que el token esté pending y no expirado, agrega al caller como miembro,
-- y marca la invitación como accepted.

create or replace function public.accept_household_invitation(invite_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  inv record;
  caller uuid;
  caller_email text;
begin
  caller := auth.uid();
  if caller is null then
    raise exception 'not_authenticated';
  end if;

  select email into caller_email from auth.users where id = caller;

  select * into inv
  from public.household_invitations
  where public.household_invitations.invite_token = accept_household_invitation.invite_token
    and status = 'pending'
  for update;

  if not found then
    raise exception 'invitation_not_found';
  end if;

  if inv.expires_at < now() then
    update public.household_invitations set status = 'expired' where id = inv.id;
    raise exception 'invitation_expired';
  end if;

  if inv.email is not null and inv.email <> '' and lower(inv.email) <> lower(coalesce(caller_email, '')) then
    raise exception 'email_mismatch';
  end if;

  insert into public.household_members (household_id, user_id, role, invited_by)
  values (inv.household_id, caller, inv.role, inv.invited_by)
  on conflict (household_id, user_id) do nothing;

  update public.household_invitations
  set status = 'accepted',
      accepted_at = now(),
      accepted_by = caller
  where id = inv.id;

  return inv.household_id;
end;
$$;

revoke all on function public.accept_household_invitation(text) from public, anon;
grant execute on function public.accept_household_invitation(text) to authenticated;

comment on function public.accept_household_invitation(text) is
  'Acepta una invitacion por token. Llamado desde cliente (iOS/Android/PWA) via RPC.';
