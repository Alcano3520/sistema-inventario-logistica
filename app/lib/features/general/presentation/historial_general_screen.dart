import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../domain/movimiento_general.dart';
import 'general_providers.dart';

final _historialGeneralProvider =
    FutureProvider.autoDispose.family<List<MovimientoGeneral>, String?>((ref, tipo) {
  return ref.watch(movimientosGeneralRepositoryProvider).obtenerHistorial(tipoMovimiento: tipo);
});

class HistorialGeneralScreen extends ConsumerStatefulWidget {
  const HistorialGeneralScreen({super.key});

  @override
  ConsumerState<HistorialGeneralScreen> createState() => _HistorialGeneralScreenState();
}

class _HistorialGeneralScreenState extends ConsumerState<HistorialGeneralScreen> {
  String? _filtroTipo;

  static const _tipos = {
    null: 'Todos',
    'SALIDA': 'Entregas',
    'DEVOLUCION': 'Devoluciones',
    'ENTRADA': 'Entradas',
    'AJUSTE': 'Ajustes',
    'BAJA': 'Bajas',
  };

  @override
  Widget build(BuildContext context) {
    final historialAsync = ref.watch(_historialGeneralProvider(_filtroTipo));
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📜 Historial — Inventario General',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tipos.entries.map((e) {
              final activo = _filtroTipo == e.key;
              return ChoiceChip(
                label: Text(e.value),
                selected: activo,
                onSelected: (_) => setState(() => _filtroTipo = e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: historialAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error al cargar historial: $e')),
              data: (movimientos) {
                if (movimientos.isEmpty) {
                  return const Center(child: Text('No hay movimientos registrados.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_historialGeneralProvider(_filtroTipo)),
                  child: ListView.builder(
                    itemCount: movimientos.length,
                    itemBuilder: (context, i) {
                      final m = movimientos[i];
                      return _FilaMovimiento(movimiento: m, formatoFecha: formatoFecha);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  final MovimientoGeneral movimiento;
  final DateFormat formatoFecha;

  const _FilaMovimiento({required this.movimiento, required this.formatoFecha});

  Color get _color {
    if (movimiento.anulado) return AppColors.textSecondary;
    switch (movimiento.tipoMovimiento) {
      case 'SALIDA':
        return AppColors.error;
      case 'DEVOLUCION':
        return AppColors.success;
      case 'ENTRADA':
        return AppColors.info;
      case 'BAJA':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  String get _emoji {
    switch (movimiento.tipoMovimiento) {
      case 'SALIDA':
        return '📤';
      case 'DEVOLUCION':
        return '↩️';
      case 'ENTRADA':
        return '📥';
      case 'AJUSTE':
        return '⚖️';
      case 'BAJA':
        return '🗑️';
      default:
        return '•';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: movimiento.anulado ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: _color, width: 4)),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$_emoji ${movimiento.articuloDescripcion ?? movimiento.articuloId}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${movimiento.cantidad}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _color)),
                if (movimiento.anulado)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('ANULADO', style: TextStyle(fontSize: 10, color: AppColors.error)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(formatoFecha.format(movimiento.fechaMovimiento.toLocal()),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (movimiento.empleadoNombre != null)
              Text('${movimiento.empleadoNombre} · CI: ${movimiento.empleadoCedula ?? '-'}',
                  style: const TextStyle(fontSize: 12)),
            if (movimiento.aplicaDescuento)
              Text('💰 Descuento: \$${movimiento.valorDescuento}',
                  style: const TextStyle(fontSize: 12, color: AppColors.warning)),
          ],
        ),
      ),
    );
  }
}
