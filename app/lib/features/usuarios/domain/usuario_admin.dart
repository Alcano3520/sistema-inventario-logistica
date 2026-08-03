class UsuarioAdmin {
  final String id;
  final String email;
  final String nombre;
  final String usuario;
  final String rol;
  final bool activo;
  final List<String> modulos;

  const UsuarioAdmin({
    required this.id,
    required this.email,
    required this.nombre,
    required this.usuario,
    required this.rol,
    required this.activo,
    required this.modulos,
  });

  factory UsuarioAdmin.fromMap(Map<String, dynamic> map) {
    return UsuarioAdmin(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      usuario: map['usuario'] as String? ?? '',
      rol: map['rol'] as String? ?? 'Operador',
      activo: map['activo'] as bool? ?? true,
      modulos: ((map['modulos'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}
