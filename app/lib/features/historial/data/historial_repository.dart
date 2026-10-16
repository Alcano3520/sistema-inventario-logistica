import '../../../core/modulos.dart';
import '../../../core/supabase_config.dart';
import '../domain/transaccion.dart';

class HistorialRepository {
  final ModuloTablas tablas;

  const HistorialRepository(this.tablas);

  Future<List<TransaccionEntrada>> obtenerHistorialEntradas() async {
    final data = await supabase
        .from(tablas.transaccionesEntrada)
        .select('*, detalles:${tablas.detalleEntradas}(*)')
        .order('fecha_hora', ascending: false);
    return (data as List)
        .map((e) => TransaccionEntrada.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransaccionSalida>> obtenerHistorialSalidas() async {
    final data = await supabase
        .from(tablas.transaccionesSalida)
        .select('*, detalles:${tablas.detalleSalidas}(*)')
        .order('fecha_hora', ascending: false);
    return (data as List)
        .map((e) => TransaccionSalida.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Historial de movimientos de UN producto en particular — para mostrar
  /// directo al abrir su detalle desde Inventario o Productos, sin tener
  /// que ir a buscarlo en el historial general. Va en orden cronológico
  /// (de más antiguo a más reciente) con saldo corrido, como un kardex: así
  /// se ve claro cómo va entrando y saliendo, y qué queda después de cada
  /// movimiento.
  Future<List<MovimientoProducto>> obtenerHistorialProducto(String cod) async {
    final entradasData = await supabase
        .from(tablas.detalleEntradas)
        .select(
            'cantidad, transaccion:${tablas.transaccionesEntrada}(fecha_hora, proveedor, num_factura, firma_url, foto_factura_url)')
        .eq('cod', cod);
    final salidasData = await supabase
        .from(tablas.detalleSalidas)
        .select(
            'cantidad, transaccion:${tablas.transaccionesSalida}(fecha_hora, a_quien_entrega, proposito, firma_url, peticion_foto_url)')
        .eq('cod', cod);

    final crudos = <({
      DateTime fecha,
      String tipo,
      num cantidad,
      String? proveedor,
      String? numFactura,
      String? aQuien,
      String? proposito,
      String? firmaUrl,
      String? fotoSustentoUrl,
      String? fotoFacturaUrl,
    })>[];

    for (final e in entradasData as List) {
      final t = (e as Map<String, dynamic>)['transaccion'] as Map<String, dynamic>?;
      if (t == null || t['fecha_hora'] == null) continue;
      crudos.add((
        fecha: DateTime.parse(t['fecha_hora'] as String),
        tipo: 'Entrada',
        cantidad: e['cantidad'] as num? ?? 0,
        proveedor: t['proveedor'] as String?,
        numFactura: t['num_factura'] as String?,
        aQuien: null,
        proposito: null,
        firmaUrl: t['firma_url'] as String?,
        fotoSustentoUrl: null,
        fotoFacturaUrl: t['foto_factura_url'] as String?,
      ));
    }
    for (final s in salidasData as List) {
      final t = (s as Map<String, dynamic>)['transaccion'] as Map<String, dynamic>?;
      if (t == null || t['fecha_hora'] == null) continue;
      crudos.add((
        fecha: DateTime.parse(t['fecha_hora'] as String),
        tipo: 'Salida',
        cantidad: s['cantidad'] as num? ?? 0,
        proveedor: null,
        numFactura: null,
        aQuien: t['a_quien_entrega'] as String?,
        proposito: t['proposito'] as String?,
        firmaUrl: t['firma_url'] as String?,
        fotoSustentoUrl: t['peticion_foto_url'] as String?,
        fotoFacturaUrl: null,
      ));
    }

    crudos.sort((a, b) => a.fecha.compareTo(b.fecha));

    num saldo = 0;
    return crudos.map((m) {
      saldo += m.tipo == 'Entrada' ? m.cantidad : -m.cantidad;
      return MovimientoProducto(
        fecha: m.fecha,
        tipo: m.tipo,
        cantidad: m.cantidad,
        proveedor: m.proveedor,
        numFactura: m.numFactura,
        aQuien: m.aQuien,
        proposito: m.proposito,
        firmaUrl: m.firmaUrl,
        fotoSustentoUrl: m.fotoSustentoUrl,
        fotoFacturaUrl: m.fotoFacturaUrl,
        saldo: saldo,
      );
    }).toList();
  }

  /// Busca todas las transacciones de Entrada cuyo número de factura
  /// coincide (parcial, sin distinguir mayúsculas) — para que Financiero
  /// pueda escribir el número de una factura y ver todo lo que se compró
  /// ahí, aunque haya quedado repartido en varios registros.
  Future<List<TransaccionEntrada>> buscarEntradasPorFactura(String factura) async {
    final termino = factura.trim();
    if (termino.isEmpty) return [];
    final data = await supabase
        .from(tablas.transaccionesEntrada)
        .select('*, detalles:${tablas.detalleEntradas}(*)')
        .ilike('num_factura', '%$termino%')
        .order('fecha_hora');
    return (data as List)
        .map((e) => TransaccionEntrada.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<String?> firmaUrlFirmada(String? path) async {
    if (path == null) return null;
    try {
      return await supabase.storage.from('inv-firmas').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }
}
