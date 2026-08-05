import '../../../core/supabase_config.dart';
import '../domain/articulo_general.dart';

class ArticulosGeneralRepository {
  Future<List<ArticuloGeneral>> obtenerArticulos({bool soloActivos = true}) async {
    var query = supabase.from('inv_general_articulos').select();
    if (soloActivos) query = query.eq('activo', true);
    final data = await query.order('descripcion');
    return (data as List).map((e) => ArticuloGeneral.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> agregarArticulo({
    required String codigoInterno,
    String? codigoBarras,
    required String descripcion,
    required String categoria,
    String? subcategoria,
    num stockMinimo = 1,
    num valorUnitario = 0,
    num valorDescuento = 0,
    bool esDescontable = false,
    bool requiereDevolucion = true,
    String? ubicacionBodega,
    String? proveedor,
  }) async {
    await supabase.from('inv_general_articulos').insert({
      'codigo_interno': codigoInterno.trim(),
      if (codigoBarras != null && codigoBarras.trim().isNotEmpty) 'codigo_barras': codigoBarras.trim(),
      'descripcion': descripcion.trim(),
      'categoria': categoria.trim(),
      'subcategoria': subcategoria?.trim(),
      'stock_minimo': stockMinimo,
      'valor_unitario': valorUnitario,
      'valor_descuento': valorDescuento,
      'es_descontable': esDescontable,
      'requiere_devolucion': requiereDevolucion,
      'ubicacion_bodega': ubicacionBodega?.trim() ?? '',
      'proveedor': proveedor?.trim() ?? '',
    });
  }

  Future<void> actualizarArticulo({
    required String id,
    required String descripcion,
    required String categoria,
    String? subcategoria,
    required num stockMinimo,
    required num valorUnitario,
    required num valorDescuento,
    required bool esDescontable,
    required bool requiereDevolucion,
    String? ubicacionBodega,
    String? proveedor,
  }) async {
    await supabase.from('inv_general_articulos').update({
      'descripcion': descripcion.trim(),
      'categoria': categoria.trim(),
      'subcategoria': subcategoria?.trim(),
      'stock_minimo': stockMinimo,
      'valor_unitario': valorUnitario,
      'valor_descuento': valorDescuento,
      'es_descontable': esDescontable,
      'requiere_devolucion': requiereDevolucion,
      'ubicacion_bodega': ubicacionBodega?.trim() ?? '',
      'proveedor': proveedor?.trim() ?? '',
    }).eq('id', id);
  }

  Future<void> desactivarArticulo(String id) async {
    await supabase.from('inv_general_articulos').update({'activo': false}).eq('id', id);
  }
}
