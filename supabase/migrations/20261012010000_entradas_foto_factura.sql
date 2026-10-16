-- Permite adjuntar una foto de la factura física a una Entrada (opcional),
-- adicional al número de factura (obligatorio) y a la clave de acceso SRI
-- (opcional). Se guarda como ruta en el bucket privado `inv-firmas`, igual
-- que la firma y la foto de sustento de Salida.
alter table public.inv_transacciones_entrada
  add column if not exists foto_factura_url text;

alter table public.inv_motos_transacciones_entrada
  add column if not exists foto_factura_url text;
