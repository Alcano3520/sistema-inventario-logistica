class Perfil {
  final String id;
  final String email;
  final String nombre;
  final String rol;
  final String? oficio;
  final bool activo;
  final List<String> modulos;

  const Perfil({
    required this.id,
    required this.email,
    required this.nombre,
    required this.rol,
    this.oficio,
    required this.activo,
    required this.modulos,
  });

  bool get esAdmin => rol == 'Admin';

  /// Jefe de logística o sus asistentes: pueden crear/gestionar cuentas de
  /// Operador (bodeguero, mecánico) y registrar entradas/salidas, pero nunca
  /// pueden tocar cuentas de Admin ni de otro Encargado de Logística — eso
  /// lo bloquea el Edge Function `admin-users`, no solo la UI.
  bool get esLogistica => rol == 'Encargado de Logística';

  bool get puedeGestionarUsuarios => esAdmin || esLogistica;

  /// Puede crear/editar productos (incluyendo agregar o cambiar la foto):
  /// cualquiera activo salvo el Mecánico, que solo debe poder crear
  /// pedidos (OT), no tocar el catálogo de productos.
  bool get puedeGestionarProductos => !esMecanico;

  /// `oficio` es solo una etiqueta sobre un Operador (no cambia el `rol`
  /// que usa la base de datos para permisos), pero al Mecánico sí se le
  /// restringe la navegación: solo puede crear pedidos (OT) y ver su
  /// propio historial, nada más.
  bool get esMecanico => rol == 'Operador' && oficio == 'Mecánico';

  bool tieneAcceso(String modulo) => modulos.contains(modulo);

  factory Perfil.fromMap(Map<String, dynamic> map, {required String email}) {
    return Perfil(
      id: map['id'] as String,
      email: email,
      nombre: map['nombre'] as String? ?? '',
      rol: map['rol'] as String? ?? 'Operador',
      oficio: map['oficio'] as String?,
      activo: map['activo'] as bool? ?? true,
      modulos: ((map['modulos'] as List?) ?? const ['barcos'])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
