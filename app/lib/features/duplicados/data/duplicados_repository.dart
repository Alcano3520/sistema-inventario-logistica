import '../../../core/supabase_config.dart';

class DuplicadosRepository {
  Future<Map<String, dynamic>> detectar() async {
    final data = await supabase.rpc('inv_detectar_duplicados');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> eliminar() async {
    final data = await supabase.rpc('inv_eliminar_duplicados');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> recalcular() async {
    final data = await supabase.rpc('inv_recalcular_stocks');
    return Map<String, dynamic>.from(data as Map);
  }
}
