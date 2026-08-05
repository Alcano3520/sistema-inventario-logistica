import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../carga_masiva/presentation/csv_import_panel.dart';
import '../data/carga_masiva_general_repository.dart';
import 'general_providers.dart';

final cargaMasivaGeneralRepositoryProvider = Provider((ref) => CargaMasivaGeneralRepository());

class CargaMasivaGeneralScreen extends ConsumerStatefulWidget {
  const CargaMasivaGeneralScreen({super.key});

  @override
  ConsumerState<CargaMasivaGeneralScreen> createState() => _CargaMasivaGeneralScreenState();
}

class _CargaMasivaGeneralScreenState extends ConsumerState<CargaMasivaGeneralScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(cargaMasivaGeneralRepositoryProvider);
    final perfil = ref.watch(perfilActualProvider).valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📂 Carga Masiva',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, children: [
            _tabSec('📦 Artículos nuevos', 0),
            _tabSec('📥 Entradas de stock', 1),
          ]),
          const SizedBox(height: 20),
          if (_tab == 0)
            CsvImportPanel(
              infoTitulo: 'ℹ️ Formato CSV:',
              infoTexto:
                  'El archivo debe tener las columnas: CODIGO, DESCRIPCION, CATEGORIA, VALOR_UNITARIO, STOCK_MINIMO',
              hint:
                  'UNI-001,Camisa uniforme M,Uniformes,25.00,5\nUNI-002,Pantalón táctico,Uniformes,30.00,5',
              botonTexto: '📤 Cargar Artículos',
              etiquetaExito: 'Artículos procesados',
              onProcesar: (csv) async {
                final r = await repo.cargarArticulos(csv);
                await ref.read(articulosGeneralProvider.notifier).refrescar();
                return r;
              },
            )
          else
            CsvImportPanel(
              infoTitulo: 'ℹ️ Formato CSV:',
              infoTexto: 'El archivo debe tener las columnas: CODIGO, CANTIDAD, MOTIVO (opcional). '
                  'El código debe corresponder a un artículo ya registrado.',
              hint: 'UNI-001,20,Compra inicial\nUNI-002,15,Reposición proveedor',
              botonTexto: '📤 Cargar Entradas',
              etiquetaExito: 'Entradas procesadas',
              onProcesar: (csv) async {
                if (perfil == null) throw Exception('Sesión no válida.');
                final r = await repo.cargarEntradas(
                    csv: csv, usuarioId: perfil.id, usuarioNombre: perfil.nombre);
                await ref.read(articulosGeneralProvider.notifier).refrescar();
                return r;
              },
            ),
        ],
      ),
    );
  }

  Widget _tabSec(String texto, int index) {
    final activo = _tab == index;
    return InkWell(
      onTap: () => setState(() => _tab = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? AppColors.primary : Colors.white,
          border: Border.all(color: activo ? AppColors.primary : AppColors.border, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(texto, style: TextStyle(color: activo ? Colors.white : const Color(0xFF5A6C7D))),
      ),
    );
  }
}
