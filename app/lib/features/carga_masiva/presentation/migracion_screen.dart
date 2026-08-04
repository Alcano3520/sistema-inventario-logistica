import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/modulos.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../productos/presentation/productos_providers.dart';
import 'carga_masiva_screen.dart' show cargaMasivaRepositoryProvider;
import 'csv_import_panel.dart';

class MigracionScreen extends ConsumerStatefulWidget {
  const MigracionScreen({super.key});

  @override
  ConsumerState<MigracionScreen> createState() => _MigracionScreenState();
}

class _MigracionScreenState extends ConsumerState<MigracionScreen> {
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
            '🔄 Migración de Datos Históricos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(6),
              border: const Border(left: BorderSide(color: AppColors.warning, width: 4)),
            ),
            child: const Text(
              '⚠️ IMPORTANTE: Esta función es solo para administradores. Úsala una sola vez para migrar '
              'datos del sistema anterior. Las transacciones se crearán con las fechas originales.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, children: [
            _tabSec('📥 Entradas', 0),
            _tabSec('📤 Salidas', 1),
          ]),
          const SizedBox(height: 20),
          if (_tab == 0)
            CsvImportPanel(
              infoTitulo: '📋 Formato de Entradas:',
              infoTexto: 'COD, PRODUCTO, FECHA, CANTIDAD  (fecha dd/mm/yyyy)',
              hint: '8M0057703,GASKET ADP PLATE,24/10/2025,2\n8M6000366,HEAD GASKET,24/10/2025,3',
              botonTexto: '📤 Migrar Entradas',
              etiquetaExito: 'Ítems de entrada migrados',
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
              infoTitulo: '📋 Formato de Salidas:',
              infoTexto:
                  'COD, PRODUCTO, FECHA, CANTIDAD, ${tablas.etiquetaVehiculo.toUpperCase()}  (fecha dd/mm/yyyy)',
              hint: '8M0142673,SOPORTE ALTERNADOR,10/01/2025,1,${tablas.ejemploVehiculo}',
              botonTexto: '📤 Migrar Salidas',
              etiquetaExito: 'Ítems de salida migrados',
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
