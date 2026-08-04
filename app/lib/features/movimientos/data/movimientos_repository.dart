import 'dart:typed_data';

import '../../../core/modulos.dart';
import '../../../core/supabase_config.dart';
import '../domain/item_movimiento.dart';

class MovimientosRepository {
  final ModuloTablas tablas;

  const MovimientosRepository(this.tablas);

  String _rutaFirma(String subcarpeta, String idTransaccion) {
    final prefijo = tablas.carpetaFirmas.isEmpty ? '' : '${tablas.carpetaFirmas}/';
    return '$prefijo$subcarpeta/$idTransaccion.png';
  }

  Future<void> registrarEntrada({
    required DateTime fecha,
    required String proveedor,
    required String numFactura,
    required String observaciones,
    required String usuarioId,
    required String usuarioNombre,
    required List<ItemMovimiento> items,
    Uint8List? firma,
  }) async {
    final transaccion = await supabase
        .from(tablas.transaccionesEntrada)
        .insert({
          'fecha_hora': fecha.toIso8601String(),
          'proveedor': proveedor,
          'num_factura': numFactura,
          'observaciones': observaciones,
          'usuario_id': usuarioId,
          'usuario_nombre': usuarioNombre,
        })
        .select()
        .single();

    final idTransaccion = transaccion['id_transaccion'] as String;

    await supabase.from(tablas.detalleEntradas).insert(items
        .map((i) => {
              'id_transaccion': idTransaccion,
              'cod': i.cod,
              'producto': i.producto,
              'cantidad': num.parse(i.cantidad),
            })
        .toList());

    if (firma != null) {
      await _subirFirma(
          bucketPath: _rutaFirma('entradas', idTransaccion),
          bytes: firma,
          tabla: tablas.transaccionesEntrada,
          idTransaccion: idTransaccion);
    }
  }

  Future<void> registrarSalida({
    required DateTime fecha,
    required String bote,
    required String aQuienEntrega,
    required String proposito,
    required String usuarioId,
    required String usuarioNombre,
    required List<ItemMovimiento> items,
    Uint8List? firma,
  }) async {
    final transaccion = await supabase
        .from(tablas.transaccionesSalida)
        .insert({
          'fecha_hora': fecha.toIso8601String(),
          'bote': bote,
          'a_quien_entrega': aQuienEntrega,
          'proposito': proposito,
          'usuario_id': usuarioId,
          'usuario_nombre': usuarioNombre,
        })
        .select()
        .single();

    final idTransaccion = transaccion['id_transaccion'] as String;

    await supabase.from(tablas.detalleSalidas).insert(items
        .map((i) => {
              'id_transaccion': idTransaccion,
              'cod': i.cod,
              'producto': i.producto,
              'cantidad': num.parse(i.cantidad),
            })
        .toList());

    if (firma != null) {
      await _subirFirma(
          bucketPath: _rutaFirma('salidas', idTransaccion),
          bytes: firma,
          tabla: tablas.transaccionesSalida,
          idTransaccion: idTransaccion);
    }
  }

  Future<void> _subirFirma({
    required String bucketPath,
    required Uint8List bytes,
    required String tabla,
    required String idTransaccion,
  }) async {
    try {
      await supabase.storage.from('inv-firmas').uploadBinary(bucketPath, bytes);
      await supabase.from(tabla).update({'firma_url': bucketPath}).eq('id_transaccion', idTransaccion);
    } catch (_) {
      // La firma es complementaria; si falla la subida no se bloquea el registro del movimiento.
    }
  }
}
