/// Un ítem detectado al leer el PDF de una factura — texto crudo, sin
/// confirmar contra el catálogo. [codigoProveedor] es el código tal como
/// aparece en la factura (del proveedor, no el interno) — solo se usa para
/// intentar emparejarlo con un producto ya existente cuyo código interno o
/// código de barras coincida EXACTO; si no hay coincidencia exacta, nunca se
/// inventa ni se fuerza un código: la persona lo elige con el buscador. Lo
/// demás (descripción, cantidad, precio) siempre sirve como punto de partida
/// para no tener que tipearlo de nuevo.
class ItemFacturaExtraido {
  final String descripcion;
  final num? cantidad;
  final num? precioUnitario;
  final String? codigoProveedor;

  const ItemFacturaExtraido({
    required this.descripcion,
    this.cantidad,
    this.precioUnitario,
    this.codigoProveedor,
  });
}

/// Resultado de leer el PDF de una factura (RIDE del SRI) — campos
/// detectados por heurística a partir del texto del documento. Todos son
/// opcionales porque el formato varía mucho entre proveedores: lo que no se
/// detecta queda en null y la persona lo completa a mano como siempre.
class FacturaExtraida {
  final String? proveedor;
  final String? numFactura;
  final String? claveAcceso;
  final DateTime? fecha;
  final List<ItemFacturaExtraido> items;

  const FacturaExtraida({
    this.proveedor,
    this.numFactura,
    this.claveAcceso,
    this.fecha,
    this.items = const [],
  });

  bool get tieneAlgo =>
      proveedor != null || numFactura != null || claveAcceso != null || fecha != null || items.isNotEmpty;
}
