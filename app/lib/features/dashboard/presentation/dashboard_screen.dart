import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/supabase_config.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../duplicados/presentation/duplicados_screen.dart';
import '../../productos/presentation/productos_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _ejecutarDiagnostico(BuildContext context, WidgetRef ref) async {
    final productos = ref.read(productosProvider).valueOrNull ?? [];
    late final int entradas;
    late final int salidas;
    late final int perfiles;
    try {
      entradas = await supabase.from('inv_transacciones_entrada').count();
      salidas = await supabase.from('inv_transacciones_salida').count();
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
        title: const Text('🔍 Diagnóstico del Sistema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Productos: ${productos.length}'),
            Text('✅ Transacciones de entrada: $entradas'),
            Text('✅ Transacciones de salida: $salidas'),
            Text('✅ Usuarios registrados: $perfiles'),
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
                const Text(
                  '📊 Dashboard',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
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
                    _KpiCard(value: '$total', label: 'Total Productos'),
                    _KpiCard(value: '$conStock', label: 'Con Stock'),
                    _KpiCard(value: '$sinStock', label: 'Sin Stock'),
                    _KpiCard(
                        value: '${stockBajo.length}',
                        label: '⚠️ Stock Bajo',
                        warning: true),
                  ],
                ),
                const SizedBox(height: 25),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(6),
                    border: const Border(left: BorderSide(color: AppColors.info, width: 4)),
                  ),
                  child: const Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: 'ℹ️ Información: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(
                          text:
                              'Use las pestañas superiores para navegar entre las diferentes funcionalidades del sistema.'),
                    ]),
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: () => _ejecutarDiagnostico(context, ref),
                      child: const Text('🔍 Diagnóstico del Sistema'),
                    ),
                    if (perfil?.esAdmin ?? false)
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DuplicadosScreen()),
                        ),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
                        child: const Text('🔄 Gestionar Duplicados'),
                      ),
                  ],
                ),
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
                        const Text('⚠️ Productos con Stock Bajo:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...stockBajo.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(left: 20, top: 4),
                            child: Text(
                              '•  ${p.producto} (${p.cod}) — Stock: ${p.stock} / Mínimo: ${p.stockMinimo}',
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
