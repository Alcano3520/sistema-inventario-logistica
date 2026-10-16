-- El Taller (repuestos, OT, despacho, custodia de piezas retiradas) ahora
-- sirve para Barcos además de Motos, con el mismo patrón de tablas
-- separadas por módulo que usa el resto de la app (movimientos/productos).
--
-- 1) Renombra moto_cod -> vehiculo_cod en las tablas de Motos, para que el
--    nombre de columna sea el mismo en ambos módulos (el código Dart ya no
--    tiene que saber si está hablando con Motos o Barcos).
-- 2) Crea el set completo de tablas espejo para Barcos, ya con las
--    correcciones de seguridad que Motos fue acumulando (stock suficiente,
--    estado de OT, separación de funciones, corrección abierta a
--    logística/operador) incorporadas desde el principio.

alter table inv_motos_ordenes_trabajo rename column moto_cod to vehiculo_cod;
alter table inv_motos_repuestos_retirados rename column moto_cod to vehiculo_cod;

-- ----------------------------------------------------------------------------
-- Tablas de Barcos (espejo de inv_motos_*)
-- ----------------------------------------------------------------------------

create table if not exists inv_barcos_repuestos (
    id uuid primary key default gen_random_uuid(),
    codigo_barras varchar(100) unique not null,
    nombre varchar(150) not null,
    stock_actual int not null default 0,
    stock_minimo int not null default 2,
    kilometraje_vida_util int default 5000,
    requiere_pieza_usada boolean default true,
    created_at timestamptz default now()
);

create table if not exists inv_barcos_repuestos_codigos (
    id uuid primary key default gen_random_uuid(),
    repuesto_id uuid references inv_barcos_repuestos(id) on delete cascade,
    codigo_barras varchar(100) unique not null,
    proveedor_nombre varchar(150),
    created_at timestamptz default now()
);
create index if not exists idx_inv_barcos_repuestos_codigos_repuesto on inv_barcos_repuestos_codigos(repuesto_id);

create table if not exists inv_barcos_ordenes_trabajo (
    id uuid primary key default gen_random_uuid(),
    codigo_ot varchar(50) unique not null,
    vehiculo_cod text references inv_productos(cod),
    mecanico_id uuid references inv_perfiles(id),
    kilometraje_actual int not null,
    descripcion_fallo text not null,
    estado varchar(30) check (estado in ('ABIERTA', 'EN_PROCESO', 'COMPLETADA', 'CANCELADA')) default 'ABIERTA',
    firma_mecanico_url text,
    foto_falla_url text,
    foto_repuesto_nuevo_url text,
    created_at timestamptz default now(),
    closed_at timestamptz
);
create index if not exists idx_inv_barcos_ot_vehiculo on inv_barcos_ordenes_trabajo(vehiculo_cod);

create table if not exists inv_barcos_ot_consumo (
    id uuid primary key default gen_random_uuid(),
    orden_trabajo_id uuid references inv_barcos_ordenes_trabajo(id) on delete cascade,
    repuesto_id uuid references inv_barcos_repuestos(id),
    cantidad int not null check (cantidad > 0),
    bodeguero_id uuid references inv_perfiles(id),
    foto_evidencia_url text,
    created_at timestamptz default now()
);
create index if not exists idx_inv_barcos_ot_consumo_ot on inv_barcos_ot_consumo(orden_trabajo_id);

create table if not exists inv_barcos_repuestos_ingresos (
    id uuid primary key default gen_random_uuid(),
    repuesto_id uuid references inv_barcos_repuestos(id),
    bodeguero_id uuid references inv_perfiles(id),
    cantidad int not null check (cantidad > 0),
    proveedor varchar(150),
    foto_comprobante_url text,
    created_at timestamptz default now()
);
create index if not exists idx_inv_barcos_repuestos_ingresos_repuesto on inv_barcos_repuestos_ingresos(repuesto_id);

create table if not exists inv_barcos_repuestos_retirados (
    id uuid primary key default gen_random_uuid(),
    orden_trabajo_id uuid references inv_barcos_ordenes_trabajo(id),
    repuesto_original_id uuid references inv_barcos_repuestos(id),
    vehiculo_cod text references inv_productos(cod),
    cantidad int not null,
    estado_pieza varchar(30) default 'DANADO_REEMPLAZADO',
    estado_gestion varchar(30) check (estado_gestion in ('EN_CUSTODIA', 'DADO_DE_BAJA', 'REACONDICIONADO')) default 'EN_CUSTODIA',
    foto_evidencia_url text,
    created_at timestamptz default now()
);

create table if not exists inv_barcos_actas_baja (
    id uuid primary key default gen_random_uuid(),
    codigo_acta varchar(50) unique not null,
    supervisor_id uuid references inv_perfiles(id),
    motivo_baja text not null,
    foto_acta_firmada_url text,
    created_at timestamptz default now()
);

create table if not exists inv_barcos_actas_baja_detalle (
    id uuid primary key default gen_random_uuid(),
    acta_id uuid references inv_barcos_actas_baja(id) on delete cascade,
    retirado_id uuid references inv_barcos_repuestos_retirados(id)
);

-- ----------------------------------------------------------------------------
-- Triggers de stock (con verificación de stock suficiente ya incorporada)
-- ----------------------------------------------------------------------------

create or replace function trg_inv_barcos_descontar_stock_repuesto()
returns trigger as $$
declare
  v_stock int;
begin
  select stock_actual into v_stock from inv_barcos_repuestos where id = new.repuesto_id for update;

  if v_stock is null then
    raise exception 'Repuesto % no encontrado', new.repuesto_id;
  end if;

  if v_stock < new.cantidad then
    raise exception 'Stock insuficiente del repuesto. Stock actual: %', v_stock;
  end if;

  update inv_barcos_repuestos
  set stock_actual = stock_actual - new.cantidad
  where id = new.repuesto_id;
  return new;
end;
$$ language plpgsql set search_path = public;

drop trigger if exists trigger_descontar_stock_repuesto on inv_barcos_ot_consumo;
create trigger trigger_descontar_stock_repuesto
after insert on inv_barcos_ot_consumo
for each row execute function trg_inv_barcos_descontar_stock_repuesto();

create or replace function trg_inv_barcos_incrementar_stock_repuesto()
returns trigger as $$
begin
    update inv_barcos_repuestos
    set stock_actual = stock_actual + new.cantidad
    where id = new.repuesto_id;
    return new;
end;
$$ language plpgsql set search_path = public;

drop trigger if exists trigger_incrementar_stock_repuesto on inv_barcos_repuestos_ingresos;
create trigger trigger_incrementar_stock_repuesto
after insert on inv_barcos_repuestos_ingresos
for each row execute function trg_inv_barcos_incrementar_stock_repuesto();

-- ----------------------------------------------------------------------------
-- RLS (mismo modelo que Motos, con las reglas de OT-estado, separación de
-- funciones y corrección abierta a Admin/Logística/operador ya incluidas)
-- ----------------------------------------------------------------------------

alter table inv_barcos_repuestos enable row level security;
alter table inv_barcos_repuestos_codigos enable row level security;
alter table inv_barcos_ordenes_trabajo enable row level security;
alter table inv_barcos_ot_consumo enable row level security;
alter table inv_barcos_repuestos_ingresos enable row level security;
alter table inv_barcos_repuestos_retirados enable row level security;
alter table inv_barcos_actas_baja enable row level security;
alter table inv_barcos_actas_baja_detalle enable row level security;

create policy inv_barcos_repuestos_select on inv_barcos_repuestos for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('barcos')));
create policy inv_barcos_repuestos_insert on inv_barcos_repuestos for insert
    with check (inv_is_admin() or inv_tiene_modulo('barcos'));
create policy inv_barcos_repuestos_admin_update on inv_barcos_repuestos for update
    using (inv_is_admin());
create policy inv_barcos_repuestos_admin_delete on inv_barcos_repuestos for delete
    using (inv_is_admin());

create policy inv_barcos_repuestos_codigos_select on inv_barcos_repuestos_codigos for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('barcos')));
create policy inv_barcos_repuestos_codigos_insert on inv_barcos_repuestos_codigos for insert
    with check (inv_is_admin() or inv_tiene_modulo('barcos'));
create policy inv_barcos_repuestos_codigos_admin_delete on inv_barcos_repuestos_codigos for delete
    using (inv_is_admin());

create policy inv_barcos_ot_select on inv_barcos_ordenes_trabajo for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('barcos')));
create policy inv_barcos_ot_insert on inv_barcos_ordenes_trabajo for insert
    with check (inv_is_admin() or (inv_tiene_modulo('barcos') and mecanico_id = auth.uid()));
create policy inv_barcos_ot_update on inv_barcos_ordenes_trabajo for update
    using (
      inv_is_admin()
      or inv_is_logistica()
      or (inv_tiene_modulo('barcos') and inv_is_active_user())
    );

create policy inv_barcos_ot_consumo_select on inv_barcos_ot_consumo for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('barcos')));
create policy inv_barcos_ot_consumo_insert on inv_barcos_ot_consumo for insert
    with check (
      bodeguero_id = auth.uid()
      and (inv_is_admin() or inv_tiene_modulo('barcos'))
      and exists (
        select 1 from inv_barcos_ordenes_trabajo o
        where o.id = orden_trabajo_id
          and o.estado in ('ABIERTA', 'EN_PROCESO')
          and o.mecanico_id <> bodeguero_id
      )
    );

create policy inv_barcos_repuestos_ingresos_select on inv_barcos_repuestos_ingresos for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('barcos')));
create policy inv_barcos_repuestos_ingresos_insert on inv_barcos_repuestos_ingresos for insert
    with check (bodeguero_id = auth.uid() and (inv_is_admin() or inv_tiene_modulo('barcos')));

create policy inv_barcos_repuestos_retirados_select on inv_barcos_repuestos_retirados for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('barcos')));
create policy inv_barcos_repuestos_retirados_insert on inv_barcos_repuestos_retirados for insert
    with check (inv_is_admin() or inv_tiene_modulo('barcos'));
create policy inv_barcos_repuestos_retirados_admin_update on inv_barcos_repuestos_retirados for update
    using (inv_is_admin());

create policy inv_barcos_actas_baja_admin_all on inv_barcos_actas_baja for all
    using (inv_is_admin()) with check (inv_is_admin());
create policy inv_barcos_actas_baja_detalle_admin_all on inv_barcos_actas_baja_detalle for all
    using (inv_is_admin()) with check (inv_is_admin());
