import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/productos_repository.dart';
import '../domain/producto.dart';

final productosRepositoryProvider = Provider<ProductosRepository>((ref) => ProductosRepository());

class ProductosNotifier extends AsyncNotifier<List<Producto>> {
  @override
  Future<List<Producto>> build() {
    return ref.read(productosRepositoryProvider).obtenerProductos();
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
          p.cod.toLowerCase().contains(termino) || p.producto.toLowerCase().contains(termino))
      .toList();
});

final productosStockBajoProvider = Provider<List<Producto>>((ref) {
  final productos = ref.watch(productosProvider).valueOrNull ?? [];
  return productos.where((p) => p.stockBajo).toList();
});
