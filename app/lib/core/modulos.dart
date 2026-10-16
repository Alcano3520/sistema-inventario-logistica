import 'package:flutter/material.dart';
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

  /// Taller: repuestos, órdenes de trabajo, despacho y custodia de piezas
  /// retiradas. Barcos y Motos comparten las mismas pantallas de
  /// `features/taller_motos`, cada uno contra su propio set de tablas.
  final String ordenesTrabajo;
  final String repuestos;
  final String repuestosCodigos;
  final String repuestosIngresos;
  final String otConsumo;
  final String repuestosRetirados;
  final String actasBaja;
  final String actasBajaDetalle;

  /// Qué mide el taller al abrir una OT: "Kilometraje actual" en motos,
  /// "Horas de motor actuales" en botes.
  final String etiquetaMedidor;

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
    required this.ordenesTrabajo,
    required this.repuestos,
    required this.repuestosCodigos,
    required this.repuestosIngresos,
    required this.otConsumo,
    required this.repuestosRetirados,
    required this.actasBaja,
    required this.actasBajaDetalle,
    required this.etiquetaMedidor,
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
  ordenesTrabajo: 'inv_barcos_ordenes_trabajo',
  repuestos: 'inv_barcos_repuestos',
  repuestosCodigos: 'inv_barcos_repuestos_codigos',
  repuestosIngresos: 'inv_barcos_repuestos_ingresos',
  otConsumo: 'inv_barcos_ot_consumo',
  repuestosRetirados: 'inv_barcos_repuestos_retirados',
  actasBaja: 'inv_barcos_actas_baja',
  actasBajaDetalle: 'inv_barcos_actas_baja_detalle',
  etiquetaMedidor: 'Horas de motor actuales',
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
  ordenesTrabajo: 'inv_motos_ordenes_trabajo',
  repuestos: 'inv_motos_repuestos',
  repuestosCodigos: 'inv_motos_repuestos_codigos',
  repuestosIngresos: 'inv_motos_repuestos_ingresos',
  otConsumo: 'inv_motos_ot_consumo',
  repuestosRetirados: 'inv_motos_repuestos_retirados',
  actasBaja: 'inv_motos_actas_baja',
  actasBajaDetalle: 'inv_motos_actas_baja_detalle',
  etiquetaMedidor: 'Kilometraje actual',
);

const _tablasPruebas = ModuloTablas(
  productos: 'inv_pruebas_productos',
  transaccionesEntrada: 'inv_pruebas_transacciones_entrada',
  detalleEntradas: 'inv_pruebas_detalle_entradas',
  transaccionesSalida: 'inv_pruebas_transacciones_salida',
  detalleSalidas: 'inv_pruebas_detalle_salidas',
  rpcDetectarDuplicados: 'inv_pruebas_detectar_duplicados',
  rpcEliminarDuplicados: 'inv_pruebas_eliminar_duplicados',
  rpcRecalcularStocks: 'inv_pruebas_recalcular_stocks',
  carpetaFirmas: 'pruebas',
  etiquetaVehiculo: 'Vehículo/Referencia',
  hintVehiculo: 'Ej: PRUEBA 1 (cualquier texto, es solo para probar)',
  ejemploVehiculo: 'PRUEBA 1',
  // Pruebas no tiene Taller — AppShell._tieneTaller solo lo habilita para
  // 'motos'/'barcos', así que estos nombres nunca se consultan en la
  // práctica. Se dejan apuntando a tablas inexistentes a propósito, para
  // que un futuro uso accidental falle alto y claro en vez de silencioso.
  ordenesTrabajo: 'inv_pruebas_ordenes_trabajo',
  repuestos: 'inv_pruebas_repuestos',
  repuestosCodigos: 'inv_pruebas_repuestos_codigos',
  repuestosIngresos: 'inv_pruebas_repuestos_ingresos',
  otConsumo: 'inv_pruebas_ot_consumo',
  repuestosRetirados: 'inv_pruebas_repuestos_retirados',
  actasBaja: 'inv_pruebas_actas_baja',
  actasBajaDetalle: 'inv_pruebas_actas_baja_detalle',
  etiquetaMedidor: 'Medidor (no aplica)',
);

const _tablasPorModulo = <String, ModuloTablas>{
  'barcos': _tablasBarcos,
  'motos': _tablasMotos,
  'pruebas': _tablasPruebas,
};

ModuloTablas tablasDeModulo(String clave) => _tablasPorModulo[clave] ?? _tablasBarcos;

/// Los módulos "simples" (Barcos/Motos) comparten las mismas pantallas de
/// productos/entrada/salida, solo cambia la tabla. "Dotación" (Inventario
/// General) es un flujo completamente distinto (entregas a empleados,
/// descuentos de nómina, devoluciones, correcciones) con sus propias
/// pantallas, así que [AppShell] arma un menú diferente según este tipo.
enum TipoModulo { simple, dotacion }

class ModuloInfo {
  final String clave;
  final IconData icono;
  final String titulo;
  final bool disponible;
  final TipoModulo tipo;

  const ModuloInfo({
    required this.clave,
    required this.icono,
    required this.titulo,
    this.disponible = true,
    this.tipo = TipoModulo.simple,
  });
}

/// Catálogo central de módulos/inventarios de la aplicación. Al agregar un
/// inventario nuevo, se suma aquí (con sus tablas en [_tablasPorModulo] si
/// es de tipo simple) y en el selector.
const modulosDisponibles = [
  ModuloInfo(
      clave: 'general',
      icono: Icons.inventory_outlined,
      titulo: 'Inventario Dotación Empleados',
      tipo: TipoModulo.dotacion),
  ModuloInfo(clave: 'barcos', icono: Icons.directions_boat_outlined, titulo: 'Inventario Barcos'),
  ModuloInfo(clave: 'motos', icono: Icons.two_wheeler_outlined, titulo: 'Inventario Motos'),
  ModuloInfo(clave: 'pruebas', icono: Icons.bug_report_outlined, titulo: 'PRUEBAS'),
];

/// Módulo actualmente seleccionado por el usuario (se fija al elegir una
/// tarjeta en el selector, antes de entrar al [AppShell]).
final moduloActivoProvider = StateProvider<String>((ref) => 'barcos');

/// Tablas/RPCs correspondientes al módulo activo. Todos los repositorios de
/// datos dependen de este provider para saber contra qué tablas trabajar.
final tablasActivasProvider = Provider<ModuloTablas>((ref) {
  return tablasDeModulo(ref.watch(moduloActivoProvider));
});
