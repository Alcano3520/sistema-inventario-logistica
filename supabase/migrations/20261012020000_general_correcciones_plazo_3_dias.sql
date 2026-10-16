-- Las correcciones (editar/anular) de movimientos de tipo ENTRADA o SALIDA
-- en el módulo de Dotación solo se permiten hasta 3 días después de
-- registrados. Pasado ese plazo, cualquier ajuste debe hacerse como un
-- movimiento nuevo (p.ej. un Ajuste de Stock), no reescribiendo el
-- historial. Otros tipos de movimiento (Devolución, Baja, Ajuste) no tienen
-- este límite. Se refuerza tanto en la RPC de anulación como en la política
-- de UPDATE directo que usa la edición de metadatos — así queda igual de
-- protegido sin importar por qué camino llegue la solicitud.

create or replace function public.inv_general_anular_movimiento(p_movimiento_id uuid, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  mov record;
  ya_exportado boolean;
begin
  if not public.inv_is_admin() then
    raise exception 'Acceso denegado. Solo administradores.';
  end if;

  select * into mov from public.inv_general_movimientos where id = p_movimiento_id;
  if mov is null then
    raise exception 'Movimiento no encontrado.';
  end if;
  if mov.anulado then
    raise exception 'El movimiento ya está anulado.';
  end if;

  if mov.tipo_movimiento in ('ENTRADA', 'SALIDA') and now() - mov.fecha_movimiento > interval '3 days' then
    raise exception 'No se puede anular: ya pasaron más de 3 días desde este movimiento.';
  end if;

  select exists(
    select 1 from public.inv_general_descuentos_nomina
    where movimiento_id = p_movimiento_id and exportado = true
  ) into ya_exportado;

  if ya_exportado then
    raise exception 'No se puede anular: el descuento de este movimiento ya fue exportado a nómina.';
  end if;

  update public.inv_general_movimientos
    set anulado = true, motivo_anulacion = p_motivo
    where id = p_movimiento_id;

  -- Revertir stock (inverso exacto de inv_general_movimiento_apply)
  if mov.tipo_movimiento = 'ENTRADA' then
    update public.inv_general_articulos
      set stock_disponible = stock_disponible - mov.cantidad,
          stock_total = stock_total - mov.cantidad
      where id = mov.articulo_id;

  elsif mov.tipo_movimiento = 'SALIDA' and mov.aplica_descuento = false then
    update public.inv_general_articulos
      set stock_disponible = stock_disponible + mov.cantidad,
          stock_consignacion = greatest(stock_consignacion - mov.cantidad, 0)
      where id = mov.articulo_id;

  elsif mov.tipo_movimiento = 'SALIDA' and mov.aplica_descuento = true then
    update public.inv_general_articulos
      set stock_disponible = stock_disponible + mov.cantidad,
          stock_descontado = greatest(stock_descontado - mov.cantidad, 0)
      where id = mov.articulo_id;

  elsif mov.tipo_movimiento = 'DEVOLUCION' and coalesce(mov.condicion, 'BUEN_ESTADO') in ('BUEN_ESTADO','USO_PARCIAL') then
    update public.inv_general_articulos
      set stock_disponible = stock_disponible - mov.cantidad,
          stock_consignacion = stock_consignacion + mov.cantidad
      where id = mov.articulo_id;

  elsif mov.tipo_movimiento = 'DEVOLUCION' then
    update public.inv_general_articulos
      set stock_consignacion = stock_consignacion + mov.cantidad,
          stock_baja = greatest(stock_baja - mov.cantidad, 0)
      where id = mov.articulo_id;

  elsif mov.tipo_movimiento = 'BAJA' then
    update public.inv_general_articulos
      set stock_disponible = stock_disponible + mov.cantidad,
          stock_baja = greatest(stock_baja - mov.cantidad, 0)
      where id = mov.articulo_id;

  elsif mov.tipo_movimiento = 'AJUSTE' then
    update public.inv_general_articulos
      set stock_disponible = mov.stock_anterior,
          stock_total = stock_total - (mov.stock_nuevo - mov.stock_anterior)
      where id = mov.articulo_id;
  end if;

  return jsonb_build_object('ok', true, 'movimiento_id', p_movimiento_id);
end;
$function$;

drop policy if exists inv_general_mov_admin_update on public.inv_general_movimientos;
create policy inv_general_mov_admin_update on public.inv_general_movimientos
for update
using (
  inv_is_admin()
  and (
    tipo_movimiento not in ('ENTRADA', 'SALIDA')
    or fecha_movimiento >= now() - interval '3 days'
  )
)
with check (
  inv_is_admin()
  and (
    tipo_movimiento not in ('ENTRADA', 'SALIDA')
    or fecha_movimiento >= now() - interval '3 days'
  )
);
