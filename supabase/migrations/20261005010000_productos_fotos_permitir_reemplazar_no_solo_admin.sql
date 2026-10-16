-- Subir una foto nueva (INSERT) ya estaba abierto a cualquier usuario
-- activo. Pero el cliente sube con upsert:true, así que REEMPLAZAR una
-- foto que ya existe pasa por UPDATE en storage — eso sí estaba limitado
-- a Admin. Mismo criterio que el resto de productos: cualquiera activo
-- salvo el Mecánico.

drop policy if exists inv_productos_fotos_admin_update on storage.objects;
create policy inv_productos_fotos_update on storage.objects for update
  using (
    bucket_id = 'inv-productos-fotos'
    and inv_is_active_user()
    and coalesce((select oficio from public.inv_perfiles where id = auth.uid()), '') <> 'Mecánico'
  );
