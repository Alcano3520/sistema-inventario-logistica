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
    String? claveAccesoSri,
    Uint8List? fotoFactura,
  }) async {
    final clave = claveAccesoSri?.trim();
    final transaccion = await supabase
        .from(tablas.transaccionesEntrada)
        .insert({
          'fecha_hora': fecha.toIso8601String(),
          'proveedor': proveedor,
          'num_factura': numFactura,
          'observaciones': observaciones,
          'usuario_id': usuarioId,
          'usuario_nombre': usuarioNombre,
          'clave_acceso_sri': (clave == null || clave.isEmpty) ? null : clave,
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
              'precio_unitario': num.tryParse(i.precioUnitario),
            })
        .toList());

    if (firma != null) {
      await _subirFirma(
          bucketPath: _rutaFirma('entradas', idTransaccion),
          bytes: firma,
          tabla: tablas.transaccionesEntrada,
          idTransaccion: idTransaccion);
    }

    if (fotoFactura != null) {
      try {
        final path = _rutaFirma('entradas_factura', idTransaccion);
        await supabase.storage.from('inv-firmas').uploadBinary(path, fotoFactura);
        await supabase
            .from(tablas.transaccionesEntrada)
            .update({'foto_factura_url': path}).eq('id_transaccion', idTransaccion);
      } catch (_) {
        // La foto de la factura es complementaria; si falla no se bloquea el registro de la entrada.
      }
    }
  }

  Future<void> registrarSalida({
    required DateTime fecha,
    required String bote,
    required String aQuienEntrega,
    required String identificacionQuienRecibe,
    required bool confirmacionRecepcion,
    required String proposito,
    required String usuarioId,
    required String usuarioNombre,
    required List<ItemMovimiento> items,
    Uint8List? firma,
    String? peticionTexto,
    Uint8List? bytesFotoPeticion,
  }) async {
    final transaccion = await supabase
        .from(tablas.transaccionesSalida)
        .insert({
          'fecha_hora': fecha.toIso8601String(),
          'bote': bote,
          'a_quien_entrega': aQuienEntrega,
          'identificacion_quien_recibe': identificacionQuienRecibe,
          'confirmacion_recepcion': confirmacionRecepcion,
          'proposito': proposito,
          'usuario_id': usuarioId,
          'usuario_nombre': usuarioNombre,
          'peticion_texto': (peticionTexto == null || peticionTexto.trim().isEmpty) ? null : peticionTexto.trim(),
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

    if (bytesFotoPeticion != null) {
      try {
        final path = _rutaFirma('salidas_peticion', idTransaccion);
        await supabase.storage.from('inv-firmas').uploadBinary(path, bytesFotoPeticion);
        await supabase.from(tablas.transaccionesSalida).update({'peticion_foto_url': path}).eq('id_transaccion', idTransaccion);
      } catch (_) {
        // La foto de la petición es complementaria; si falla no se bloquea el registro de la salida.
      }
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
