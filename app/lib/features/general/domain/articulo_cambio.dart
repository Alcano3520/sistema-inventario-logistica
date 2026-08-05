class ArticuloCambio {
  final String campo;
  final String? valorAnterior;
  final String? valorNuevo;
  final DateTime fecha;

  const ArticuloCambio({
    required this.campo,
    this.valorAnterior,
    this.valorNuevo,
    required this.fecha,
  });

  static const _etiquetas = {
    'descripcion': 'Descripción',
    'categoria': 'Categoría',
    'subcategoria': 'Subcategoría',
    'stock_minimo': 'Stock mínimo',
    'valor_unitario': 'Valor unitario',
    'valor_descuento': 'Valor de descuento',
    'es_descontable': 'Genera descuento',
    'requiere_devolucion': 'Requiere devolución',
    'ubicacion_bodega': 'Ubicación en bodega',
    'proveedor': 'Proveedor',
    'activo': 'Activo',
  };

  String get descripcionLegible {
    final etiqueta = _etiquetas[campo] ?? campo;
    return '$etiqueta cambió de "${valorAnterior ?? '-'}" a "${valorNuevo ?? '-'}"';
  }

  factory ArticuloCambio.fromMap(Map<String, dynamic> map) {
    return ArticuloCambio(
      campo: map['campo'] as String,
      valorAnterior: map['valor_anterior'] as String?,
      valorNuevo: map['valor_nuevo'] as String?,
      fecha: DateTime.parse(map['created_at'] as String),
    );
  }
}
