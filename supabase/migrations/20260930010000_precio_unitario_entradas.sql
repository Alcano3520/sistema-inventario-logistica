-- Precio de compra por unidad, opcional, en las líneas de Entrada. El
-- número de factura (num_factura) ya existía a nivel de transacción; sigue
-- opcional por ahora, pero se prevé exigirlo más adelante.

alter table inv_detalle_entradas add column if not exists precio_unitario numeric;
alter table inv_motos_detalle_entradas add column if not exists precio_unitario numeric;
