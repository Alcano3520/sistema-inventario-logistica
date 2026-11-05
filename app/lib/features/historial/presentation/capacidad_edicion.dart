import '../../auth/domain/perfil.dart';

/// Qué tanto puede corregir alguien de una Entrada/Salida ya registrada:
///   - `completa`: quien tiene el permiso de editar facturas (sin límite de
///     tiempo, sea de quien sea el registro), o quien la registró el MISMO
///     día (puede corregir todo: fecha, cantidades, a quién, etc.).
///   - `soloFecha`: quien la registró, entre el día 2 y el día 3 desde que
///     la creó — ya no puede tocar nada más que la fecha.
///   - `ninguna`: pasaron más de 3 días, o no es ni quien la registró ni
///     tiene el permiso de editar facturas — tiene que pedírselo a alguien
///     que sí tenga ese permiso.
enum CapacidadEdicion { ninguna, soloFecha, completa }

CapacidadEdicion capacidadEdicion({
  required Perfil perfil,
  required String usuarioIdRegistro,
  required DateTime creadoEn,
}) {
  if (perfil.puedeEditarFacturas) return CapacidadEdicion.completa;
  if (perfil.id != usuarioIdRegistro) return CapacidadEdicion.ninguna;

  final transcurrido = DateTime.now().difference(creadoEn.toLocal());
  if (transcurrido <= const Duration(days: 1)) return CapacidadEdicion.completa;
  if (transcurrido <= const Duration(days: 3)) return CapacidadEdicion.soloFecha;
  return CapacidadEdicion.ninguna;
}
