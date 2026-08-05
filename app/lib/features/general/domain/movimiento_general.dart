class MovimientoGeneral {
  final String id;
  final String articuloId;
  final String? articuloDescripcion;
  final String? articuloCodigo;
  final String tipoMovimiento;
  final num cantidad;
  final DateTime fechaMovimiento;
  final String usuarioNombre;
  final String? empleadoCedula;
  final String? empleadoNombre;
  final String? empleadoCargo;
  final String? empleadoBase;
  final bool aplicaDescuento;
  final num valorDescuento;
  final String? talla;
  final String? condicion;
  final String? motivo;
  final String observaciones;
  final String? firmaUrl;
  final String? entregaGrupoId;
  final bool anulado;
  final String? motivoAnulacion;

  const MovimientoGeneral({
    required this.id,
    required this.articuloId,
    this.articuloDescripcion,
    this.articuloCodigo,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.fechaMovimiento,
    required this.usuarioNombre,
    this.empleadoCedula,
    this.empleadoNombre,
    this.empleadoCargo,
    this.empleadoBase,
    required this.aplicaDescuento,
    required this.valorDescuento,
    this.talla,
    this.condicion,
    this.motivo,
    required this.observaciones,
    this.firmaUrl,
    this.entregaGrupoId,
    required this.anulado,
    this.motivoAnulacion,
  });

  factory MovimientoGeneral.fromMap(Map<String, dynamic> map) {
    final articulo = map['inv_general_articulos'] as Map<String, dynamic>?;
    return MovimientoGeneral(
      id: map['id'] as String,
      articuloId: map['articulo_id'] as String,
      articuloDescripcion: articulo?['descripcion'] as String?,
      articuloCodigo: articulo?['codigo_interno'] as String?,
      tipoMovimiento: map['tipo_movimiento'] as String,
      cantidad: map['cantidad'] as num? ?? 0,
      fechaMovimiento: DateTime.parse(map['fecha_movimiento'] as String),
      usuarioNombre: map['usuario_nombre'] as String? ?? '',
      empleadoCedula: map['empleado_cedula'] as String?,
      empleadoNombre: map['empleado_nombre'] as String?,
      empleadoCargo: map['empleado_cargo'] as String?,
      empleadoBase: map['empleado_base'] as String?,
      aplicaDescuento: map['aplica_descuento'] as bool? ?? false,
      valorDescuento: map['valor_descuento'] as num? ?? 0,
      talla: map['talla'] as String?,
      condicion: map['condicion'] as String?,
      motivo: map['motivo'] as String?,
      observaciones: map['observaciones'] as String? ?? '',
      firmaUrl: map['firma_url'] as String?,
      entregaGrupoId: map['entrega_grupo_id'] as String?,
      anulado: map['anulado'] as bool? ?? false,
      motivoAnulacion: map['motivo_anulacion'] as String?,
    );
  }
}
