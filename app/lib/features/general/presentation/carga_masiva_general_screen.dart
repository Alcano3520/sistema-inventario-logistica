import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../carga_masiva/presentation/csv_import_panel.dart';
import '../data/carga_masiva_general_repository.dart';
import 'general_providers.dart';

final cargaMasivaGeneralRepositoryProvider = Provider((ref) => CargaMasivaGeneralRepository());

class CargaMasivaGeneralScreen extends ConsumerWidget {
  const CargaMasivaGeneralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(cargaMasivaGeneralRepositoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📂 Carga Masiva de Artículos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          CsvImportPanel(
            infoTitulo: 'ℹ️ Formato CSV:',
            infoTexto:
                'El archivo debe tener las columnas: CODIGO, DESCRIPCION, CATEGORIA, VALOR_UNITARIO, STOCK_MINIMO',
            hint: 'UNI-001,Camisa uniforme M,Uniformes,25.00,5\nUNI-002,Pantalón táctico,Uniformes,30.00,5',
            botonTexto: '📤 Cargar Artículos',
            etiquetaExito: 'Artículos procesados',
            onProcesar: (csv) async {
              final r = await repo.cargarArticulos(csv);
              await ref.read(articulosGeneralProvider.notifier).refrescar();
              return r;
            },
          ),
        ],
      ),
    );
  }
}
