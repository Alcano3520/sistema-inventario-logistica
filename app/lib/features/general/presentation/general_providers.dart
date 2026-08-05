import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/articulos_general_repository.dart';
import '../data/descuentos_general_repository.dart';
import '../data/empleados_externos_repository.dart';
import '../data/movimientos_general_repository.dart';
import '../domain/articulo_general.dart';

final articulosGeneralRepositoryProvider =
    Provider<ArticulosGeneralRepository>((ref) => ArticulosGeneralRepository());

final movimientosGeneralRepositoryProvider =
    Provider<MovimientosGeneralRepository>((ref) => MovimientosGeneralRepository());

final empleadosExternosRepositoryProvider =
    Provider<EmpleadosExternosRepository>((ref) => EmpleadosExternosRepository());

final descuentosGeneralRepositoryProvider =
    Provider<DescuentosGeneralRepository>((ref) => DescuentosGeneralRepository());

class ArticulosGeneralNotifier extends AsyncNotifier<List<ArticuloGeneral>> {
  @override
  Future<List<ArticuloGeneral>> build() {
    return ref.watch(articulosGeneralRepositoryProvider).obtenerArticulos();
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(articulosGeneralRepositoryProvider).obtenerArticulos());
  }
}

final articulosGeneralProvider =
    AsyncNotifierProvider<ArticulosGeneralNotifier, List<ArticuloGeneral>>(
  ArticulosGeneralNotifier.new,
);

final busquedaArticulosGeneralProvider = StateProvider<String>((ref) => '');

final articulosGeneralFiltradosProvider = Provider<List<ArticuloGeneral>>((ref) {
  final articulos = ref.watch(articulosGeneralProvider).valueOrNull ?? [];
  final termino = ref.watch(busquedaArticulosGeneralProvider).trim().toLowerCase();
  if (termino.isEmpty) return articulos;
  return articulos
      .where((a) =>
          a.codigoInterno.toLowerCase().contains(termino) ||
          a.descripcion.toLowerCase().contains(termino) ||
          a.categoria.toLowerCase().contains(termino))
      .toList();
});

final articulosGeneralStockBajoProvider = Provider<List<ArticuloGeneral>>((ref) {
  final articulos = ref.watch(articulosGeneralProvider).valueOrNull ?? [];
  return articulos.where((a) => a.stockBajo).toList();
});
