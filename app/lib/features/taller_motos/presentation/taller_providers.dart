import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modulos.dart';
import '../data/taller_repository.dart';
import '../domain/orden_trabajo.dart';
import '../domain/repuesto.dart';
import '../domain/repuesto_retirado.dart';

final tallerRepositoryProvider =
    Provider<TallerRepository>((ref) => TallerRepository(ref.watch(tablasActivasProvider)));

class OrdenesTrabajoNotifier extends AsyncNotifier<List<OrdenTrabajo>> {
  @override
  Future<List<OrdenTrabajo>> build() {
    return ref.watch(tallerRepositoryProvider).obtenerOrdenesActivas();
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(tallerRepositoryProvider).obtenerOrdenesActivas());
  }
}

final ordenesTrabajoProvider =
    AsyncNotifierProvider<OrdenesTrabajoNotifier, List<OrdenTrabajo>>(OrdenesTrabajoNotifier.new);

class RepuestosTallerNotifier extends AsyncNotifier<List<Repuesto>> {
  @override
  Future<List<Repuesto>> build() {
    return ref.watch(tallerRepositoryProvider).obtenerRepuestos();
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(tallerRepositoryProvider).obtenerRepuestos());
  }
}

final repuestosTallerProvider =
    AsyncNotifierProvider<RepuestosTallerNotifier, List<Repuesto>>(RepuestosTallerNotifier.new);

class RepuestosRetiradosNotifier extends AsyncNotifier<List<RepuestoRetirado>> {
  @override
  Future<List<RepuestoRetirado>> build() {
    return ref.watch(tallerRepositoryProvider).obtenerRetirados();
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(tallerRepositoryProvider).obtenerRetirados());
  }
}

final repuestosRetiradosProvider =
    AsyncNotifierProvider<RepuestosRetiradosNotifier, List<RepuestoRetirado>>(RepuestosRetiradosNotifier.new);
