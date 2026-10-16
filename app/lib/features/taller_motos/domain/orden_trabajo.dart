class OrdenTrabajo {
  final String id;
  final String codigoOt;
  final String vehiculoCod;
  final String? vehiculoProducto;
  final String mecanicoId;
  final String? mecanicoNombre;
  final int kilometrajeActual;
  final String descripcionFallo;
  final String estado;
  final String? firmaMecanicoUrl;

  /// Evidencia que el mecánico deja al reportar la falla, no después.
  final String? fotoFallaUrl;
  final String? fotoRepuestoNuevoUrl;

  final DateTime creadoEn;
  final DateTime? cerradoEn;

  const OrdenTrabajo({
    required this.id,
    required this.codigoOt,
    required this.vehiculoCod,
    this.vehiculoProducto,
    required this.mecanicoId,
    this.mecanicoNombre,
    required this.kilometrajeActual,
    required this.descripcionFallo,
    required this.estado,
    this.firmaMecanicoUrl,
    this.fotoFallaUrl,
    this.fotoRepuestoNuevoUrl,
    required this.creadoEn,
    this.cerradoEn,
  });

  bool get abierta => estado == 'ABIERTA' || estado == 'EN_PROCESO';

  factory OrdenTrabajo.fromMap(Map<String, dynamic> map) {
    final vehiculo = map['vehiculo_info'] as Map<String, dynamic>?;
    final mecanico = map['inv_perfiles'] as Map<String, dynamic>?;
    return OrdenTrabajo(
      id: map['id'] as String,
      codigoOt: map['codigo_ot'] as String? ?? '',
      vehiculoCod: map['vehiculo_cod'] as String? ?? '',
      vehiculoProducto: vehiculo?['producto'] as String?,
      mecanicoId: map['mecanico_id'] as String? ?? '',
      mecanicoNombre: mecanico?['nombre'] as String?,
      kilometrajeActual: map['kilometraje_actual'] as int? ?? 0,
      descripcionFallo: map['descripcion_fallo'] as String? ?? '',
      estado: map['estado'] as String? ?? 'ABIERTA',
      firmaMecanicoUrl: map['firma_mecanico_url'] as String?,
      fotoFallaUrl: map['foto_falla_url'] as String?,
      fotoRepuestoNuevoUrl: map['foto_repuesto_nuevo_url'] as String?,
      creadoEn: DateTime.parse(map['created_at'] as String),
      cerradoEn: map['closed_at'] != null ? DateTime.parse(map['closed_at'] as String) : null,
    );
  }
}
