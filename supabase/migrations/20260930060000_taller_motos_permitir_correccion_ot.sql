-- El mecánico puede equivocarse al describir la falla, el kilometraje o
-- incluso la moto al crear la OT. Tanto el encargado de logística como
-- cualquier otro operador con acceso al módulo motos (el bodeguero) deben
-- poder corregir esos datos, no solo el Admin o el mecánico original.

create or replace function inv_is_logistica()
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.inv_perfiles
    where id = auth.uid() and rol = 'Encargado de Logística' and activo = true
  );
$$;

drop policy if exists inv_motos_ot_update on inv_motos_ordenes_trabajo;
create policy inv_motos_ot_update on inv_motos_ordenes_trabajo
for update
using (
  inv_is_admin()
  or inv_is_logistica()
  or (inv_tiene_modulo('motos') and inv_is_active_user())
);
