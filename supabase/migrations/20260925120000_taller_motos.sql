-- ============================================================================
-- Módulo de Taller, Repuestos y Mantenimiento Anti-Robo (Motos)
-- ============================================================================
-- Nota: `moto_id UUID REFERENCES inv_motos_productos(id)` del diseño original
-- no aplica en este proyecto: inv_motos_productos usa `cod` (text) como PK,
-- no tiene columna `id`. Se corrigió a `moto_cod TEXT REFERENCES
-- inv_motos_productos(cod)` en las dos tablas que lo usaban.

create table if not exists inv_motos_repuestos (
    id uuid primary key default gen_random_uuid(),
    codigo_barras varchar(100) unique not null,
    nombre varchar(150) not null,
    stock_actual int not null default 0,
    stock_minimo int not null default 2,
    kilometraje_vida_util int default 5000,
    requiere_pieza_usada boolean default true,
    created_at timestamptz default now()
);

-- Códigos de barras secundarios: el mismo repuesto puede llegar con un
-- código distinto según el proveedor/marca que lo suministre.
create table if not exists inv_motos_repuestos_codigos (
    id uuid primary key default gen_random_uuid(),
    repuesto_id uuid references inv_motos_repuestos(id) on delete cascade,
    codigo_barras varchar(100) unique not null,
    proveedor_nombre varchar(150),
    created_at timestamptz default now()
);
create index if not exists idx_inv_motos_repuestos_codigos_repuesto on inv_motos_repuestos_codigos(repuesto_id);

create table if not exists inv_motos_ordenes_trabajo (
    id uuid primary key default gen_random_uuid(),
    codigo_ot varchar(50) unique not null,
    moto_cod text references inv_motos_productos(cod),
    mecanico_id uuid references inv_perfiles(id),
    kilometraje_actual int not null,
    descripcion_fallo text not null,
    estado varchar(30) check (estado in ('ABIERTA', 'EN_PROCESO', 'COMPLETADA', 'CANCELADA')) default 'ABIERTA',
    firma_mecanico_url text,
    created_at timestamptz default now(),
    closed_at timestamptz
);
create index if not exists idx_inv_motos_ot_moto on inv_motos_ordenes_trabajo(moto_cod);

create table if not exists inv_motos_ot_consumo (
    id uuid primary key default gen_random_uuid(),
    orden_trabajo_id uuid references inv_motos_ordenes_trabajo(id) on delete cascade,
    repuesto_id uuid references inv_motos_repuestos(id),
    cantidad int not null check (cantidad > 0),
    bodeguero_id uuid references inv_perfiles(id),
    foto_evidencia_url text,
    created_at timestamptz default now()
);
create index if not exists idx_inv_motos_ot_consumo_ot on inv_motos_ot_consumo(orden_trabajo_id);

create table if not exists inv_motos_repuestos_ingresos (
    id uuid primary key default gen_random_uuid(),
    repuesto_id uuid references inv_motos_repuestos(id),
    bodeguero_id uuid references inv_perfiles(id),
    cantidad int not null check (cantidad > 0),
    proveedor varchar(150),
    foto_comprobante_url text,
    created_at timestamptz default now()
);
create index if not exists idx_inv_motos_repuestos_ingresos_repuesto on inv_motos_repuestos_ingresos(repuesto_id);

-- Depósito de piezas usadas/dañadas retiradas en cada OT (control anti-robo:
-- toda pieza reemplazada queda en custodia hasta que se formalice su baja).
create table if not exists inv_motos_repuestos_retirados (
    id uuid primary key default gen_random_uuid(),
    orden_trabajo_id uuid references inv_motos_ordenes_trabajo(id),
    repuesto_original_id uuid references inv_motos_repuestos(id),
    moto_cod text references inv_motos_productos(cod),
    cantidad int not null,
    estado_pieza varchar(30) default 'DANADO_REEMPLAZADO',
    estado_gestion varchar(30) check (estado_gestion in ('EN_CUSTODIA', 'DADO_DE_BAJA', 'REACONDICIONADO')) default 'EN_CUSTODIA',
    foto_evidencia_url text,
    created_at timestamptz default now()
);

create table if not exists inv_motos_actas_baja (
    id uuid primary key default gen_random_uuid(),
    codigo_acta varchar(50) unique not null,
    supervisor_id uuid references inv_perfiles(id),
    motivo_baja text not null,
    foto_acta_firmada_url text,
    created_at timestamptz default now()
);

create table if not exists inv_motos_actas_baja_detalle (
    id uuid primary key default gen_random_uuid(),
    acta_id uuid references inv_motos_actas_baja(id) on delete cascade,
    retirado_id uuid references inv_motos_repuestos_retirados(id)
);

-- ----------------------------------------------------------------------------
-- Triggers atómicos de stock (mismo principio que el resto de la app: el
-- cliente Dart nunca suma/resta stock, solo inserta el movimiento).
-- ----------------------------------------------------------------------------

create or replace function trg_inv_motos_descontar_stock_repuesto()
returns trigger as $$
begin
    update inv_motos_repuestos
    set stock_actual = stock_actual - new.cantidad
    where id = new.repuesto_id;
    return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_descontar_stock_repuesto on inv_motos_ot_consumo;
create trigger trigger_descontar_stock_repuesto
after insert on inv_motos_ot_consumo
for each row execute function trg_inv_motos_descontar_stock_repuesto();

create or replace function trg_inv_motos_incrementar_stock_repuesto()
returns trigger as $$
begin
    update inv_motos_repuestos
    set stock_actual = stock_actual + new.cantidad
    where id = new.repuesto_id;
    return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_incrementar_stock_repuesto on inv_motos_repuestos_ingresos;
create trigger trigger_incrementar_stock_repuesto
after insert on inv_motos_repuestos_ingresos
for each row execute function trg_inv_motos_incrementar_stock_repuesto();

alter function trg_inv_motos_descontar_stock_repuesto() set search_path = public;
alter function trg_inv_motos_incrementar_stock_repuesto() set search_path = public;

-- ----------------------------------------------------------------------------
-- RLS: mismo modelo de seguridad que el resto de inv_* (inv_is_admin(),
-- inv_is_active_user(), inv_tiene_modulo('motos')).
-- ----------------------------------------------------------------------------

alter table inv_motos_repuestos enable row level security;
alter table inv_motos_repuestos_codigos enable row level security;
alter table inv_motos_ordenes_trabajo enable row level security;
alter table inv_motos_ot_consumo enable row level security;
alter table inv_motos_repuestos_ingresos enable row level security;
alter table inv_motos_repuestos_retirados enable row level security;
alter table inv_motos_actas_baja enable row level security;
alter table inv_motos_actas_baja_detalle enable row level security;

create policy inv_motos_repuestos_select on inv_motos_repuestos for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('motos')));
create policy inv_motos_repuestos_insert on inv_motos_repuestos for insert
    with check (inv_is_admin() or inv_tiene_modulo('motos'));
create policy inv_motos_repuestos_admin_update on inv_motos_repuestos for update
    using (inv_is_admin());
create policy inv_motos_repuestos_admin_delete on inv_motos_repuestos for delete
    using (inv_is_admin());

create policy inv_motos_repuestos_codigos_select on inv_motos_repuestos_codigos for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('motos')));
create policy inv_motos_repuestos_codigos_insert on inv_motos_repuestos_codigos for insert
    with check (inv_is_admin() or inv_tiene_modulo('motos'));
create policy inv_motos_repuestos_codigos_admin_delete on inv_motos_repuestos_codigos for delete
    using (inv_is_admin());

create policy inv_motos_ot_select on inv_motos_ordenes_trabajo for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('motos')));
create policy inv_motos_ot_insert on inv_motos_ordenes_trabajo for insert
    with check (inv_is_admin() or (inv_tiene_modulo('motos') and mecanico_id = auth.uid()));
create policy inv_motos_ot_update on inv_motos_ordenes_trabajo for update
    using (inv_is_admin() or (inv_tiene_modulo('motos') and mecanico_id = auth.uid()));

create policy inv_motos_ot_consumo_select on inv_motos_ot_consumo for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('motos')));
create policy inv_motos_ot_consumo_insert on inv_motos_ot_consumo for insert
    with check (bodeguero_id = auth.uid() and (inv_is_admin() or inv_tiene_modulo('motos')));

create policy inv_motos_repuestos_ingresos_select on inv_motos_repuestos_ingresos for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('motos')));
create policy inv_motos_repuestos_ingresos_insert on inv_motos_repuestos_ingresos for insert
    with check (bodeguero_id = auth.uid() and (inv_is_admin() or inv_tiene_modulo('motos')));

create policy inv_motos_repuestos_retirados_select on inv_motos_repuestos_retirados for select
    using (inv_is_admin() or (inv_is_active_user() and inv_tiene_modulo('motos')));
create policy inv_motos_repuestos_retirados_insert on inv_motos_repuestos_retirados for insert
    with check (inv_is_admin() or inv_tiene_modulo('motos'));
create policy inv_motos_repuestos_retirados_admin_update on inv_motos_repuestos_retirados for update
    using (inv_is_admin());

-- Acta de baja formal de chatarra: restringida a Admin (no existe un rol
-- "supervisor" separado en inv_perfiles.rol, solo Admin/Operador).
create policy inv_motos_actas_baja_admin_all on inv_motos_actas_baja for all
    using (inv_is_admin()) with check (inv_is_admin());
create policy inv_motos_actas_baja_detalle_admin_all on inv_motos_actas_baja_detalle for all
    using (inv_is_admin()) with check (inv_is_admin());
