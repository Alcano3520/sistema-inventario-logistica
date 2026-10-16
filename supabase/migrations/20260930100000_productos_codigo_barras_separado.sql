-- El código de producto (cod, la clave interna que usa toda la app) y el
-- código de barras son cosas distintas: un producto puede traer un código
-- de barras del fabricante/proveedor diferente al código interno con el
-- que se identifica en el sistema. Mismo patrón que ya existe en Dotación
-- Empleados (codigo_interno + codigo_barras).

alter table inv_productos add column if not exists codigo_barras text;
alter table inv_motos_productos add column if not exists codigo_barras text;

create unique index if not exists idx_inv_productos_codigo_barras
  on inv_productos (codigo_barras) where codigo_barras is not null;
create unique index if not exists idx_inv_motos_productos_codigo_barras
  on inv_motos_productos (codigo_barras) where codigo_barras is not null;
