import '../../../core/modulos.dart';
import '../../../core/supabase_config.dart';
import '../domain/transaccion.dart';

class HistorialRepository {
  final ModuloTablas tablas;

  const HistorialRepository(this.tablas);

  Future<List<TransaccionEntrada>> obtenerHistorialEntradas() async {
    final data = await supabase
        .from(tablas.transaccionesEntrada)
        .select('*, detalles:${tablas.detalleEntradas}(*)')
        .order('fecha_hora', ascending: false);
    return (data as List)
        .map((e) => TransaccionEntrada.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransaccionSalida>> obtenerHistorialSalidas() async {
    final data = await supabase
        .from(tablas.transaccionesSalida)
        .select('*, detalles:${tablas.detalleSalidas}(*)')
        .order('fecha_hora', ascending: false);
    return (data as List)
        .map((e) => TransaccionSalida.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<String?> firmaUrlFirmada(String? path) async {
    if (path == null) return null;
    try {
      return await supabase.storage.from('inv-firmas').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }
}
