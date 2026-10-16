class Perfil {
  final String id;
  final String email;
  final String nombre;
  final String rol;
  final String? oficio;
  final bool activo;
  final List<String> modulos;

  /// Permiso aparte del rol: puede corregir una Entrada/factura ya
  /// registrada (datos de encabezado e ítems), con observación obligatoria.
  /// No todo Admin lo tiene — es deliberadamente más angosto que `esAdmin`,
  /// pensado para el super-admin y para contabilidad/auditoría.
  final bool puedeEditarFacturas;

  const Perfil({
    required this.id,
    required this.email,
    required this.nombre,
    required this.rol,
    this.oficio,
    required this.activo,
    required this.modulos,
    this.puedeEditarFacturas = false,
  });

  bool get esAdmin => rol == 'Admin';

  /// Única cuenta que puede modificar a OTRO Admin, y la única que puede
  /// otorgar/quitar `puedeEditarFacturas` — mismo id que `SUPER_ADMIN_ID`
  /// en el Edge Function `admin-users` (la autoridad real de este permiso,
  /// no esto: esto solo decide si mostrar el control en la UI).
  static const _superAdminId = '3bd84c78-7a09-4e2b-9c7f-096e92d6c1a3';
  bool get esSuperAdmin => id == _superAdminId;

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
      puedeEditarFacturas: map['puede_editar_facturas'] as bool? ?? false,
    );
  }
}
