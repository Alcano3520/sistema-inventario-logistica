-- Endurece el despacho de repuestos del taller de motos con dos reglas de
-- integridad/anti-fraude que antes solo vivían en la pantalla (por lo
-- tanto evitables saltándose la app), y que aplican incluso a Admin porque
-- son reglas de negocio, no de permisos:
--   1. La OT debe seguir ABIERTA o EN_PROCESO (no despachar contra una OT
--      ya Completada o Cancelada).
--   2. El bodeguero que despacha no puede ser el mismo mecánico dueño de la
--      OT (separación de funciones — nadie se autodespacha).

drop policy if exists inv_motos_ot_consumo_insert on inv_motos_ot_consumo;

create policy inv_motos_ot_consumo_insert on inv_motos_ot_consumo for insert
  with check (
    bodeguero_id = auth.uid()
    and (inv_is_admin() or inv_tiene_modulo('motos'))
    and exists (
      select 1 from inv_motos_ordenes_trabajo o
      where o.id = orden_trabajo_id
        and o.estado in ('ABIERTA', 'EN_PROCESO')
        and o.mecanico_id <> bodeguero_id
    )
  );
