-- El trigger de descuento de stock del taller de motos (repuestos) no
-- validaba stock suficiente antes de descontar, a diferencia de los
-- triggers de salida de Barcos/Motos que sí lo hacen. Se corrige con el
-- mismo patrón: bloquea la fila (for update) y rechaza si no alcanza.

create or replace function trg_inv_motos_descontar_stock_repuesto()
returns trigger as $$
declare
  v_stock int;
begin
  select stock_actual into v_stock from inv_motos_repuestos where id = new.repuesto_id for update;

  if v_stock is null then
    raise exception 'Repuesto % no encontrado', new.repuesto_id;
  end if;

  if v_stock < new.cantidad then
    raise exception 'Stock insuficiente del repuesto. Stock actual: %', v_stock;
  end if;

  update inv_motos_repuestos
  set stock_actual = stock_actual - new.cantidad
  where id = new.repuesto_id;
  return new;
end;
$$ language plpgsql set search_path = public;
