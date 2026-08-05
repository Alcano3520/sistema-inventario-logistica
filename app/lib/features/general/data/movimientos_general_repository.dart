import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_config.dart';
import '../domain/empleado_externo.dart';
import '../domain/item_carrito.dart';
import '../domain/movimiento_general.dart';
import 'offline_queue_general.dart';

/// Repositorio de movimientos del módulo General. Las operaciones de
/// entrega/devolución son offline-aware: si no hay conexión (o falla la
/// escritura), se encolan en Hive (ver [OfflineQueueGeneral]) en vez de
/// fallar, y [SyncGeneralService] las reproduce más tarde llamando a los
/// mismos métodos `*Cruda` que usa el camino en línea. El stock nunca se
/// calcula en el cliente: cada INSERT dispara el trigger atómico en
/// Postgres, así que no hay condición de carrera entre dispositivos.
class MovimientosGeneralRepository {
  static const _uuid = Uuid();

  Future<bool> get _hayConexion async {
    final resultado = await Connectivity().checkConnectivity();
    return !resultado.contains(ConnectivityResult.none);
  }

  Future<String?> _subirFirma({
    required Uint8List firma,
    required String carpeta,
    required String grupoId,
  }) async {
    try {
      final path = 'general/$carpeta/$grupoId.png';
      await supabase.storage.from('inv-firmas').uploadBinary(path, firma);
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Registra una entrega (una o varias líneas) a un empleado. Devuelve
  /// `true` si se guardó directo en Supabase, `false` si quedó encolada
  /// localmente por falta de conexión.
  Future<bool> registrarEntrega({
    required List<ItemCarrito> items,
    EmpleadoExterno? empleado,
    required String nombreManual,
    required String cedulaManual,
    String? cargoManual,
    String? baseManual,
    required String usuarioId,
    required String usuarioNombre,
    String observaciones = '',
    Uint8List? firma,
  }) async {
    final datos = {
      'items': items
          .map((i) => {
                'articulo_id': i.articulo.id,
                'cantidad': i.cantidad,
                'aplica_descuento': i.aplicaDescuento,
                'valor_descuento': i.aplicaDescuento ? i.valorDescuentoPersonalizado : 0,
                'talla': i.talla,
                'observacion': i.observacion,
              })
          .toList(),
      'empleado_cedula': empleado?.cedula ?? cedulaManual,
      'empleado_nombre': empleado?.nombreCompleto ?? nombreManual,
      'empleado_cargo': empleado?.cargo ?? cargoManual,
      'empleado_base': baseManual,
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'observaciones': observaciones,
      'firma': firma,
    };

    if (!await _hayConexion) {
      await OfflineQueueGeneral.encolar('entrega', datos);
      return false;
    }
    try {
      await registrarEntregaCruda(datos);
      return true;
    } catch (_) {
      await OfflineQueueGeneral.encolar('entrega', datos);
      return false;
    }
  }

  /// Registra una devolución (una o varias líneas). Devuelve `true` si se
  /// guardó directo, `false` si quedó encolada localmente.
  Future<bool> registrarDevolucion({
    required List<ItemCarrito> items,
    EmpleadoExterno? empleado,
    required String nombreManual,
    required String cedulaManual,
    String? cargoManual,
    required String usuarioId,
    required String usuarioNombre,
    String observaciones = '',
  }) async {
    final datos = {
      'items': items
          .map((i) => {
                'articulo_id': i.articulo.id,
                'cantidad': i.cantidad,
                'condicion': i.condicion,
                'observacion': i.observacion,
              })
          .toList(),
      'empleado_cedula': empleado?.cedula ?? cedulaManual,
      'empleado_nombre': empleado?.nombreCompleto ?? nombreManual,
      'empleado_cargo': empleado?.cargo ?? cargoManual,
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'observaciones': observaciones,
    };

    if (!await _hayConexion) {
      await OfflineQueueGeneral.encolar('devolucion', datos);
      return false;
    }
    try {
      await registrarDevolucionCruda(datos);
      return true;
    } catch (_) {
      await OfflineQueueGeneral.encolar('devolucion', datos);
      return false;
    }
  }

  /// Inserta directamente en Supabase a partir de un mapa "en bruto" (usado
  /// tanto por [registrarEntrega] como por [SyncGeneralService] al
  /// reproducir la cola offline).
  Future<void> registrarEntregaCruda(Map<String, dynamic> datos) async {
    final grupoId = _uuid.v4();
    final firma = datos['firma'] as Uint8List?;
    String? firmaUrl;
    if (firma != null) {
      firmaUrl = await _subirFirma(firma: firma, carpeta: 'entregas', grupoId: grupoId);
    }

    final items = (datos['items'] as List).cast<Map>();
    for (final item in items) {
      final talla = (item['talla'] as String? ?? '').trim();
      final observacion = (item['observacion'] as String? ?? '').trim();
      await supabase.from('inv_general_movimientos').insert({
        'articulo_id': item['articulo_id'],
        'tipo_movimiento': 'SALIDA',
        'cantidad': item['cantidad'],
        'stock_anterior': 0,
        'stock_nuevo': 0,
        'usuario_id': datos['usuario_id'],
        'usuario_nombre': datos['usuario_nombre'],
        'empleado_cedula': datos['empleado_cedula'],
        'empleado_nombre': datos['empleado_nombre'],
        'empleado_cargo': datos['empleado_cargo'],
        'empleado_base': datos['empleado_base'],
        'aplica_descuento': item['aplica_descuento'] ?? false,
        'valor_descuento': item['valor_descuento'] ?? 0,
        'talla': talla.isEmpty ? null : talla,
        'observaciones': observacion.isEmpty ? (datos['observaciones'] as String? ?? '') : observacion,
        'firma_url': firmaUrl,
        'entrega_grupo_id': grupoId,
      });
    }
  }

  Future<void> registrarDevolucionCruda(Map<String, dynamic> datos) async {
    final grupoId = _uuid.v4();
    final items = (datos['items'] as List).cast<Map>();
    for (final item in items) {
      final observacion = (item['observacion'] as String? ?? '').trim();
      await supabase.from('inv_general_movimientos').insert({
        'articulo_id': item['articulo_id'],
        'tipo_movimiento': 'DEVOLUCION',
        'cantidad': item['cantidad'],
        'stock_anterior': 0,
        'stock_nuevo': 0,
        'usuario_id': datos['usuario_id'],
        'usuario_nombre': datos['usuario_nombre'],
        'empleado_cedula': datos['empleado_cedula'],
        'empleado_nombre': datos['empleado_nombre'],
        'empleado_cargo': datos['empleado_cargo'],
        'condicion': item['condicion'],
        'observaciones': observacion.isEmpty ? (datos['observaciones'] as String? ?? '') : observacion,
        'entrega_grupo_id': grupoId,
      });
    }
  }

  Future<void> registrarEntradaStock({
    required String articuloId,
    required num cantidad,
    required num stockActual,
    required String usuarioId,
    required String usuarioNombre,
    String motivo = '',
    String observaciones = '',
  }) async {
    await supabase.from('inv_general_movimientos').insert({
      'articulo_id': articuloId,
      'tipo_movimiento': 'ENTRADA',
      'cantidad': cantidad,
      'stock_anterior': stockActual,
      'stock_nuevo': stockActual + cantidad,
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'motivo': motivo,
      'observaciones': observaciones,
    });
  }

  Future<void> registrarAjuste({
    required String articuloId,
    required num stockAnterior,
    required num stockNuevo,
    required String usuarioId,
    required String usuarioNombre,
    String motivo = '',
    String observaciones = '',
  }) async {
    final diferencia = (stockNuevo - stockAnterior).abs();
    await supabase.from('inv_general_movimientos').insert({
      'articulo_id': articuloId,
      'tipo_movimiento': 'AJUSTE',
      'cantidad': diferencia == 0 ? 1 : diferencia,
      'stock_anterior': stockAnterior,
      'stock_nuevo': stockNuevo,
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'motivo': motivo,
      'observaciones': observaciones,
    });
  }

  Future<void> registrarBaja({
    required String articuloId,
    required num cantidad,
    required num stockActual,
    required String usuarioId,
    required String usuarioNombre,
    String motivo = '',
    String observaciones = '',
  }) async {
    await supabase.from('inv_general_movimientos').insert({
      'articulo_id': articuloId,
      'tipo_movimiento': 'BAJA',
      'cantidad': cantidad,
      'stock_anterior': stockActual,
      'stock_nuevo': stockActual - cantidad,
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'motivo': motivo,
      'observaciones': observaciones,
    });
  }

  Future<List<MovimientoGeneral>> obtenerHistorial({
    String? tipoMovimiento,
    DateTime? desde,
    DateTime? hasta,
    int limite = 200,
  }) async {
    var query = supabase
        .from('inv_general_movimientos')
        .select('*, inv_general_articulos(descripcion, codigo_interno)');
    if (tipoMovimiento != null) query = query.eq('tipo_movimiento', tipoMovimiento);
    if (desde != null) query = query.gte('fecha_movimiento', desde.toIso8601String());
    if (hasta != null) query = query.lte('fecha_movimiento', hasta.toIso8601String());

    final data = await query.order('fecha_movimiento', ascending: false).limit(limite);
    return (data as List).map((e) => MovimientoGeneral.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> anular(String movimientoId, String motivo) async {
    await supabase.rpc('inv_general_anular_movimiento', params: {
      'p_movimiento_id': movimientoId,
      'p_motivo': motivo,
    });
  }

  Future<Map<String, dynamic>> recalcularStocks() async {
    final data = await supabase.rpc('inv_general_recalcular_stocks');
    return Map<String, dynamic>.from(data as Map);
  }
}
