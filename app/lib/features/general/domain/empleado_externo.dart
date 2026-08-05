class EmpleadoExterno {
  final String cedula;
  final String nombreCompleto;
  final String? cargo;
  final String? departamento;
  final String? estado;

  const EmpleadoExterno({
    required this.cedula,
    required this.nombreCompleto,
    this.cargo,
    this.departamento,
    this.estado,
  });

  /// Normaliza la cédula: quita puntos/espacios/decimales de Excel y
  /// rellena con cero a la izquierda si quedó en 9 dígitos.
  static String normalizarCedula(String valor) {
    var limpio = valor.trim();
    if (limpio.endsWith('.0')) limpio = limpio.substring(0, limpio.length - 2);
    limpio = limpio.replaceAll(RegExp(r'[^0-9]'), '');
    if (limpio.length == 9) limpio = '0$limpio';
    return limpio;
  }

  /// La búsqueda pasa por la Edge Function `buscar-empleados-rrhh`, que ya
  /// normaliza los nombres de columna de la base externa antes de responder.
  factory EmpleadoExterno.fromMap(Map<String, dynamic> map) {
    return EmpleadoExterno(
      cedula: normalizarCedula((map['cedula'] ?? '').toString()),
      nombreCompleto: (map['nombreCompleto'] as String?)?.trim() ?? '',
      cargo: map['cargo'] as String?,
      departamento: map['departamento'] as String?,
      estado: map['estado'] as String?,
    );
  }
}
