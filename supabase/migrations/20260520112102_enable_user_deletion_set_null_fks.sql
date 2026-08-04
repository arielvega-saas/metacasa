-- Apple App Store Guideline 5.1.1(v): apps con creación de cuenta deben permitir
-- delete in-app. Para que auth.admin.deleteUser() funcione sin bloquearse en FKs
-- históricos, convertimos las columnas `created_by`/`owner_user_id`/etc en
-- nullable + ON DELETE SET NULL. Preservamos el dato histórico (transacción,
-- household) y solo perdemos el puntero al usuario eliminado.
--
-- household_members.user_id ya tiene ON DELETE CASCADE → la membresía se borra
-- al eliminar el user, lo que efectivamente lo saca del hogar. Si era el único
-- miembro, el household queda sin members → invisible vía RLS.

-- households.created_by (RESTRICT → SET NULL)
ALTER TABLE public.households ALTER COLUMN created_by DROP NOT NULL;
ALTER TABLE public.households DROP CONSTRAINT households_created_by_fkey;
ALTER TABLE public.households
  ADD CONSTRAINT households_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- accounts.created_by (NO ACTION → SET NULL)
ALTER TABLE public.accounts ALTER COLUMN created_by DROP NOT NULL;
ALTER TABLE public.accounts DROP CONSTRAINT accounts_created_by_fkey;
ALTER TABLE public.accounts
  ADD CONSTRAINT accounts_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- accounts.owner_user_id (nullable, NO ACTION → SET NULL)
ALTER TABLE public.accounts DROP CONSTRAINT accounts_owner_user_id_fkey;
ALTER TABLE public.accounts
  ADD CONSTRAINT accounts_owner_user_id_fkey
  FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- debts.created_by (NO ACTION → SET NULL)
ALTER TABLE public.debts ALTER COLUMN created_by DROP NOT NULL;
ALTER TABLE public.debts DROP CONSTRAINT debts_created_by_fkey;
ALTER TABLE public.debts
  ADD CONSTRAINT debts_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- goal_contributions.contributed_by (NO ACTION → SET NULL)
ALTER TABLE public.goal_contributions ALTER COLUMN contributed_by DROP NOT NULL;
ALTER TABLE public.goal_contributions DROP CONSTRAINT goal_contributions_contributed_by_fkey;
ALTER TABLE public.goal_contributions
  ADD CONSTRAINT goal_contributions_contributed_by_fkey
  FOREIGN KEY (contributed_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- goals.created_by (NO ACTION → SET NULL)
ALTER TABLE public.goals ALTER COLUMN created_by DROP NOT NULL;
ALTER TABLE public.goals DROP CONSTRAINT goals_created_by_fkey;
ALTER TABLE public.goals
  ADD CONSTRAINT goals_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- household_invitations.accepted_by (nullable, NO ACTION → SET NULL)
ALTER TABLE public.household_invitations DROP CONSTRAINT household_invitations_accepted_by_fkey;
ALTER TABLE public.household_invitations
  ADD CONSTRAINT household_invitations_accepted_by_fkey
  FOREIGN KEY (accepted_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- household_members.invited_by (nullable, NO ACTION → SET NULL)
ALTER TABLE public.household_members DROP CONSTRAINT household_members_invited_by_fkey;
ALTER TABLE public.household_members
  ADD CONSTRAINT household_members_invited_by_fkey
  FOREIGN KEY (invited_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- installment_plans.created_by (NO ACTION → SET NULL)
ALTER TABLE public.installment_plans ALTER COLUMN created_by DROP NOT NULL;
ALTER TABLE public.installment_plans DROP CONSTRAINT installment_plans_created_by_fkey;
ALTER TABLE public.installment_plans
  ADD CONSTRAINT installment_plans_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- transaction_templates.created_by (NO ACTION → SET NULL)
ALTER TABLE public.transaction_templates ALTER COLUMN created_by DROP NOT NULL;
ALTER TABLE public.transaction_templates DROP CONSTRAINT transaction_templates_created_by_fkey;
ALTER TABLE public.transaction_templates
  ADD CONSTRAINT transaction_templates_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
