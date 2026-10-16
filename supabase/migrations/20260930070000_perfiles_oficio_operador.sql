-- Etiqueta descriptiva para cuentas de rol Operador (Mecánico, Bodeguero, u
-- Operador genérico). NO afecta permisos: eso lo sigue decidiendo `rol`.
-- Es solo para que Admin/Logística distingan a simple vista quién es quién
-- en la lista de Usuarios.

alter table inv_perfiles add column if not exists oficio text;
