-- El mecánico que solicita la OT también puede dejar evidencia fotográfica
-- al momento de reportar la falla: foto de la pieza dañada, y opcionalmente
-- del repuesto nuevo si ya lo tiene en mano.

alter table inv_motos_ordenes_trabajo add column if not exists foto_falla_url text;
alter table inv_motos_ordenes_trabajo add column if not exists foto_repuesto_nuevo_url text;
