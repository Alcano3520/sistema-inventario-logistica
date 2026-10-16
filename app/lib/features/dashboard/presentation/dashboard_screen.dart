import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/modulos.dart';
import '../../../core/supabase_config.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../duplicados/presentation/duplicados_screen.dart';
import '../../productos/presentation/productos_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _ejecutarDiagnostico(BuildContext context, WidgetRef ref) async {
    final productos = ref.read(productosProvider).valueOrNull ?? [];
    final tablas = ref.read(tablasActivasProvider);
    late final int entradas;
    late final int salidas;
    late final int perfiles;
    try {
      entradas = await supabase.from(tablas.transaccionesEntrada).count();
      salidas = await supabase.from(tablas.transaccionesSalida).count();
      perfiles = await supabase.from('inv_perfiles').count();
    } catch (_) {
      entradas = -1;
      salidas = -1;
      perfiles = -1;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Diagnóstico del sistema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Productos: ${productos.length}'),
            Text('Transacciones de entrada: $entradas'),
            Text('Transacciones de salida: $salidas'),
            Text('Usuarios registrados: $perfiles'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productosAsync = ref.watch(productosProvider);
    final productos = productosAsync.valueOrNull ?? [];
    final stockBajo = ref.watch(productosStockBajoProvider);
    final perfil = ref.watch(perfilActualProvider).valueOrNull;

    final total = productos.length;
    final conStock = productos.where((p) => p.stock > 0).length;
    final sinStock = productos.where((p) => p.stock <= 0).length;

    return productosAsync.isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => ref.read(productosProvider.notifier).refrescar(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Dashboard', style: AppText.screenTitle),
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
                    KpiCard(value: '$total', label: 'Total Productos'),
                    KpiCard(value: '$conStock', label: 'Con Stock'),
                    KpiCard(value: '$sinStock', label: 'Sin Stock'),
                    KpiCard(value: '${stockBajo.length}', label: 'Stock Bajo', alerta: true),
                  ],
                ),
                const SizedBox(height: 25),
                Container(
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
                      const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Usa el menú lateral para navegar entre las funciones del sistema.',
                          style: AppText.body,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _ejecutarDiagnostico(context, ref),
                      icon: const Icon(Icons.troubleshoot_outlined, size: 18),
                      label: const Text('Diagnóstico del sistema'),
                    ),
                    if (perfil?.esAdmin ?? false)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DuplicadosScreen()),
                        ),
                        icon: const Icon(Icons.content_copy_outlined, size: 18),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
                        label: const Text('Gestionar duplicados'),
                      ),
                  ],
                ),
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
                            Text('Productos con stock bajo', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...stockBajo.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(left: 26, top: 4),
                            child: Text(
                              '${p.producto} (${p.cod}) — Stock: ${p.stock} / Mínimo: ${p.stockMinimo}',
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
