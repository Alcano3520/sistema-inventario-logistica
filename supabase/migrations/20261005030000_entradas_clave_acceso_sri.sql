-- Campo opcional para la clave de acceso del SRI (49 dígitos) de la
-- factura electrónica — se puede escanear del código de barras del RIDE,
-- sirve como respaldo/verificación oficial sin errores de tipeo. El
-- número de factura corto que Financiero usa para buscar sigue siendo el
-- campo principal (num_factura), este es adicional.

alter table inv_transacciones_entrada add column if not exists clave_acceso_sri text;
alter table inv_motos_transacciones_entrada add column if not exists clave_acceso_sri text;
