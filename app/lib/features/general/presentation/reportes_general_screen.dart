import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../data/pdf_report_service.dart';
import 'general_providers.dart';

final _pdfReportServiceProvider = Provider((ref) => PdfReportService());

class ReportesGeneralScreen extends ConsumerStatefulWidget {
  const ReportesGeneralScreen({super.key});

  @override
  ConsumerState<ReportesGeneralScreen> createState() => _ReportesGeneralScreenState();
}

class _ReportesGeneralScreenState extends ConsumerState<ReportesGeneralScreen> {
  bool _generando = false;
  DateTimeRange? _rango;
  final _formatoFecha = DateFormat('dd/MM/yyyy');

  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final seleccionado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(ahora.year + 1),
      initialDateRange: _rango,
    );
    if (seleccionado != null) setState(() => _rango = seleccionado);
  }

  Future<void> _generarInventario() async {
    setState(() => _generando = true);
    try {
      final articulos = ref.read(articulosGeneralProvider).valueOrNull ?? [];
      final bytes = await ref.read(_pdfReportServiceProvider).generarReporteInventario(articulos);
      await ref.read(_pdfReportServiceProvider).imprimir(bytes, 'inventario_general.pdf');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _generarMovimientos({String? tipo, String? titulo}) async {
    setState(() => _generando = true);
    try {
      final movimientos = await ref.read(movimientosGeneralRepositoryProvider).obtenerHistorial(
            tipoMovimiento: tipo,
            desde: _rango?.start,
            hasta: _rango?.end.add(const Duration(hours: 23, minutes: 59)),
            limite: 1000,
          );
      final bytes = await ref
          .read(_pdfReportServiceProvider)
          .generarReporteMovimientos(movimientos, titulo: titulo ?? 'MOVIMIENTOS');
      await ref.read(_pdfReportServiceProvider).imprimir(bytes, 'movimientos_general.pdf');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📄 Reportes — Inventario General',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _rango == null
                        ? 'Período: todo el historial'
                        : 'Período: ${_formatoFecha.format(_rango!.start)} – ${_formatoFecha.format(_rango!.end)}',
                  ),
                ),
                TextButton(onPressed: _elegirRango, child: const Text('Elegir fechas')),
                if (_rango != null)
                  TextButton(
                      onPressed: () => setState(() => _rango = null), child: const Text('Quitar')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _tarjeta(
            titulo: '📦 Inventario actual',
            descripcion: 'PDF con el estado de stock de todos los artículos, con membrete INSEVIG.',
            onTap: _generarInventario,
          ),
          const SizedBox(height: 16),
          _tarjeta(
            titulo: '📜 Todos los movimientos',
            descripcion: 'Entregas, devoluciones, entradas y ajustes del período seleccionado.',
            onTap: () => _generarMovimientos(titulo: 'MOVIMIENTOS'),
          ),
          const SizedBox(height: 16),
          _tarjeta(
            titulo: '🧾 Entregas por empleado',
            descripcion: 'Solo las salidas (entregas) del período, agrupadas por fecha y empleado.',
            onTap: () => _generarMovimientos(tipo: 'SALIDA', titulo: 'ENTREGAS'),
          ),
          const SizedBox(height: 16),
          _tarjeta(
            titulo: '↩️ Devoluciones',
            descripcion: 'Solo las devoluciones del período seleccionado.',
            onTap: () => _generarMovimientos(tipo: 'DEVOLUCION', titulo: 'DEVOLUCIONES'),
          ),
          if (_generando) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _tarjeta({required String titulo, required String descripcion, required VoidCallback onTap}) {
    return InkWell(
      onTap: _generando ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text(descripcion, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
