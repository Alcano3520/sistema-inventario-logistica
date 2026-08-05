import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../data/exportador_descuentos.dart';
import '../domain/descuento_nomina.dart';
import 'general_providers.dart';

final _descuentosPendientesProvider = FutureProvider.autoDispose<List<DescuentoNomina>>((ref) {
  return ref.watch(descuentosGeneralRepositoryProvider).obtenerPendientes();
});

final _descuentosExportadosProvider = FutureProvider.autoDispose<List<DescuentoNomina>>((ref) {
  return ref.watch(descuentosGeneralRepositoryProvider).obtenerExportados();
});

final _exportadorDescuentosProvider = Provider((ref) => ExportadorDescuentos());

class DescuentosGeneralScreen extends ConsumerStatefulWidget {
  const DescuentosGeneralScreen({super.key});

  @override
  ConsumerState<DescuentosGeneralScreen> createState() => _DescuentosGeneralScreenState();
}

class _DescuentosGeneralScreenState extends ConsumerState<DescuentosGeneralScreen> {
  int _tab = 0;
  final Set<String> _seleccionados = {};
  bool _exportando = false;
  final _formatoFecha = DateFormat('dd/MM/yyyy');

  num _totalSeleccionado(List<DescuentoNomina> pendientes) {
    return pendientes
        .where((d) => _seleccionados.contains(d.id))
        .fold<num>(0, (acc, d) => acc + d.valorDescuento);
  }

  Future<void> _exportarSeleccionados(List<DescuentoNomina> pendientes) async {
    final elegidos = pendientes.where((d) => _seleccionados.contains(d.id)).toList();
    if (elegidos.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exportar descuentos'),
        content: Text(
            '¿Exportar ${elegidos.length} descuento(s) por un total de \$${_totalSeleccionado(pendientes).toStringAsFixed(2)}?\n\n'
            'Una vez exportados, esos movimientos no podrán editarse ni anularse.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Exportar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _exportando = true);
    try {
      final lote = 'LOTE-${DateTime.now().millisecondsSinceEpoch}';
      final resultado =
          await ref.read(_exportadorDescuentosProvider).exportarExcel(elegidos, lote: lote);
      if (resultado.cancelado) return;

      await ref
          .read(descuentosGeneralRepositoryProvider)
          .marcarComoExportados(elegidos.map((e) => e.id).toList(), lote);

      ref.invalidate(_descuentosPendientesProvider);
      ref.invalidate(_descuentosExportadosProvider);
      setState(() => _seleccionados.clear());

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('✅ Exportado y guardado en: ${resultado.ruta}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💰 Descuentos de Nómina',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, children: [
            ChoiceChip(
                label: const Text('Pendientes'),
                selected: _tab == 0,
                onSelected: (_) => setState(() => _tab = 0)),
            ChoiceChip(
                label: const Text('Exportados'),
                selected: _tab == 1,
                onSelected: (_) => setState(() => _tab = 1)),
          ]),
          const SizedBox(height: 16),
          Expanded(child: _tab == 0 ? _listaPendientes() : _listaExportados()),
        ],
      ),
    );
  }

  Widget _listaPendientes() {
    final async = ref.watch(_descuentosPendientesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (pendientes) {
        if (pendientes.isEmpty) {
          return const Center(child: Text('No hay descuentos pendientes de exportar.'));
        }
        return Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: _seleccionados.length == pendientes.length,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _seleccionados.addAll(pendientes.map((d) => d.id));
                    } else {
                      _seleccionados.clear();
                    }
                  }),
                ),
                const Text('Seleccionar todos'),
                const Spacer(),
                Text('Total: \$${_totalSeleccionado(pendientes).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: pendientes.length,
                itemBuilder: (context, i) {
                  final d = pendientes[i];
                  return CheckboxListTile(
                    value: _seleccionados.contains(d.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _seleccionados.add(d.id);
                      } else {
                        _seleccionados.remove(d.id);
                      }
                    }),
                    title: Text('${d.empleadoNombre} — ${d.articuloDescripcion}'),
                    subtitle: Text(
                        'CI: ${d.empleadoCedula} · ${_formatoFecha.format(d.fechaEntrega)} · \$${d.valorDescuento}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: (_seleccionados.isEmpty || _exportando)
                  ? null
                  : () => _exportarSeleccionados(pendientes),
              child: _exportando
                  ? const SizedBox(
                      height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('📗 Exportar seleccionados (${_seleccionados.length})'),
            ),
          ],
        );
      },
    );
  }

  Widget _listaExportados() {
    final async = ref.watch(_descuentosExportadosProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (exportados) {
        if (exportados.isEmpty) {
          return const Center(child: Text('Aún no se ha exportado ningún descuento.'));
        }
        return ListView.builder(
          itemCount: exportados.length,
          itemBuilder: (context, i) {
            final d = exportados[i];
            return ListTile(
              title: Text('${d.empleadoNombre} — ${d.articuloDescripcion}'),
              subtitle: Text('Lote: ${d.loteNumero ?? '-'} · \$${d.valorDescuento}'),
              trailing: Text(_formatoFecha.format(d.fechaEntrega)),
            );
          },
        );
      },
    );
  }
}
