import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/modulos.dart';
import '../../../core/supabase_config.dart';
import '../domain/producto.dart';

class ProductosRepository {
  final ModuloTablas tablas;

  const ProductosRepository(this.tablas);

  Future<List<Producto>> obtenerProductos() async {
    final data = await supabase.from(tablas.productos).select().order('producto');
    return (data as List).map((e) => Producto.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Busca por código de producto (cod) o por código de barras — son campos
  /// independientes, así que un escaneo puede coincidir con cualquiera de
  /// los dos. `null` si no hay ningún producto con ese código.
  Future<Producto?> buscarPorCodigo(String codigo) async {
    final valor = codigo.trim();
    final data = await supabase
        .from(tablas.productos)
        .select()
        .or('cod.eq.$valor,codigo_barras.eq.$valor')
        .maybeSingle();
    if (data == null) return null;
    return Producto.fromMap(data);
  }

  /// Sube la foto ya comprimida al bucket público `inv-productos-fotos` y
  /// devuelve su URL pública. La ruta se prefija con la tabla del módulo
  /// activo para que Barcos y Motos nunca choquen aunque compartan `cod`.
  Future<String> subirFoto(Uint8List bytesComprimidos, String cod) async {
    final path = '${tablas.productos}/${cod.trim()}.jpg';
    await supabase.storage.from('inv-productos-fotos').uploadBinary(
          path,
          bytesComprimidos,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return supabase.storage.from('inv-productos-fotos').getPublicUrl(path);
  }

  Future<void> agregarProducto({
    required String cod,
    required String producto,
    String categoria = '',
    String ubicacion = '',
    num stockMinimo = 5,
    String? fotoUrl,
    String? codigoBarras,
  }) async {
    final barras = codigoBarras?.trim();
    await supabase.from(tablas.productos).insert({
      'cod': cod.trim(),
      'producto': producto.trim(),
      'categoria': categoria.trim(),
      'ubicacion': ubicacion.trim(),
      'stock_minimo': stockMinimo,
      'foto_url': ?fotoUrl,
      'codigo_barras': (barras == null || barras.isEmpty) ? null : barras,
    });
  }

  /// [codActual] identifica la fila a actualizar; pasa [codNuevo] solo si el
  /// código realmente cambió (renombrar un código pegado mal, corregir un
  /// typo, etc. — el historial de entradas/salidas previas queda con el
  /// código viejo, ya que no hay forma de reescribir transacciones pasadas).
  Future<void> actualizarProducto({
    required String codActual,
    String? codNuevo,
    required String producto,
    required String categoria,
    required String ubicacion,
    required num stockMinimo,
    String? fotoUrl,
    String? codigoBarras,
  }) async {
    final nuevo = codNuevo?.trim();
    final barras = codigoBarras?.trim();
    await supabase.from(tablas.productos).update({
      'producto': producto.trim(),
      'categoria': categoria.trim(),
      'ubicacion': ubicacion.trim(),
      'stock_minimo': stockMinimo,
      'foto_url': ?fotoUrl,
      'codigo_barras': (barras == null || barras.isEmpty) ? null : barras,
      if (nuevo != null && nuevo.isNotEmpty && nuevo != codActual) 'cod': nuevo,
    }).eq('cod', codActual);
  }

  /// Registra la diferencia entre el stock actual y lo contado físicamente
  /// como una Entrada o Salida real — nunca escribe `stock` directo. Así el
  /// ajuste queda auditado (aparece en Historial) y sobrevive a un
  /// "Recalcular Stocks" (que reconstruye el stock sumando Entradas/Salidas,
  /// no leyendo el campo `stock`; ponerlo a mano se perdería en el próximo
  /// recálculo).
  /// [numFactura]/[precioUnitario] solo aplican cuando la cantidad contada
  /// es mayor a la actual (entra mercadería) — una salida/corrección hacia
  /// abajo no tiene factura de compra.
  Future<void> registrarConteoFisico({
    required String cod,
    required String producto,
    required num stockActual,
    required num cantidadContada,
    required String usuarioId,
    required String usuarioNombre,
    String? numFactura,
    num? precioUnitario,
  }) async {
    final delta = cantidadContada - stockActual;
    if (delta == 0) return;

    if (delta > 0) {
      final factura = numFactura?.trim();
      final transaccion = await supabase
          .from(tablas.transaccionesEntrada)
          .insert({
            'fecha_hora': DateTime.now().toIso8601String(),
            'proveedor': 'Conteo físico',
            'num_factura': (factura == null || factura.isEmpty) ? '' : factura,
            'observaciones': 'Ajuste por conteo físico de inventario',
            'usuario_id': usuarioId,
            'usuario_nombre': usuarioNombre,
          })
          .select()
          .single();
      await supabase.from(tablas.detalleEntradas).insert({
        'id_transaccion': transaccion['id_transaccion'],
        'cod': cod,
        'producto': producto,
        'cantidad': delta,
        'precio_unitario': precioUnitario,
      });
    } else {
      final transaccion = await supabase
          .from(tablas.transaccionesSalida)
          .insert({
            'fecha_hora': DateTime.now().toIso8601String(),
            'bote': 'Ajuste de inventario',
            'a_quien_entrega': 'Conteo físico',
            'proposito': 'Corrección por conteo físico de inventario',
            'usuario_id': usuarioId,
            'usuario_nombre': usuarioNombre,
          })
          .select()
          .single();
      await supabase.from(tablas.detalleSalidas).insert({
        'id_transaccion': transaccion['id_transaccion'],
        'cod': cod,
        'producto': producto,
        'cantidad': -delta,
      });
    }
  }
}
