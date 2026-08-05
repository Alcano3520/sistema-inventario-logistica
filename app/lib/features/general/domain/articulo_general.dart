class ArticuloGeneral {
  final String id;
  final String codigoInterno;
  final String? codigoBarras;
  final String descripcion;
  final String categoria;
  final String? subcategoria;
  final num stockTotal;
  final num stockDisponible;
  final num stockConsignacion;
  final num stockDescontado;
  final num stockBaja;
  final num stockMinimo;
  final num valorUnitario;
  final num valorDescuento;
  final bool esDescontable;
  final bool requiereDevolucion;
  final String? ubicacionBodega;
  final String? proveedor;
  final bool activo;

  const ArticuloGeneral({
    required this.id,
    required this.codigoInterno,
    this.codigoBarras,
    required this.descripcion,
    required this.categoria,
    this.subcategoria,
    required this.stockTotal,
    required this.stockDisponible,
    required this.stockConsignacion,
    required this.stockDescontado,
    required this.stockBaja,
    required this.stockMinimo,
    required this.valorUnitario,
    required this.valorDescuento,
    required this.esDescontable,
    required this.requiereDevolucion,
    this.ubicacionBodega,
    this.proveedor,
    required this.activo,
  });

  bool get stockBajo => stockDisponible <= stockMinimo;

  factory ArticuloGeneral.fromMap(Map<String, dynamic> map) {
    return ArticuloGeneral(
      id: map['id'] as String,
      codigoInterno: map['codigo_interno'] as String,
      codigoBarras: map['codigo_barras'] as String?,
      descripcion: map['descripcion'] as String,
      categoria: map['categoria'] as String? ?? '',
      subcategoria: map['subcategoria'] as String?,
      stockTotal: map['stock_total'] as num? ?? 0,
      stockDisponible: map['stock_disponible'] as num? ?? 0,
      stockConsignacion: map['stock_consignacion'] as num? ?? 0,
      stockDescontado: map['stock_descontado'] as num? ?? 0,
      stockBaja: map['stock_baja'] as num? ?? 0,
      stockMinimo: map['stock_minimo'] as num? ?? 1,
      valorUnitario: map['valor_unitario'] as num? ?? 0,
      valorDescuento: map['valor_descuento'] as num? ?? 0,
      esDescontable: map['es_descontable'] as bool? ?? false,
      requiereDevolucion: map['requiere_devolucion'] as bool? ?? true,
      ubicacionBodega: map['ubicacion_bodega'] as String?,
      proveedor: map['proveedor'] as String?,
      activo: map['activo'] as bool? ?? true,
    );
  }
}
