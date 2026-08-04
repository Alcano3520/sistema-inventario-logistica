import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modulos.dart';
import '../data/historial_repository.dart';
import '../domain/transaccion.dart';

final historialRepositoryProvider = Provider<HistorialRepository>(
  (ref) => HistorialRepository(ref.watch(tablasActivasProvider)),
);

final historialEntradasProvider = FutureProvider.autoDispose<List<TransaccionEntrada>>((ref) {
  return ref.watch(historialRepositoryProvider).obtenerHistorialEntradas();
});

final historialSalidasProvider = FutureProvider.autoDispose<List<TransaccionSalida>>((ref) {
  return ref.watch(historialRepositoryProvider).obtenerHistorialSalidas();
});

final busquedaHistorialProvider = StateProvider.autoDispose<String>((ref) => '');
