import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/supabase_config.dart';
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
                const Text(
                  '📊 Dashboard — Inventario General',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                if (pendientesOffline > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(6),
                      border: const Border(left: BorderSide(color: AppColors.warning, width: 4)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              '📴 $pendientesOffline operación(es) guardadas sin conexión, pendientes de sincronizar.'),
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
                    _KpiCard(value: '$total', label: 'Total Artículos'),
                    _KpiCard(value: '$conStock', label: 'Con Stock'),
                    _KpiCard(value: '$sinStock', label: 'Sin Stock'),
                    _KpiCard(value: '${stockBajo.length}', label: '⚠️ Stock Bajo', warning: true),
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
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(6),
                      border: const Border(left: BorderSide(color: AppColors.warning, width: 4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚠️ Artículos con Stock Bajo:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...stockBajo.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(left: 20, top: 4),
                            child: Text(
                              '•  ${a.descripcion} (${a.codigoInterno}) — Disponible: ${a.stockDisponible} / Mínimo: ${a.stockMinimo}',
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
        color: const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(6),
        border: const Border(left: BorderSide(color: AppColors.info, width: 4)),
      ),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(text: '💰 Descuentos pendientes de exportar: ', style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(
              text: _cantidad == null
                  ? 'cargando...'
                  : '$_cantidad (\$${_total!.toStringAsFixed(2)})'),
        ]),
        style: const TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final bool warning;

  const _KpiCard({required this.value, required this.label, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
        border: warning ? const Border(left: BorderSide(color: AppColors.warning, width: 4)) : null,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}
