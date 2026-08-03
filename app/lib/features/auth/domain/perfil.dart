class Perfil {
  final String id;
  final String email;
  final String nombre;
  final String rol;
  final bool activo;
  final List<String> modulos;

  const Perfil({
    required this.id,
    required this.email,
    required this.nombre,
    required this.rol,
    required this.activo,
    required this.modulos,
  });

  bool get esAdmin => rol == 'Admin';

  bool tieneAcceso(String modulo) => modulos.contains(modulo);

  factory Perfil.fromMap(Map<String, dynamic> map, {required String email}) {
    return Perfil(
      id: map['id'] as String,
      email: email,
      nombre: map['nombre'] as String? ?? '',
      rol: map['rol'] as String? ?? 'Operador',
      activo: map['activo'] as bool? ?? true,
      modulos: ((map['modulos'] as List?) ?? const ['barcos'])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
