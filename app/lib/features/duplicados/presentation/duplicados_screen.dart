import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/modulos.dart';
import '../../../shared/widgets/nota_banner.dart';
import '../../productos/presentation/productos_providers.dart';
import '../data/duplicados_repository.dart';

final duplicadosRepositoryProvider = Provider<DuplicadosRepository>(
  (ref) => DuplicadosRepository(ref.watch(tablasActivasProvider)),
);

class DuplicadosScreen extends ConsumerStatefulWidget {
  const DuplicadosScreen({super.key});

  @override
  ConsumerState<DuplicadosScreen> createState() => _DuplicadosScreenState();
}

class _DuplicadosScreenState extends ConsumerState<DuplicadosScreen> {
  bool _cargando = false;
  Map<String, dynamic>? _deteccion;
  String? _resultadoEliminacion;
  String? _resultadoRecalculo;
  String? _error;

  int get _totalDuplicados {
    if (_deteccion == null) return 0;
    final ent = (_deteccion!['entradas_duplicadas'] as List? ?? []);
    final sal = (_deteccion!['salidas_duplicadas'] as List? ?? []);
    return ent.length + sal.length;
  }

  Future<void> _detectar() async {
    setState(() {
      _cargando = true;
      _error = null;
      _deteccion = null;
    });
    try {
      final r = await ref.read(duplicadosRepositoryProvider).detectar();
      setState(() => _deteccion = r);
    } catch (e) {
      setState(() => _error = 'Error al detectar duplicados: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmarEliminar() async {
    final c1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Atención'),
        content: const Text(
            'Esta acción eliminará permanentemente las transacciones duplicadas y recalculará todos los stocks.\n\nNO SE PUEDE DESHACER.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continuar')),
        ],
      ),
    );
    if (c1 != true || !mounted) return;

    final c2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmación final'),
        content: const Text('¿Está completamente seguro de eliminar los duplicados detectados?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, eliminar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (c2 != true) return;

    setState(() {
      _cargando = true;
      _error = null;
      _resultadoEliminacion = null;
    });
    try {
      final r = await ref.read(duplicadosRepositoryProvider).eliminar();
      await ref.read(productosProvider.notifier).refrescar();
      setState(() {
        _resultadoEliminacion =
            'Duplicados eliminados: ${r['entradas_eliminadas']} entradas, ${r['salidas_eliminadas']} salidas. Stocks recalculados.';
        _deteccion = null;
      });
    } catch (e) {
      setState(() => _error = 'Error al eliminar duplicados: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _recalcular() async {
    setState(() {
      _cargando = true;
      _error = null;
      _resultadoRecalculo = null;
    });
    try {
      final r = await ref.read(duplicadosRepositoryProvider).recalcular();
      await ref.read(productosProvider.notifier).refrescar();
      setState(() =>
          _resultadoRecalculo = 'Stocks recalculados. Productos actualizados: ${r['productos_actualizados']}.');
    } catch (e) {
      setState(() => _error = 'Error al recalcular stocks: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Duplicados')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NotaBanner.texto(
              'Detecta y elimina transacciones duplicadas (mismo proveedor/destinatario, '
              'fecha y N° de factura o bote). Mantiene solo la primera de cada grupo y recalcula todos los stocks.',
              tipo: TipoNota.advertencia,
            ),
            const SizedBox(height: 20),
            _seccion(
              titulo: 'Paso 1: Detectar Duplicados',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Analiza las transacciones para encontrar posibles duplicados.'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _cargando ? null : _detectar,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Detectar Duplicados'),
                  ),
                  if (_deteccion != null) ...[
                    const SizedBox(height: 12),
                    Text(_totalDuplicados == 0
                        ? 'No se encontraron duplicados.'
                        : 'Se encontraron $_totalDuplicados grupo(s) con transacciones duplicadas.'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _seccion(
              titulo: 'Paso 2: Eliminar Duplicados',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta acción eliminará permanentemente las transacciones duplicadas y '
                    'recalculará todos los stocks. No se puede deshacer.',
                    style: TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: (_cargando || _deteccion == null || _totalDuplicados == 0)
                        ? null
                        : _confirmarEliminar,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    label: const Text('Eliminar Duplicados y Recalcular Stocks'),
                  ),
                  if (_resultadoEliminacion != null) ...[
                    const SizedBox(height: 12),
                    Text(_resultadoEliminacion!, style: const TextStyle(color: AppColors.success)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _seccion(
              titulo: 'Opción Alternativa: Solo Recalcular Stocks',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Si no desea eliminar duplicados pero necesita recalcular los stocks desde las transacciones existentes:'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _cargando ? null : _recalcular,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('Recalcular Todos los Stocks'),
                  ),
                  if (_resultadoRecalculo != null) ...[
                    const SizedBox(height: 12),
                    Text(_resultadoRecalculo!, style: const TextStyle(color: AppColors.success)),
                  ],
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              NotaBanner.texto(_error!, tipo: TipoNota.error),
            ],
            if (_cargando) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _seccion({required String titulo, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: AppText.sectionTitle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
