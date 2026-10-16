-- Igual que con INSERT: editar un producto existente (agregar/cambiar su
-- foto, corregir categoría/ubicación, etc.) debe poder hacerlo cualquiera
-- activo con acceso al módulo, salvo el Mecánico.

drop policy if exists inv_productos_admin_update on inv_productos;
create policy inv_productos_update on inv_productos for update
  using (inv_puede_editar_productos('barcos'))
  with check (inv_puede_editar_productos('barcos'));

drop policy if exists inv_motos_productos_admin_update on inv_motos_productos;
create policy inv_motos_productos_update on inv_motos_productos for update
  using (inv_puede_editar_productos('motos'))
  with check (inv_puede_editar_productos('motos'));
