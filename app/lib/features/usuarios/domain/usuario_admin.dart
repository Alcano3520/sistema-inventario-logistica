class UsuarioAdmin {
  final String id;
  final String email;
  final String nombre;
  final String usuario;
  final String rol;
  final String? oficio;
  final bool activo;
  final List<String> modulos;
  final bool puedeEditarFacturas;

  const UsuarioAdmin({
    required this.id,
    required this.email,
    required this.nombre,
    required this.usuario,
    required this.rol,
    this.oficio,
    required this.activo,
    required this.modulos,
    this.puedeEditarFacturas = false,
  });

  /// Etiqueta a mostrar en la lista: el oficio (Mecánico/Bodeguero) si lo
  /// tiene, o el rol genérico.
  String get rolMostrado => oficio ?? rol;

  factory UsuarioAdmin.fromMap(Map<String, dynamic> map) {
    return UsuarioAdmin(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      usuario: map['usuario'] as String? ?? '',
      rol: map['rol'] as String? ?? 'Operador',
      oficio: map['oficio'] as String?,
      activo: map['activo'] as bool? ?? true,
      modulos: ((map['modulos'] as List?) ?? const []).map((e) => e.toString()).toList(),
      puedeEditarFacturas: map['puede_editar_facturas'] as bool? ?? false,
    );
  }
}
