import '../../../core/supabase_config.dart';
import '../domain/empleado_externo.dart';

/// Busca empleados en la base de RRHH externa a través de una Edge Function
/// propia (`buscar-empleados-rrhh`), que guarda esa conexión y su anon key
/// del lado del servidor. Así el cliente (web/APK/escritorio) nunca recibe
/// esa credencial, evitando exponer cédulas/sueldos de empleados.
class EmpleadosExternosRepository {
  Future<List<EmpleadoExterno>> buscar(String termino) async {
    final t = termino.trim();
    if (t.length < 2) return [];

    final respuesta = await supabase.functions.invoke(
      'buscar-empleados-rrhh',
      body: {'termino': t},
    );

    final data = respuesta.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
    final lista = data['empleados'] as List;
    return lista.map((e) => EmpleadoExterno.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }
}
