-- Cuando el administrador registra una salida directamente, puede anexar
-- (opcionalmente) la petición que la originó: texto y/o foto del papel o
-- mensaje de quien la solicitó. No es obligatorio.

alter table inv_transacciones_salida add column if not exists peticion_texto text;
alter table inv_transacciones_salida add column if not exists peticion_foto_url text;

alter table inv_motos_transacciones_salida add column if not exists peticion_texto text;
alter table inv_motos_transacciones_salida add column if not exists peticion_foto_url text;
