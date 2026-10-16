import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../domain/articulo_general.dart';
import 'articulo_detalle_general_screen.dart';
import 'general_providers.dart';

class InventarioGeneralScreen extends ConsumerWidget {
  const InventarioGeneralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articulosAsync = ref.watch(articulosGeneralProvider);
    final articulosFiltrados = ref.watch(articulosGeneralFiltradosProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventario — Dotación Empleados', style: AppText.screenTitle),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por código, nombre o categoría...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => ref.read(busquedaArticulosGeneralProvider.notifier).state = v,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: articulosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error al cargar artículos: $e')),
              data: (_) {
                if (articulosFiltrados.isEmpty) {
                  return const Center(child: Text('No se encontraron artículos.'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(articulosGeneralProvider.notifier).refrescar(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 640) {
                        return ListView.builder(
                          itemCount: articulosFiltrados.length,
                          itemBuilder: (context, i) => _TarjetaArticulo(articulo: articulosFiltrados[i]),
                        );
                      }
                      return SingleChildScrollView(
                        child: _TablaInventario(articulos: articulosFiltrados),
                      );
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

class _TarjetaArticulo extends StatelessWidget {
  final ArticuloGeneral articulo;

  const _TarjetaArticulo({required this.articulo});

  @override
  Widget build(BuildContext context) {
    final sinStock = articulo.stockDisponible <= 0;
    final Color colorEstado = sinStock
        ? AppColors.error
        : articulo.stockBajo
            ? AppColors.warning
            : AppColors.success;
    final Color fondoTarjeta = sinStock
        ? AppColors.errorBg
        : articulo.stockBajo
            ? AppColors.warningBg
            : AppColors.surface;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ArticuloDetalleGeneralScreen(articulo: articulo)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: fondoTarjeta,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: colorEstado, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(articulo.descripcion,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Cód: ${articulo.codigoInterno}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${articulo.stockDisponible}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorEstado)),
                  const Text('Disponible', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _dato('Consignación', '${articulo.stockConsignacion}'),
              _dato('Descontado', '${articulo.stockDescontado}'),
              _dato('Baja', '${articulo.stockBaja}'),
              _dato('Mínimo', '${articulo.stockMinimo}'),
              if (articulo.categoria.isNotEmpty) _dato('Categoría', articulo.categoria),
              if (articulo.esDescontable) _dato('Valor desc.', '\$${articulo.valorDescuento}'),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _dato(String label, String valor) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        TextSpan(
            text: valor,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TablaInventario extends StatelessWidget {
  final List<ArticuloGeneral> articulos;

  const _TablaInventario({required this.articulos});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
          columns: const [
            DataColumn(label: Text('Código')),
            DataColumn(label: Text('Descripción')),
            DataColumn(label: Text('Categoría')),
            DataColumn(label: Text('Disponible')),
            DataColumn(label: Text('Consig.')),
            DataColumn(label: Text('Descont.')),
            DataColumn(label: Text('Baja')),
            DataColumn(label: Text('Mínimo')),
          ],
          rows: articulos.map((a) {
            final sinStock = a.stockDisponible <= 0;
            final Color? rowColor = sinStock
                ? AppColors.errorBg
                : a.stockBajo
                    ? AppColors.warningBg
                    : null;
            return DataRow(
              color: rowColor != null ? WidgetStateProperty.all(rowColor) : null,
              onSelectChanged: (_) => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ArticuloDetalleGeneralScreen(articulo: a)),
              ),
              cells: [
                DataCell(Text(a.codigoInterno)),
                DataCell(Text(a.descripcion)),
                DataCell(Text(a.categoria)),
                DataCell(Text('${a.stockDisponible}')),
                DataCell(Text('${a.stockConsignacion}')),
                DataCell(Text('${a.stockDescontado}')),
                DataCell(Text('${a.stockBaja}')),
                DataCell(Text('${a.stockMinimo}')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
