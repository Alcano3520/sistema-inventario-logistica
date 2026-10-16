class RepuestoRetirado {
  final String id;
  final String? repuestoId;
  final String? repuestoNombre;
  final String? ordenTrabajoId;
  final String? codigoOt;
  final String vehiculoCod;
  final num cantidad;
  final String estadoPieza;
  final String estadoGestion;
  final String? fotoEvidenciaUrl;
  final DateTime creadoEn;

  const RepuestoRetirado({
    required this.id,
    this.repuestoId,
    this.repuestoNombre,
    this.ordenTrabajoId,
    this.codigoOt,
    required this.vehiculoCod,
    required this.cantidad,
    required this.estadoPieza,
    required this.estadoGestion,
    this.fotoEvidenciaUrl,
    required this.creadoEn,
  });

  bool get enCustodia => estadoGestion == 'EN_CUSTODIA';

  factory RepuestoRetirado.fromMap(Map<String, dynamic> map) {
    final repuesto = map['repuesto_info'] as Map<String, dynamic>?;
    final ot = map['ot_info'] as Map<String, dynamic>?;
    return RepuestoRetirado(
      id: map['id'] as String,
      repuestoId: map['repuesto_original_id'] as String?,
      repuestoNombre: repuesto?['nombre'] as String?,
      ordenTrabajoId: map['orden_trabajo_id'] as String?,
      codigoOt: ot?['codigo_ot'] as String?,
      vehiculoCod: map['vehiculo_cod'] as String? ?? '',
      cantidad: map['cantidad'] as num? ?? 0,
      estadoPieza: map['estado_pieza'] as String? ?? 'DANADO_REEMPLAZADO',
      estadoGestion: map['estado_gestion'] as String? ?? 'EN_CUSTODIA',
      fotoEvidenciaUrl: map['foto_evidencia_url'] as String?,
      creadoEn: DateTime.parse(map['created_at'] as String),
    );
  }
}
