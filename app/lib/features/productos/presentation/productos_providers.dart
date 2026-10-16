import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modulos.dart';
import '../data/barcode_pdf_service.dart';
import '../data/exportador_inventario.dart';
import '../data/ficha_pdf_service.dart';
import '../data/productos_repository.dart';
import '../domain/producto.dart';

final productosRepositoryProvider = Provider<ProductosRepository>(
  (ref) => ProductosRepository(ref.watch(tablasActivasProvider)),
);

final barcodePdfServiceProvider = Provider<BarcodePdfService>((ref) => BarcodePdfService());

final fichaPdfServiceProvider = Provider<FichaPdfService>((ref) => FichaPdfService());

final exportadorInventarioProvider = Provider<ExportadorInventario>((ref) => ExportadorInventario());

class ProductosNotifier extends AsyncNotifier<List<Producto>> {
  @override
  Future<List<Producto>> build() {
    return ref.watch(productosRepositoryProvider).obtenerProductos();
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(productosRepositoryProvider).obtenerProductos());
  }
}

final productosProvider = AsyncNotifierProvider<ProductosNotifier, List<Producto>>(
  ProductosNotifier.new,
);

final busquedaProductosProvider = StateProvider<String>((ref) => '');

final productosFiltradosProvider = Provider<List<Producto>>((ref) {
  final productos = ref.watch(productosProvider).valueOrNull ?? [];
  final termino = ref.watch(busquedaProductosProvider).trim().toLowerCase();

  if (termino.isEmpty) return productos;

  return productos
      .where((p) =>
          p.cod.toLowerCase().contains(termino) ||
          p.producto.toLowerCase().contains(termino) ||
          (p.codigoBarras?.toLowerCase().contains(termino) ?? false))
      .toList();
});

final productosStockBajoProvider = Provider<List<Producto>>((ref) {
  final productos = ref.watch(productosProvider).valueOrNull ?? [];
  return productos.where((p) => p.stockBajo).toList();
});
