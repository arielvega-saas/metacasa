-- Cierra la auto-inscripción en hogares ajenos.
--
-- La policy anterior era:
--   with check (user_id = auth.uid() OR current_user_household_role(household_id) in ('owner','admin'))
--
-- La primera rama no restringía NI `household_id` NI `role`, así que cualquier usuario autenticado
-- podía insertar (household_id = <ajeno>, user_id = él mismo, role = 'owner') y quedar dentro del
-- hogar con permisos de dueño: lectura y escritura de todas las finanzas, y la policy de delete le
-- permitía borrar el hogar entero. Saltea por completo accept_household_invitation(), que sí valida
-- token, expiración y coincidencia de email.
--
-- No es enumerable (hace falta conocer el UUID del hogar), pero un EX-MIEMBRO lo conoce de siempre:
-- ex pareja, roommate al que sacaron del hogar. En una app de finanzas compartidas ese es un modelo
-- de amenaza real, no teórico.
--
-- Verificado antes de aplicar:
--   * public.create_household(...) es SECURITY DEFINER -> sigue pudiendo insertar al owner.
--   * public.accept_household_invitation(...) es SECURITY DEFINER -> las invitaciones siguen andando.
--   * Ni iOS ni la web insertan en household_members directamente (sólo select/update/delete).
-- Por eso quitar la rama de auto-inserción no rompe ningún flujo legítimo.
--
-- Aplicada en prod el 2026-08-01; verificado después: 17 hogares, 0 sin owner.

drop policy if exists "household_members_insert_self_or_admin" on public.household_members;

create policy "household_members_insert_admin_only"
  on public.household_members
  for insert
  to authenticated
  with check (
    app_hidden.current_user_household_role(household_id) in ('owner', 'admin')
  );
