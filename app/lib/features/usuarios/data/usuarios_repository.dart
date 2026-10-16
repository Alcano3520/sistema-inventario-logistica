import '../../../core/supabase_config.dart';
import '../domain/usuario_admin.dart';

class UsuariosException implements Exception {
  final String mensaje;
  UsuariosException(this.mensaje);
  @override
  String toString() => mensaje;
}

class UsuariosRepository {
  Future<Map<String, dynamic>> _invocar(Map<String, dynamic> body) async {
    final res = await supabase.functions.invoke('admin-users', body: body);
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw UsuariosException(data['error'].toString());
    }
    if (res.status >= 400) {
      throw UsuariosException('Error del servidor (${res.status}).');
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<UsuarioAdmin>> listar() async {
    final data = await _invocar({'action': 'list'});
    final lista = (data['usuarios'] as List? ?? []);
    return lista.map((e) => UsuarioAdmin.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> crear({
    required String email,
    required String nombre,
    required String usuario,
    required String password,
    required String rol,
    String? oficio,
    required List<String> modulos,
  }) {
    return _invocar({
      'action': 'create',
      'email': email,
      'nombre': nombre,
      'usuario': usuario,
      'password': password,
      'rol': rol,
      'oficio': ?oficio,
      'modulos': modulos,
    });
  }

  Future<void> actualizar({
    required String id,
    String? nombre,
    String? rol,
    String? oficio,
    bool? activo,
    List<String>? modulos,
    bool? puedeEditarFacturas,
  }) {
    return _invocar({
      'action': 'update',
      'id': id,
      'nombre': ?nombre,
      'rol': ?rol,
      'oficio': ?oficio,
      'activo': ?activo,
      'modulos': ?modulos,
      'puede_editar_facturas': ?puedeEditarFacturas,
    });
  }

  Future<void> restablecerPassword({required String id, required String nuevaPassword}) {
    return _invocar({'action': 'resetPassword', 'id': id, 'nuevaPassword': nuevaPassword});
  }

  Future<void> eliminar(String id) {
    return _invocar({'action': 'delete', 'id': id});
  }
}
