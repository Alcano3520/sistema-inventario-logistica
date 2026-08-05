import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/app_theme.dart';
import '../domain/movimiento_general.dart';
import 'general_providers.dart';

final _correccionesGeneralProvider = FutureProvider.autoDispose<List<MovimientoGeneral>>((ref) {
  return ref.watch(movimientosGeneralRepositoryProvider).obtenerHistorial(limite: 300);
});

class CorreccionesGeneralScreen extends ConsumerStatefulWidget {
  const CorreccionesGeneralScreen({super.key});

  @override
  ConsumerState<CorreccionesGeneralScreen> createState() => _CorreccionesGeneralScreenState();
}

class _CorreccionesGeneralScreenState extends ConsumerState<CorreccionesGeneralScreen> {
  final _busquedaController = TextEditingController();

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<bool> _verificarBloqueado(MovimientoGeneral movimiento, {required String accion}) async {
    if (!movimiento.aplicaDescuento) return false;
    final exportado = await ref.read(movimientosGeneralRepositoryProvider).tieneDescuentoExportado(movimiento.id);
    if (exportado && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'No se puede $accion: el descuento de este movimiento ya fue exportado a nómina.')));
    }
    return exportado;
  }

  Future<void> _editar(MovimientoGeneral movimiento) async {
    if (await _verificarBloqueado(movimiento, accion: 'editar')) return;
    if (!mounted) return;

    final cantidadController = TextEditingController(text: '${movimiento.cantidad}');
    final valorController = TextEditingController(text: '${movimiento.valorDescuento}');
    final observacionesController = TextEditingController(text: movimiento.observaciones);
    var aplicaDescuento = movimiento.aplicaDescuento;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Editar: ${movimiento.tipoMovimiento} · ${movimiento.articuloDescripcion ?? ''}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: cantidadController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
                const SizedBox(height: 10),
                if (movimiento.tipoMovimiento == 'SALIDA') ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('¿Aplica descuento?'),
                    value: aplicaDescuento,
                    onChanged: (v) => setDialogState(() => aplicaDescuento = v),
                  ),
                  if (aplicaDescuento)
                    TextField(
                      controller: valorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor de descuento (\$)'),
                    ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: observacionesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observaciones'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (guardar != true) return;

    try {
      await ref.read(movimientosGeneralRepositoryProvider).editarMovimiento(
            movimientoId: movimiento.id,
            cantidad: num.tryParse(cantidadController.text) ?? movimiento.cantidad,
            aplicaDescuento: aplicaDescuento,
            valorDescuento: num.tryParse(valorController.text) ?? movimiento.valorDescuento,
            observaciones: observacionesController.text,
          );
      ref.invalidate(_correccionesGeneralProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Movimiento actualizado.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al editar: $e')));
      }
    }
  }

  Future<void> _anular(MovimientoGeneral movimiento) async {
    if (await _verificarBloqueado(movimiento, accion: 'anular')) return;
    if (!mounted) return;

    final motivoController = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Anular movimiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${movimiento.tipoMovimiento} · ${movimiento.articuloDescripcion ?? ''} · '
                'Cantidad: ${movimiento.cantidad}'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(labelText: 'Motivo de anulación'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref
          .read(movimientosGeneralRepositoryProvider)
          .anular(movimiento.id, motivoController.text);
      ref.invalidate(_correccionesGeneralProvider);
      await ref.read(articulosGeneralProvider.notifier).refrescar();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Movimiento anulado correctamente.')));
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al anular: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_correccionesGeneralProvider);
    final busqueda = _busquedaController.text.trim().toLowerCase();
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🛠️ Correcciones — Inventario General',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _busquedaController,
            decoration: const InputDecoration(hintText: 'Buscar por empleado o artículo...'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (movimientos) {
                final filtrados = busqueda.isEmpty
                    ? movimientos
                    : movimientos
                        .where((m) =>
                            (m.empleadoNombre?.toLowerCase().contains(busqueda) ?? false) ||
                            (m.articuloDescripcion?.toLowerCase().contains(busqueda) ?? false))
                        .toList();
                if (filtrados.isEmpty) {
                  return const Center(child: Text('No hay movimientos.'));
                }
                return ListView.builder(
                  itemCount: filtrados.length,
                  itemBuilder: (context, i) {
                    final m = filtrados[i];
                    return Opacity(
                      opacity: m.anulado ? 0.5 : 1,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${m.tipoMovimiento} · ${m.articuloDescripcion ?? m.articuloId}'),
                          subtitle: Text(
                              '${formatoFecha.format(m.fechaMovimiento.toLocal())}'
                              '${m.empleadoNombre != null ? ' · ${m.empleadoNombre}' : ''} · Cant: ${m.cantidad}'
                              '${m.anulado ? ' · ANULADO' : ''}'),
                          trailing: m.anulado
                              ? null
                              : PopupMenuButton<String>(
                                  onSelected: (accion) {
                                    if (accion == 'editar') _editar(m);
                                    if (accion == 'anular') _anular(m);
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(value: 'editar', child: Text('✏️ Editar')),
                                    PopupMenuItem(value: 'anular', child: Text('↩️ Anular')),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
