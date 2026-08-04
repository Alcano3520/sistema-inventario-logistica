import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/modulos.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../productos/presentation/productos_providers.dart';
import '../data/carga_masiva_repository.dart';
import 'csv_import_panel.dart';

final cargaMasivaRepositoryProvider = Provider<CargaMasivaRepository>(
  (ref) => CargaMasivaRepository(ref.watch(tablasActivasProvider)),
);

class CargaMasivaScreen extends ConsumerStatefulWidget {
  const CargaMasivaScreen({super.key});

  @override
  ConsumerState<CargaMasivaScreen> createState() => _CargaMasivaScreenState();
}

class _CargaMasivaScreenState extends ConsumerState<CargaMasivaScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilActualProvider).valueOrNull;
    final repo = ref.read(cargaMasivaRepositoryProvider);
    final tablas = ref.watch(tablasActivasProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📂 Carga Masiva de Datos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, children: [
            _tabSec('📦 Productos', 0),
            _tabSec('📥 Entradas Históricas', 1),
            _tabSec('📤 Salidas Históricas', 2),
          ]),
          const SizedBox(height: 20),
          if (_tab == 0)
            CsvImportPanel(
              infoTitulo: 'ℹ️ Formato CSV:',
              infoTexto: 'El archivo debe tener las columnas: COD, PRODUCTO, CATEGORIA, UBICACION, STOCK_MINIMO',
              hint: 'REP001,Filtro de Aceite,Filtros,Estante A1,5\nREP002,Bujía NGK,Eléctrico,Estante B2,10',
              botonTexto: '📤 Cargar Productos',
              etiquetaExito: 'Productos procesados',
              onProcesar: (csv) async {
                final r = await repo.cargarProductos(csv);
                await ref.read(productosProvider.notifier).refrescar();
                return r;
              },
            )
          else if (_tab == 1)
            CsvImportPanel(
              infoTitulo: '📋 Formato:',
              infoTexto: 'COD, PRODUCTO, FECHA, CANTIDAD  (fecha dd/mm/yyyy)',
              hint: '8M0057703,GASKET ADP PLATE,24/10/2025,2\n8M6000366,HEAD GASKET,24/10/2025,3',
              botonTexto: '📤 Cargar Entradas',
              etiquetaExito: 'Ítems de entrada procesados',
              onProcesar: (csv) async {
                if (perfil == null) throw Exception('Sesión no válida.');
                final r = await repo.migrarEntradas(
                    csv: csv, usuarioId: perfil.id, usuarioNombre: perfil.nombre);
                await ref.read(productosProvider.notifier).refrescar();
                return r;
              },
            )
          else
            CsvImportPanel(
              infoTitulo: '📋 Formato:',
              infoTexto:
                  'COD, PRODUCTO, FECHA, CANTIDAD, ${tablas.etiquetaVehiculo.toUpperCase()}  (fecha dd/mm/yyyy)',
              hint: '8M0142673,SOPORTE ALTERNADOR,10/01/2025,1,${tablas.ejemploVehiculo}',
              botonTexto: '📤 Cargar Salidas',
              etiquetaExito: 'Ítems de salida procesados',
              onProcesar: (csv) async {
                if (perfil == null) throw Exception('Sesión no válida.');
                final r = await repo.migrarSalidas(
                    csv: csv, usuarioId: perfil.id, usuarioNombre: perfil.nombre);
                await ref.read(productosProvider.notifier).refrescar();
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
