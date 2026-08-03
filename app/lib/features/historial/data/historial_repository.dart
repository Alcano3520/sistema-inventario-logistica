import '../../../core/supabase_config.dart';
import '../domain/transaccion.dart';

class HistorialRepository {
  Future<List<TransaccionEntrada>> obtenerHistorialEntradas() async {
    final data = await supabase
        .from('inv_transacciones_entrada')
        .select('*, inv_detalle_entradas(*)')
        .order('fecha_hora', ascending: false);
    return (data as List)
        .map((e) => TransaccionEntrada.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransaccionSalida>> obtenerHistorialSalidas() async {
    final data = await supabase
        .from('inv_transacciones_salida')
        .select('*, inv_detalle_salidas(*)')
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
