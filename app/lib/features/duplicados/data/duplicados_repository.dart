import '../../../core/modulos.dart';
import '../../../core/supabase_config.dart';

class DuplicadosRepository {
  final ModuloTablas tablas;

  const DuplicadosRepository(this.tablas);

  Future<Map<String, dynamic>> detectar() async {
    final data = await supabase.rpc(tablas.rpcDetectarDuplicados);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> eliminar() async {
    final data = await supabase.rpc(tablas.rpcEliminarDuplicados);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> recalcular() async {
    final data = await supabase.rpc(tablas.rpcRecalcularStocks);
    return Map<String, dynamic>.from(data as Map);
  }
}
