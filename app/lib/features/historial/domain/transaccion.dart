class DetalleItem {
  final String cod;
  final String producto;
  final num cantidad;

  const DetalleItem({required this.cod, required this.producto, required this.cantidad});

  factory DetalleItem.fromMap(Map<String, dynamic> map) {
    return DetalleItem(
      cod: map['cod'] as String? ?? '',
      producto: map['producto'] as String? ?? '',
      cantidad: map['cantidad'] as num? ?? 0,
    );
  }
}

class TransaccionEntrada {
  final String idTransaccion;
  final DateTime fechaHora;
  final String proveedor;
  final String numFactura;
  final String usuarioNombre;
  final String observaciones;
  final String? firmaUrl;
  final List<DetalleItem> items;

  const TransaccionEntrada({
    required this.idTransaccion,
    required this.fechaHora,
    required this.proveedor,
    required this.numFactura,
    required this.usuarioNombre,
    required this.observaciones,
    required this.firmaUrl,
    required this.items,
  });

  factory TransaccionEntrada.fromMap(Map<String, dynamic> map) {
    return TransaccionEntrada(
      idTransaccion: map['id_transaccion'] as String,
      fechaHora: DateTime.parse(map['fecha_hora'] as String),
      proveedor: map['proveedor'] as String? ?? '',
      numFactura: map['num_factura'] as String? ?? '',
      usuarioNombre: map['usuario_nombre'] as String? ?? '',
      observaciones: map['observaciones'] as String? ?? '',
      firmaUrl: map['firma_url'] as String?,
      items: ((map['detalles'] as List?) ?? [])
          .map((e) => DetalleItem.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TransaccionSalida {
  final String idTransaccion;
  final DateTime fechaHora;
  final String bote;
  final String aQuienEntrega;
  final String proposito;
  final String usuarioNombre;
  final String? firmaUrl;
  final List<DetalleItem> items;

  const TransaccionSalida({
    required this.idTransaccion,
    required this.fechaHora,
    required this.bote,
    required this.aQuienEntrega,
    required this.proposito,
    required this.usuarioNombre,
    required this.firmaUrl,
    required this.items,
  });

  factory TransaccionSalida.fromMap(Map<String, dynamic> map) {
    return TransaccionSalida(
      idTransaccion: map['id_transaccion'] as String,
      fechaHora: DateTime.parse(map['fecha_hora'] as String),
      bote: map['bote'] as String? ?? '',
      aQuienEntrega: map['a_quien_entrega'] as String? ?? '',
      proposito: map['proposito'] as String? ?? '',
      usuarioNombre: map['usuario_nombre'] as String? ?? '',
      firmaUrl: map['firma_url'] as String?,
      items: ((map['detalles'] as List?) ?? [])
          .map((e) => DetalleItem.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
