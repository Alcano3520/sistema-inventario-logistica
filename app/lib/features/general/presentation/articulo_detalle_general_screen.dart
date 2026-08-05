import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../domain/articulo_cambio.dart';
import '../domain/articulo_general.dart';
import '../domain/movimiento_general.dart';
import 'general_providers.dart';

final _historialArticuloProvider =
    FutureProvider.autoDispose.family<List<MovimientoGeneral>, String>((ref, articuloId) {
  return ref.watch(movimientosGeneralRepositoryProvider).obtenerHistorial(articuloId: articuloId, limite: 100);
});

final _cambiosArticuloProvider =
    FutureProvider.autoDispose.family<List<ArticuloCambio>, String>((ref, articuloId) {
  return ref.watch(articulosGeneralRepositoryProvider).obtenerCambios(articuloId);
});

class ArticuloDetalleGeneralScreen extends ConsumerWidget {
  final ArticuloGeneral articulo;
  const ArticuloDetalleGeneralScreen({super.key, required this.articulo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(_historialArticuloProvider(articulo.id));
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(articulo.descripcion)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Código: ${articulo.codigoInterno}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (articulo.categoria.isNotEmpty) Text('Categoría: ${articulo.categoria}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _dato('Disponible', '${articulo.stockDisponible}'),
                    _dato('Consignación', '${articulo.stockConsignacion}'),
                    _dato('Descontado', '${articulo.stockDescontado}'),
                    _dato('Baja', '${articulo.stockBaja}'),
                    _dato('Total', '${articulo.stockTotal}'),
                    _dato('Mínimo', '${articulo.stockMinimo}'),
                  ],
                ),
                if (articulo.esDescontable) ...[
                  const SizedBox(height: 6),
                  Text('💰 Descuento por unidad: \$${articulo.valorDescuento}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('📜 Historial de movimientos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          historialAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (movimientos) {
              if (movimientos.isEmpty) {
                return const Text('Sin movimientos registrados todavía.',
                    style: TextStyle(color: AppColors.textSecondary));
              }
              return Column(
                children: movimientos
                    .map((m) => Opacity(
                          opacity: m.anulado ? 0.5 : 1,
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              title: Text('${m.tipoMovimiento} · Cant: ${m.cantidad}'
                                  '${m.anulado ? ' (ANULADO)' : ''}'),
                              subtitle: Text(
                                  '${formatoFecha.format(m.fechaMovimiento.toLocal())}'
                                  '${m.empleadoNombre != null ? ' · ${m.empleadoNombre}' : ''}'),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('🕓 Historial de cambios',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Consumer(builder: (context, ref, _) {
            final cambiosAsync = ref.watch(_cambiosArticuloProvider(articulo.id));
            return cambiosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (cambios) {
                if (cambios.isEmpty) {
                  return const Text('Sin cambios registrados todavía.',
                      style: TextStyle(color: AppColors.textSecondary));
                }
                return Column(
                  children: cambios
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '• ${c.descripcionLegible}  (${formatoFecha.format(c.fecha.toLocal())})',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ))
                      .toList(),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _dato(String label, String valor) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        TextSpan(
            text: valor,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
