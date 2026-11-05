class DetalleItem {
  /// `id` de la fila en `inv_detalle_entradas`/`inv_detalle_salidas` — null
  /// si este detalle no vino de una consulta directa a esa tabla (p.ej. en
  /// el kardex por producto, que no lo necesita). Se usa para poder editar
  /// una línea puntual de una factura ya registrada.
  final int? id;
  final String cod;
  final String producto;
  final num cantidad;
  final num? precioUnitario;

  const DetalleItem({
    this.id,
    required this.cod,
    required this.producto,
    required this.cantidad,
    this.precioUnitario,
  });

  factory DetalleItem.fromMap(Map<String, dynamic> map) {
    return DetalleItem(
      id: map['id'] as int?,
      cod: map['cod'] as String? ?? '',
      producto: map['producto'] as String? ?? '',
      cantidad: map['cantidad'] as num? ?? 0,
      precioUnitario: map['precio_unitario'] as num?,
    );
  }
}

class TransaccionEntrada {
  final String idTransaccion;
  final DateTime fechaHora;
  final String proveedor;
  final String numFactura;
  final String usuarioId;
  final String usuarioNombre;
  final String observaciones;
  final String? firmaUrl;
  final String? claveAccesoSri;
  final String? fotoFacturaUrl;
  final List<DetalleItem> items;

  /// Cuándo se registró de verdad (no confundir con [fechaHora], que es la
  /// fecha del movimiento y puede corregirse) — con esto se calcula si
  /// quien lo registró todavía puede autocorregirlo (hoy: todo; día 2-3:
  /// solo la fecha; después: ya no).
  final DateTime createdAt;

  const TransaccionEntrada({
    required this.idTransaccion,
    required this.fechaHora,
    required this.proveedor,
    required this.numFactura,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.observaciones,
    required this.firmaUrl,
    this.claveAccesoSri,
    this.fotoFacturaUrl,
    required this.items,
    required this.createdAt,
  });

  factory TransaccionEntrada.fromMap(Map<String, dynamic> map) {
    return TransaccionEntrada(
      idTransaccion: map['id_transaccion'] as String,
      fechaHora: DateTime.parse(map['fecha_hora'] as String),
      proveedor: map['proveedor'] as String? ?? '',
      numFactura: map['num_factura'] as String? ?? '',
      usuarioId: map['usuario_id'] as String? ?? '',
      usuarioNombre: map['usuario_nombre'] as String? ?? '',
      observaciones: map['observaciones'] as String? ?? '',
      firmaUrl: map['firma_url'] as String?,
      claveAccesoSri: map['clave_acceso_sri'] as String?,
      fotoFacturaUrl: map['foto_factura_url'] as String?,
      items: ((map['detalles'] as List?) ?? [])
          .map((e) => DetalleItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Un movimiento puntual (entrada o salida) de UN producto en particular —
/// usado en el historial por producto, que se muestra directo en
/// Inventario/Productos al abrir el detalle de un artículo.
class MovimientoProducto {
  final DateTime fecha;
  final String tipo; // 'Entrada' | 'Salida'
  final num cantidad;

  /// `id_transaccion` de la Entrada/Salida de la que vino este movimiento —
  /// para poder abrir "Editar factura" directo desde la ficha del producto.
  final String idTransaccion;

  /// Quién registró este movimiento y cuándo — para calcular si todavía
  /// puede autocorregirlo (ver [capacidadEdicion]).
  final String usuarioId;
  final DateTime creadoEn;

  // Entrada:
  final String? proveedor;
  final String? numFactura;

  // Salida:
  final String? aQuien;
  final String? proposito;

  /// Ruta en storage (bucket privado `inv-firmas`) de la firma y, en
  /// salidas, de la foto de sustento — ambas opcionales (las salidas
  /// anteriores a que la foto fuera obligatoria no la tienen).
  final String? firmaUrl;
  final String? fotoSustentoUrl;

  /// Entrada: foto opcional de la factura física.
  final String? fotoFacturaUrl;

  /// Saldo (stock) justo después de este movimiento, calculado en orden
  /// cronológico — como un kardex: cada entrada suma, cada salida resta.
  final num saldo;

  const MovimientoProducto({
    required this.fecha,
    required this.tipo,
    required this.cantidad,
    required this.idTransaccion,
    required this.usuarioId,
    required this.creadoEn,
    this.proveedor,
    this.numFactura,
    this.aQuien,
    this.proposito,
    this.firmaUrl,
    this.fotoSustentoUrl,
    this.fotoFacturaUrl,
    required this.saldo,
  });
}

class TransaccionSalida {
  final String idTransaccion;
  final DateTime fechaHora;
  final String bote;
  final String aQuienEntrega;
  final String identificacionQuienRecibe;
  final bool confirmacionRecepcion;
  final String proposito;
  final String usuarioId;
  final String usuarioNombre;
  final String? firmaUrl;
  final String? peticionTexto;
  final String? peticionFotoUrl;
  final List<DetalleItem> items;

  /// Ver nota en [TransaccionEntrada.createdAt] — mismo propósito.
  final DateTime createdAt;

  const TransaccionSalida({
    required this.idTransaccion,
    required this.fechaHora,
    required this.bote,
    required this.aQuienEntrega,
    required this.identificacionQuienRecibe,
    required this.confirmacionRecepcion,
    required this.proposito,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.firmaUrl,
    this.peticionTexto,
    this.peticionFotoUrl,
    required this.items,
    required this.createdAt,
  });

  factory TransaccionSalida.fromMap(Map<String, dynamic> map) {
    return TransaccionSalida(
      idTransaccion: map['id_transaccion'] as String,
      fechaHora: DateTime.parse(map['fecha_hora'] as String),
      bote: map['bote'] as String? ?? '',
      aQuienEntrega: map['a_quien_entrega'] as String? ?? '',
      identificacionQuienRecibe: map['identificacion_quien_recibe'] as String? ?? '',
      confirmacionRecepcion: map['confirmacion_recepcion'] as bool? ?? false,
      proposito: map['proposito'] as String? ?? '',
      usuarioId: map['usuario_id'] as String? ?? '',
      usuarioNombre: map['usuario_nombre'] as String? ?? '',
      firmaUrl: map['firma_url'] as String?,
      peticionTexto: map['peticion_texto'] as String?,
      peticionFotoUrl: map['peticion_foto_url'] as String?,
      items: ((map['detalles'] as List?) ?? [])
          .map((e) => DetalleItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
