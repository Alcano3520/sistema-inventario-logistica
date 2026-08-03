class Producto {
  final String cod;
  final String producto;
  final num entrada;
  final num salida;
  final num stock;
  final String categoria;
  final String ubicacion;
  final num stockMinimo;

  const Producto({
    required this.cod,
    required this.producto,
    required this.entrada,
    required this.salida,
    required this.stock,
    required this.categoria,
    required this.ubicacion,
    required this.stockMinimo,
  });

  bool get sinStock => stock <= 0;
  bool get stockBajo => stockMinimo > 0 && stock <= stockMinimo;

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      cod: map['cod'] as String,
      producto: map['producto'] as String? ?? '',
      entrada: map['entrada'] as num? ?? 0,
      salida: map['salida'] as num? ?? 0,
      stock: map['stock'] as num? ?? 0,
      categoria: map['categoria'] as String? ?? '',
      ubicacion: map['ubicacion'] as String? ?? '',
      stockMinimo: map['stock_minimo'] as num? ?? 0,
    );
  }
}
