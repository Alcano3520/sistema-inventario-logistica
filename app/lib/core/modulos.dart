import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nombres de tablas/RPCs/almacenamiento y textos de UI específicos de un
/// módulo de inventario. Cada módulo tiene sus propias tablas en Supabase,
/// así que los datos de Barcos y Motos quedan completamente separados.
class ModuloTablas {
  final String productos;
  final String transaccionesEntrada;
  final String detalleEntradas;
  final String transaccionesSalida;
  final String detalleSalidas;
  final String rpcDetectarDuplicados;
  final String rpcEliminarDuplicados;
  final String rpcRecalcularStocks;

  /// Subcarpeta dentro del bucket `inv-firmas` (vacío = raíz, usado por Barcos
  /// para no romper las rutas de firmas ya existentes).
  final String carpetaFirmas;

  final String etiquetaVehiculo;
  final String hintVehiculo;
  final String ejemploVehiculo;

  const ModuloTablas({
    required this.productos,
    required this.transaccionesEntrada,
    required this.detalleEntradas,
    required this.transaccionesSalida,
    required this.detalleSalidas,
    required this.rpcDetectarDuplicados,
    required this.rpcEliminarDuplicados,
    required this.rpcRecalcularStocks,
    required this.carpetaFirmas,
    required this.etiquetaVehiculo,
    required this.hintVehiculo,
    required this.ejemploVehiculo,
  });
}

const _tablasBarcos = ModuloTablas(
  productos: 'inv_productos',
  transaccionesEntrada: 'inv_transacciones_entrada',
  detalleEntradas: 'inv_detalle_entradas',
  transaccionesSalida: 'inv_transacciones_salida',
  detalleSalidas: 'inv_detalle_salidas',
  rpcDetectarDuplicados: 'inv_detectar_duplicados',
  rpcEliminarDuplicados: 'inv_eliminar_duplicados',
  rpcRecalcularStocks: 'inv_recalcular_stocks',
  carpetaFirmas: '',
  etiquetaVehiculo: 'Bote',
  hintVehiculo: 'Ej: BOTE 1, BOTE 31',
  ejemploVehiculo: 'BOTE 31',
);

const _tablasMotos = ModuloTablas(
  productos: 'inv_motos_productos',
  transaccionesEntrada: 'inv_motos_transacciones_entrada',
  detalleEntradas: 'inv_motos_detalle_entradas',
  transaccionesSalida: 'inv_motos_transacciones_salida',
  detalleSalidas: 'inv_motos_detalle_salidas',
  rpcDetectarDuplicados: 'inv_motos_detectar_duplicados',
  rpcEliminarDuplicados: 'inv_motos_eliminar_duplicados',
  rpcRecalcularStocks: 'inv_motos_recalcular_stocks',
  carpetaFirmas: 'motos',
  etiquetaVehiculo: 'Moto',
  hintVehiculo: 'Ej: MOTO 1, PLACA ABC-123',
  ejemploVehiculo: 'MOTO 1',
);

const _tablasPorModulo = <String, ModuloTablas>{
  'barcos': _tablasBarcos,
  'motos': _tablasMotos,
};

ModuloTablas tablasDeModulo(String clave) => _tablasPorModulo[clave] ?? _tablasBarcos;

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
/// inventario nuevo, se suma aquí (con sus tablas en [_tablasPorModulo]) y
/// en el selector.
const modulosDisponibles = [
  ModuloInfo(clave: 'barcos', emoji: '🚤', titulo: 'INVENTARIO_BARCOS'),
  ModuloInfo(clave: 'motos', emoji: '🏍️', titulo: 'INVENTARIO_MOTOS'),
];

/// Módulo actualmente seleccionado por el usuario (se fija al elegir una
/// tarjeta en el selector, antes de entrar al [AppShell]).
final moduloActivoProvider = StateProvider<String>((ref) => 'barcos');

/// Tablas/RPCs correspondientes al módulo activo. Todos los repositorios de
/// datos dependen de este provider para saber contra qué tablas trabajar.
final tablasActivasProvider = Provider<ModuloTablas>((ref) {
  return tablasDeModulo(ref.watch(moduloActivoProvider));
});
