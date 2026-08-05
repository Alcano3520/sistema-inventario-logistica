import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _generarMovimientos() async {
    setState(() => _generando = true);
    try {
      final movimientos = await ref.read(movimientosGeneralRepositoryProvider).obtenerHistorial(limite: 500);
      final bytes = await ref
          .read(_pdfReportServiceProvider)
          .generarReporteMovimientos(movimientos, titulo: 'MOVIMIENTOS RECIENTES');
      await ref.read(_pdfReportServiceProvider).imprimir(bytes, 'movimientos_general.pdf');
    } finally {
      if (mounted) setState(() => _generando = false);
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
            '📄 Reportes — Inventario General',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          _tarjeta(
            titulo: '📦 Inventario actual',
            descripcion: 'PDF con el estado de stock de todos los artículos, con membrete INSEVIG.',
            onTap: _generarInventario,
          ),
          const SizedBox(height: 16),
          _tarjeta(
            titulo: '📜 Movimientos recientes',
            descripcion: 'PDF de las últimas 500 entregas, devoluciones, entradas y ajustes.',
            onTap: _generarMovimientos,
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
