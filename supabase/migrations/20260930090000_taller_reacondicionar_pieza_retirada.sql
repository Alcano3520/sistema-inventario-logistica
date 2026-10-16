-- Igual que en Dotación (una devolución en buen estado vuelve a
-- stock_disponible, una mala va a stock_baja), una pieza retirada en el
-- taller puede resultar reutilizable: si el supervisor la marca
-- REACONDICIONADO, vuelve al stock_actual del repuesto; si la marca
-- DADO_DE_BAJA (ya existía), no vuelve a stock, solo queda el acta.

create or replace function trg_inv_motos_reacondicionar_repuesto()
returns trigger as $$
begin
  if new.estado_gestion = 'REACONDICIONADO' and old.estado_gestion is distinct from 'REACONDICIONADO' then
    update inv_motos_repuestos
    set stock_actual = stock_actual + new.cantidad
    where id = new.repuesto_original_id;
  end if;
  return new;
end;
$$ language plpgsql set search_path = public;

drop trigger if exists trigger_reacondicionar_repuesto on inv_motos_repuestos_retirados;
create trigger trigger_reacondicionar_repuesto
after update of estado_gestion on inv_motos_repuestos_retirados
for each row execute function trg_inv_motos_reacondicionar_repuesto();

create or replace function trg_inv_barcos_reacondicionar_repuesto()
returns trigger as $$
begin
  if new.estado_gestion = 'REACONDICIONADO' and old.estado_gestion is distinct from 'REACONDICIONADO' then
    update inv_barcos_repuestos
    set stock_actual = stock_actual + new.cantidad
    where id = new.repuesto_original_id;
  end if;
  return new;
end;
$$ language plpgsql set search_path = public;

drop trigger if exists trigger_reacondicionar_repuesto on inv_barcos_repuestos_retirados;
create trigger trigger_reacondicionar_repuesto
after update of estado_gestion on inv_barcos_repuestos_retirados
for each row execute function trg_inv_barcos_reacondicionar_repuesto();

-- Antes solo Admin podía cambiar el estado de una pieza retirada (dar de
-- baja o, ahora, reacondicionar). Se abre también a Encargado de Logística,
-- igual que el resto de correcciones operativas del taller.
drop policy if exists inv_motos_repuestos_retirados_admin_update on inv_motos_repuestos_retirados;
create policy inv_motos_repuestos_retirados_update on inv_motos_repuestos_retirados for update
    using (inv_is_admin() or inv_is_logistica());

drop policy if exists inv_barcos_repuestos_retirados_admin_update on inv_barcos_repuestos_retirados;
create policy inv_barcos_repuestos_retirados_update on inv_barcos_repuestos_retirados for update
    using (inv_is_admin() or inv_is_logistica());
