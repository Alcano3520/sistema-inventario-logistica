class DescuentoNomina {
  final String id;
  final String? movimientoId;
  final String empleadoCedula;
  final String empleadoNombre;
  final String? empleadoCargo;
  final String articuloDescripcion;
  final num valorDescuento;
  final DateTime fechaEntrega;
  final bool exportado;
  final DateTime? fechaExportacion;
  final String? loteNumero;
  final String? observaciones;

  const DescuentoNomina({
    required this.id,
    this.movimientoId,
    required this.empleadoCedula,
    required this.empleadoNombre,
    this.empleadoCargo,
    required this.articuloDescripcion,
    required this.valorDescuento,
    required this.fechaEntrega,
    required this.exportado,
    this.fechaExportacion,
    this.loteNumero,
    this.observaciones,
  });

  factory DescuentoNomina.fromMap(Map<String, dynamic> map) {
    return DescuentoNomina(
      id: map['id'] as String,
      movimientoId: map['movimiento_id'] as String?,
      empleadoCedula: map['empleado_cedula'] as String? ?? '',
      empleadoNombre: map['empleado_nombre'] as String? ?? '',
      empleadoCargo: map['empleado_cargo'] as String?,
      articuloDescripcion: map['articulo_descripcion'] as String? ?? '',
      valorDescuento: map['valor_descuento'] as num? ?? 0,
      fechaEntrega: DateTime.parse(map['fecha_entrega'] as String),
      exportado: map['exportado'] as bool? ?? false,
      fechaExportacion:
          map['fecha_exportacion'] != null ? DateTime.parse(map['fecha_exportacion'] as String) : null,
      loteNumero: map['lote_numero'] as String?,
      observaciones: map['observaciones'] as String?,
    );
  }
}
