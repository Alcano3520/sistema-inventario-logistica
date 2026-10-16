-- Foto de producto (Barcos/Motos) + bucket público para servirla sin URLs
-- firmadas (a diferencia de inv-firmas, que es privado).

alter table inv_productos add column if not exists foto_url text;
alter table inv_motos_productos add column if not exists foto_url text;

insert into storage.buckets (id, name, public)
values ('inv-productos-fotos', 'inv-productos-fotos', true)
on conflict (id) do nothing;

create policy inv_productos_fotos_insert on storage.objects for insert
  with check (bucket_id = 'inv-productos-fotos' and inv_is_active_user());
create policy inv_productos_fotos_select on storage.objects for select
  using (bucket_id = 'inv-productos-fotos');
create policy inv_productos_fotos_admin_update on storage.objects for update
  using (bucket_id = 'inv-productos-fotos' and inv_is_admin());
create policy inv_productos_fotos_admin_delete on storage.objects for delete
  using (bucket_id = 'inv-productos-fotos' and inv_is_admin());
