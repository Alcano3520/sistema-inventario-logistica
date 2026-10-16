-- Módulo "PRUEBAS": una copia funcional e independiente de Barcos/Motos
-- (mismas pantallas de Productos/Entrada/Salida/Inventario/Historial, tablas
-- propias con prefijo inv_pruebas_*) para que el equipo pueda ensayar
-- ingresos, salidas, lectura de factura PDF, etc. sin tocar datos reales.
-- Se agrega con un poco de data de muestra ya cargada para probar de una.

create table public.inv_pruebas_productos (
  cod text primary key,
  producto text not null,
  entrada numeric not null default 0,
  salida numeric not null default 0,
  stock numeric not null default 0,
  categoria text not null default '',
  ubicacion text not null default '',
  stock_minimo numeric not null default 5,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foto_url text,
  codigo_barras text
);

create unique index idx_inv_pruebas_productos_codigo_barras
  on public.inv_pruebas_productos (codigo_barras) where (codigo_barras is not null);
create index inv_pruebas_productos_producto_trgm on public.inv_pruebas_productos using gin (producto gin_trgm_ops);
create index inv_pruebas_productos_cod_trgm on public.inv_pruebas_productos using gin (cod gin_trgm_ops);

create trigger inv_pruebas_productos_updated_at
  before update on public.inv_pruebas_productos
  for each row execute function public.inv_set_updated_at();

create table public.inv_pruebas_transacciones_entrada (
  id_transaccion text primary key default (('PRU-ENT-'::text || to_char(now(), 'YYYYMMDDHH24MISS'::text)) || '-'::text) || substr(md5((random())::text), 1, 6),
  fecha_hora timestamptz not null default now(),
  proveedor text not null default '',
  num_factura text not null default '',
  usuario_id uuid not null references auth.users(id),
  usuario_nombre text not null,
  observaciones text not null default '',
  firma_url text,
  clave_acceso_sri text,
  foto_factura_url text,
  created_at timestamptz not null default now()
);

create table public.inv_pruebas_detalle_entradas (
  id bigint generated always as identity primary key,
  id_transaccion text not null references public.inv_pruebas_transacciones_entrada(id_transaccion) on delete cascade,
  cod text not null,
  producto text not null,
  cantidad numeric not null check (cantidad > 0),
  precio_unitario numeric
);
create index inv_pruebas_detalle_entradas_trans_idx on public.inv_pruebas_detalle_entradas (id_transaccion);

create table public.inv_pruebas_transacciones_salida (
  id_transaccion text primary key default (('PRU-SAL-'::text || to_char(now(), 'YYYYMMDDHH24MISS'::text)) || '-'::text) || substr(md5((random())::text), 1, 6),
  fecha_hora timestamptz not null default now(),
  bote text not null default '',
  a_quien_entrega text not null,
  proposito text not null default '',
  usuario_id uuid not null references auth.users(id),
  usuario_nombre text not null,
  firma_url text,
  peticion_texto text,
  peticion_foto_url text,
  created_at timestamptz not null default now()
);

create table public.inv_pruebas_detalle_salidas (
  id bigint generated always as identity primary key,
  id_transaccion text not null references public.inv_pruebas_transacciones_salida(id_transaccion) on delete cascade,
  cod text not null,
  producto text not null,
  cantidad numeric not null check (cantidad > 0)
);
create index inv_pruebas_detalle_salidas_trans_idx on public.inv_pruebas_detalle_salidas (id_transaccion);

-- Triggers de stock (mismo comportamiento que Barcos/Motos, contra las
-- tablas de Pruebas).
create or replace function public.inv_pruebas_detalle_entrada_apply()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  insert into public.inv_pruebas_productos (cod, producto, entrada, stock)
  values (new.cod, new.producto, new.cantidad, new.cantidad)
  on conflict (cod) do update
    set entrada = public.inv_pruebas_productos.entrada + excluded.entrada,
        stock = public.inv_pruebas_productos.stock + excluded.entrada;
  return new;
end;
$function$;

create trigger inv_pruebas_detalle_entrada_apply_trg
  after insert on public.inv_pruebas_detalle_entradas
  for each row execute function public.inv_pruebas_detalle_entrada_apply();

create or replace function public.inv_pruebas_detalle_salida_apply()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_stock numeric;
begin
  select stock into v_stock from public.inv_pruebas_productos where cod = new.cod for update;

  if v_stock is null then
    raise exception 'Producto con código % no encontrado', new.cod;
  end if;

  if v_stock < new.cantidad then
    raise exception 'Stock insuficiente para %. Stock actual: %', new.producto, v_stock;
  end if;

  update public.inv_pruebas_productos
    set salida = salida + new.cantidad,
        stock = stock - new.cantidad
    where cod = new.cod;

  return new;
end;
$function$;

create trigger inv_pruebas_detalle_salida_apply_trg
  after insert on public.inv_pruebas_detalle_salidas
  for each row execute function public.inv_pruebas_detalle_salida_apply();

-- RPCs de duplicados/recalculo (misma lógica que Barcos/Motos).
create or replace function public.inv_pruebas_detectar_duplicados()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  resultado jsonb;
begin
  if not public.inv_is_admin() then
    raise exception 'Acceso denegado. Solo administradores.';
  end if;

  select jsonb_build_object(
    'entradas_duplicadas', coalesce((
      select jsonb_agg(jsonb_build_object('clave', clave, 'cantidad', cantidad, 'ids', ids))
      from (
        select
          lower(coalesce(proveedor,'') || '_' || fecha_hora::text || '_' || coalesce(num_factura,'')) as clave,
          count(*) as cantidad,
          array_agg(id_transaccion order by created_at) as ids
        from public.inv_pruebas_transacciones_entrada
        group by 1
        having count(*) > 1
      ) g
    ), '[]'::jsonb),
    'salidas_duplicadas', coalesce((
      select jsonb_agg(jsonb_build_object('clave', clave, 'cantidad', cantidad, 'ids', ids))
      from (
        select
          lower(coalesce(a_quien_entrega,'') || '_' || fecha_hora::text || '_' || coalesce(bote,'')) as clave,
          count(*) as cantidad,
          array_agg(id_transaccion order by created_at) as ids
        from public.inv_pruebas_transacciones_salida
        group by 1
        having count(*) > 1
      ) g
    ), '[]'::jsonb)
  ) into resultado;

  return resultado;
end;
$function$;

create or replace function public.inv_pruebas_eliminar_duplicados()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  duplicados jsonb;
  entradas_eliminadas int := 0;
  salidas_eliminadas int := 0;
  filas_afectadas int;
  grupo jsonb;
  ids text[];
begin
  if not public.inv_is_admin() then
    raise exception 'Acceso denegado. Solo administradores.';
  end if;

  duplicados := public.inv_pruebas_detectar_duplicados();

  for grupo in select * from jsonb_array_elements(duplicados->'entradas_duplicadas')
  loop
    ids := array(select jsonb_array_elements_text(grupo->'ids'));
    delete from public.inv_pruebas_transacciones_entrada
    where id_transaccion = any(ids[2:array_length(ids,1)]);
    get diagnostics filas_afectadas = row_count;
    entradas_eliminadas := entradas_eliminadas + filas_afectadas;
  end loop;

  for grupo in select * from jsonb_array_elements(duplicados->'salidas_duplicadas')
  loop
    ids := array(select jsonb_array_elements_text(grupo->'ids'));
    delete from public.inv_pruebas_transacciones_salida
    where id_transaccion = any(ids[2:array_length(ids,1)]);
    get diagnostics filas_afectadas = row_count;
    salidas_eliminadas := salidas_eliminadas + filas_afectadas;
  end loop;

  perform public.inv_pruebas_recalcular_stocks();

  return jsonb_build_object(
    'entradas_eliminadas', entradas_eliminadas,
    'salidas_eliminadas', salidas_eliminadas
  );
end;
$function$;

create or replace function public.inv_pruebas_recalcular_stocks()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  productos_actualizados int;
begin
  if not public.inv_is_admin() then
    raise exception 'Acceso denegado. Solo administradores.';
  end if;

  insert into public.inv_pruebas_productos (cod, producto)
  select distinct d.cod, d.producto
  from public.inv_pruebas_detalle_entradas d
  left join public.inv_pruebas_productos p on p.cod = d.cod
  where p.cod is null
  on conflict (cod) do nothing;

  insert into public.inv_pruebas_productos (cod, producto)
  select distinct d.cod, d.producto
  from public.inv_pruebas_detalle_salidas d
  left join public.inv_pruebas_productos p on p.cod = d.cod
  where p.cod is null
  on conflict (cod) do nothing;

  update public.inv_pruebas_productos set entrada = 0, salida = 0, stock = 0 where cod is not null;

  update public.inv_pruebas_productos p
  set entrada = t.total, stock = p.stock + t.total
  from (select cod, sum(cantidad) as total from public.inv_pruebas_detalle_entradas group by cod) t
  where t.cod = p.cod;

  update public.inv_pruebas_productos p
  set salida = t.total, stock = p.stock - t.total
  from (select cod, sum(cantidad) as total from public.inv_pruebas_detalle_salidas group by cod) t
  where t.cod = p.cod;

  select count(*) into productos_actualizados from public.inv_pruebas_productos;

  return jsonb_build_object('productos_actualizados', productos_actualizados);
end;
$function$;

-- RLS: mismo esquema que Barcos/Motos.
alter table public.inv_pruebas_productos enable row level security;
alter table public.inv_pruebas_transacciones_entrada enable row level security;
alter table public.inv_pruebas_detalle_entradas enable row level security;
alter table public.inv_pruebas_transacciones_salida enable row level security;
alter table public.inv_pruebas_detalle_salidas enable row level security;

create policy inv_pruebas_productos_select on public.inv_pruebas_productos
  for select using (inv_is_active_user());
create policy inv_pruebas_productos_insert on public.inv_pruebas_productos
  for insert with check (inv_puede_editar_productos('pruebas'));
create policy inv_pruebas_productos_update on public.inv_pruebas_productos
  for update using (inv_puede_editar_productos('pruebas')) with check (inv_puede_editar_productos('pruebas'));
create policy inv_pruebas_productos_admin_delete on public.inv_pruebas_productos
  for delete using (inv_is_admin());

create policy inv_pruebas_trans_entrada_select on public.inv_pruebas_transacciones_entrada
  for select using (inv_is_active_user());
create policy inv_pruebas_trans_entrada_insert on public.inv_pruebas_transacciones_entrada
  for insert with check (inv_is_active_user() and usuario_id = auth.uid());

create policy inv_pruebas_detalle_entrada_select on public.inv_pruebas_detalle_entradas
  for select using (inv_is_active_user());
create policy inv_pruebas_detalle_entrada_insert on public.inv_pruebas_detalle_entradas
  for insert with check (inv_is_active_user());

create policy inv_pruebas_trans_salida_select on public.inv_pruebas_transacciones_salida
  for select using (inv_is_active_user());
create policy inv_pruebas_trans_salida_insert on public.inv_pruebas_transacciones_salida
  for insert with check (inv_is_active_user() and usuario_id = auth.uid());

create policy inv_pruebas_detalle_salida_select on public.inv_pruebas_detalle_salidas
  for select using (inv_is_active_user());
create policy inv_pruebas_detalle_salida_insert on public.inv_pruebas_detalle_salidas
  for insert with check (inv_is_active_user());

-- Data de muestra para poder probar de una: productos + un par de entradas
-- y una salida, todo bajo el prefijo PRU- para distinguirlo a simple vista
-- de datos reales.
insert into public.inv_pruebas_productos (cod, producto, categoria, ubicacion, stock_minimo) values
  ('PRU-001', 'Producto de prueba A — tornillos', 'Ferretería', 'Bodega Pruebas - Estante 1', 10),
  ('PRU-002', 'Producto de prueba B — manguera', 'Hidráulica', 'Bodega Pruebas - Estante 2', 5),
  ('PRU-003', 'Producto de prueba C — cable eléctrico', 'Eléctrico', 'Bodega Pruebas - Estante 3', 5);

do $$
declare
  v_usuario_id uuid := '3bd84c78-7a09-4e2b-9c7f-096e92d6c1a3';
  v_usuario_nombre text := 'daniel3520';
  v_ent1 text;
  v_ent2 text;
  v_sal1 text;
begin
  insert into public.inv_pruebas_transacciones_entrada
    (proveedor, num_factura, usuario_id, usuario_nombre, observaciones, fecha_hora)
  values
    ('Proveedor de Pruebas S.A.', '001-001-000000001', v_usuario_id, v_usuario_nombre,
     'Entrada de ejemplo para pruebas del sistema.', now() - interval '2 days')
  returning id_transaccion into v_ent1;

  insert into public.inv_pruebas_detalle_entradas (id_transaccion, cod, producto, cantidad, precio_unitario) values
    (v_ent1, 'PRU-001', 'Producto de prueba A — tornillos', 50, 0.25),
    (v_ent1, 'PRU-002', 'Producto de prueba B — manguera', 30, 3.50);

  insert into public.inv_pruebas_transacciones_entrada
    (proveedor, num_factura, usuario_id, usuario_nombre, observaciones, fecha_hora)
  values
    ('Distribuidora Prueba Ltda.', '001-001-000000002', v_usuario_id, v_usuario_nombre,
     'Segunda entrada de ejemplo, para probar que el historial acumula bien.', now() - interval '1 day')
  returning id_transaccion into v_ent2;

  insert into public.inv_pruebas_detalle_entradas (id_transaccion, cod, producto, cantidad, precio_unitario) values
    (v_ent2, 'PRU-003', 'Producto de prueba C — cable eléctrico', 20, 1.10),
    (v_ent2, 'PRU-001', 'Producto de prueba A — tornillos', 10, 0.25);

  insert into public.inv_pruebas_transacciones_salida
    (bote, a_quien_entrega, proposito, usuario_id, usuario_nombre, fecha_hora)
  values
    ('BOTE PRUEBA 1', 'Juan Pérez (prueba)', 'Salida de ejemplo para pruebas del sistema.',
     v_usuario_id, v_usuario_nombre, now() - interval '12 hours')
  returning id_transaccion into v_sal1;

  insert into public.inv_pruebas_detalle_salidas (id_transaccion, cod, producto, cantidad) values
    (v_sal1, 'PRU-001', 'Producto de prueba A — tornillos', 15),
    (v_sal1, 'PRU-002', 'Producto de prueba B — manguera', 5);
end $$;
