class Repuesto {
  final String id;
  final String codigoBarras;
  final String nombre;
  final int stockActual;
  final int stockMinimo;
  final int kilometrajeVidaUtil;
  final bool requierePiezaUsada;

  const Repuesto({
    required this.id,
    required this.codigoBarras,
    required this.nombre,
    required this.stockActual,
    required this.stockMinimo,
    required this.kilometrajeVidaUtil,
    required this.requierePiezaUsada,
  });

  bool get stockBajo => stockActual <= stockMinimo;

  factory Repuesto.fromMap(Map<String, dynamic> map) {
    return Repuesto(
      id: map['id'] as String,
      codigoBarras: map['codigo_barras'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      stockActual: map['stock_actual'] as int? ?? 0,
      stockMinimo: map['stock_minimo'] as int? ?? 0,
      kilometrajeVidaUtil: map['kilometraje_vida_util'] as int? ?? 5000,
      requierePiezaUsada: map['requiere_pieza_usada'] as bool? ?? true,
    );
  }
}
