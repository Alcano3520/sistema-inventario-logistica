-- Cualquier usuario activo con acceso al módulo (bodeguero, logística,
-- admin) puede ingresar/registrar productos nuevos — el único que NO puede
-- es el Mecánico, que solo debe poder crear pedidos (OT), no tocar el
-- catálogo de productos.

create or replace function inv_puede_editar_productos(p_modulo text)
returns boolean
language sql
security definer
stable
as $$
  select
    inv_is_admin()
    or inv_is_logistica()
    or (
      inv_is_active_user()
      and inv_tiene_modulo(p_modulo)
      and coalesce((select oficio from public.inv_perfiles where id = auth.uid()), '') <> 'Mecánico'
    );
$$;

drop policy if exists inv_productos_admin_insert on inv_productos;
create policy inv_productos_insert on inv_productos for insert
  with check (inv_puede_editar_productos('barcos'));

drop policy if exists inv_motos_productos_admin_insert on inv_motos_productos;
create policy inv_motos_productos_insert on inv_motos_productos for insert
  with check (inv_puede_editar_productos('motos'));
