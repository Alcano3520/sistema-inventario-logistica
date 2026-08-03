class ModuloInfo {
  final String clave;
  final String emoji;
  final String titulo;
  final bool disponible;

  const ModuloInfo({
    required this.clave,
    required this.emoji,
    required this.titulo,
    this.disponible = true,
  });
}

/// Catálogo central de módulos/inventarios de la aplicación. Al agregar un
/// inventario nuevo (por ejemplo Motos), se suma aquí y en el selector.
const modulosDisponibles = [
  ModuloInfo(clave: 'barcos', emoji: '🚤', titulo: 'INVENTARIO_BARCOS'),
  ModuloInfo(clave: 'motos', emoji: '🏍️', titulo: 'INVENTARIO_MOTOS', disponible: false),
];
