import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/supabase_config.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../data/sync_general_service.dart';
import 'general_providers.dart';

class DashboardGeneralScreen extends ConsumerWidget {
  const DashboardGeneralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articulosAsync = ref.watch(articulosGeneralProvider);
    final articulos = articulosAsync.valueOrNull ?? [];
    final stockBajo = ref.watch(articulosGeneralStockBajoProvider);
    final pendientesOffline = SyncGeneralService.instance.pendientes;

    final total = articulos.length;
    final conStock = articulos.where((a) => a.stockDisponible > 0).length;
    final sinStock = articulos.where((a) => a.stockDisponible <= 0).length;

    return articulosAsync.isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => ref.read(articulosGeneralProvider.notifier).refrescar(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Dashboard — Dotación Empleados', style: AppText.screenTitle),
                if (pendientesOffline > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined, color: AppColors.warning, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$pendientesOffline operación(es) guardadas sin conexión, pendientes de sincronizar.',
                            style: AppText.body,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await SyncGeneralService.instance.sincronizar();
                            await ref.read(articulosGeneralProvider.notifier).refrescar();
                          },
                          child: const Text('Sincronizar ahora'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 500 ? 4 : 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    mainAxisExtent: 118,
                  ),
                  children: [
                    KpiCard(value: '$total', label: 'Total Artículos'),
                    KpiCard(value: '$conStock', label: 'Con Stock'),
                    KpiCard(value: '$sinStock', label: 'Sin Stock'),
                    KpiCard(value: '${stockBajo.length}', label: 'Stock Bajo', alerta: true),
                  ],
                ),
                const SizedBox(height: 25),
                const _DescuentosPendientesCard(),
                const SizedBox(height: 25),
                if (stockBajo.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 18),
                            SizedBox(width: 8),
                            Text('Artículos con stock bajo', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...stockBajo.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(left: 26, top: 4),
                            child: Text(
                              '${a.descripcion} (${a.codigoInterno}) — Disponible: ${a.stockDisponible} / Mínimo: ${a.stockMinimo}',
                              style: AppText.bodySecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
  }
}

class _DescuentosPendientesCard extends StatefulWidget {
  const _DescuentosPendientesCard();

  @override
  State<_DescuentosPendientesCard> createState() => _DescuentosPendientesCardState();
}

class _DescuentosPendientesCardState extends State<_DescuentosPendientesCard> {
  int? _cantidad;
  num? _total;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final data =
          await supabase.from('inv_general_descuentos_nomina').select('valor_descuento').eq('exportado', false);
      final lista = data as List;
      final total = lista.fold<num>(0, (acc, e) => acc + (e['valor_descuento'] as num? ?? 0));
      if (mounted) {
        setState(() {
          _cantidad = lista.length;
          _total = total;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cantidad = 0;
          _total = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.payments_outlined, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Descuentos pendientes de exportar: ', style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: _cantidad == null ? 'cargando…' : '$_cantidad (\$${_total!.toStringAsFixed(2)})'),
              ]),
              style: AppText.body,
            ),
          ),
        ],
      ),
    );
  }
}
