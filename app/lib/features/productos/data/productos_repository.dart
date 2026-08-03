import '../../../core/supabase_config.dart';
import '../domain/producto.dart';

class ProductosRepository {
  Future<List<Producto>> obtenerProductos() async {
    final data = await supabase.from('inv_productos').select().order('producto');
    return (data as List).map((e) => Producto.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> agregarProducto({
    required String cod,
    required String producto,
    String categoria = '',
    String ubicacion = '',
    num stockMinimo = 5,
  }) async {
    await supabase.from('inv_productos').insert({
      'cod': cod.trim(),
      'producto': producto.trim(),
      'categoria': categoria.trim(),
      'ubicacion': ubicacion.trim(),
      'stock_minimo': stockMinimo,
    });
  }

  Future<void> actualizarProducto({
    required String cod,
    required String producto,
    required String categoria,
    required String ubicacion,
    required num stockMinimo,
  }) async {
    await supabase.from('inv_productos').update({
      'producto': producto.trim(),
      'categoria': categoria.trim(),
      'ubicacion': ubicacion.trim(),
      'stock_minimo': stockMinimo,
    }).eq('cod', cod);
  }
}
