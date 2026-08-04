import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../data/exportador_inventario.dart';
import '../domain/producto.dart';
import 'productos_providers.dart';

final exportadorInventarioProvider = Provider((ref) => ExportadorInventario());

class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  bool _exportando = false;

  Future<void> _exportar(
      Future<ResultadoExportacion> Function(List<Producto>) fn) async {
    if (_exportando) return;
    final productos = ref.read(productosFiltradosProvider);
    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos para exportar.')),
      );
      return;
    }

    setState(() => _exportando = true);
    try {
      final resultado = await fn(productos);
      if (mounted && !resultado.cancelado) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Guardado en: ${resultado.ruta}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosProvider);
    final productosFiltrados = ref.watch(productosFiltradosProvider);
    final exportador = ref.read(exportadorInventarioProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📋 Inventario Actual',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              hintText: '🔍 Buscar por código o producto...',
            ),
            onChanged: (v) => ref.read(busquedaProductosProvider.notifier).state = v,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _exportando ? null : () => _exportar(exportador.exportarExcel),
                child: const Text('📗 Exportar a Excel'),
              ),
              OutlinedButton(
                onPressed: _exportando ? null : () => _exportar(exportador.exportarCsv),
                child: const Text('📊 Exportar a CSV'),
              ),
              OutlinedButton(
                onPressed: _exportando ? null : () => _exportar(exportador.exportarPdf),
                child: const Text('📄 Exportar a PDF'),
              ),
              if (_exportando)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: productosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error al cargar productos: $e')),
              data: (_) {
                if (productosFiltrados.isEmpty) {
                  return const Center(child: Text('No se encontraron productos.'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(productosProvider.notifier).refrescar(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 640) {
                        return ListView.builder(
                          itemCount: productosFiltrados.length,
                          itemBuilder: (context, i) =>
                              _TarjetaProducto(producto: productosFiltrados[i]),
                        );
                      }
                      return SingleChildScrollView(
                        child: _TablaInventario(productos: productosFiltrados),
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

class _TarjetaProducto extends StatelessWidget {
  final Producto producto;

  const _TarjetaProducto({required this.producto});

  @override
  Widget build(BuildContext context) {
    final Color colorEstado = producto.sinStock
        ? AppColors.error
        : producto.stockBajo
            ? AppColors.warning
            : AppColors.success;
    final Color fondoTarjeta = producto.sinStock
        ? const Color(0xFFFDEAEA)
        : producto.stockBajo
            ? const Color(0xFFFFF4E5)
            : AppColors.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: fondoTarjeta,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: colorEstado, width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)],
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
                    Text(producto.producto,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Cód: ${producto.cod}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${producto.stock}',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: colorEstado)),
                  const Text('Stock',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _dato('Entradas', '${producto.entrada}'),
              _dato('Salidas', '${producto.salida}'),
              _dato('Mínimo', '${producto.stockMinimo}'),
              if (producto.categoria.isNotEmpty) _dato('Categoría', producto.categoria),
              if (producto.ubicacion.isNotEmpty) _dato('Ubicación', producto.ubicacion),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dato(String label, String valor) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: '$label: ',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        TextSpan(
            text: valor,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TablaInventario extends StatelessWidget {
  final List<Producto> productos;

  const _TablaInventario({required this.productos});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FA)),
          columns: const [
            DataColumn(label: Text('Código')),
            DataColumn(label: Text('Producto')),
            DataColumn(label: Text('Entradas')),
            DataColumn(label: Text('Salidas')),
            DataColumn(label: Text('Stock')),
            DataColumn(label: Text('Categoría')),
            DataColumn(label: Text('Ubicación')),
            DataColumn(label: Text('Stock Min.')),
          ],
          rows: productos.map((p) {
            final Color? rowColor = p.sinStock
                ? const Color(0xFFFDEAEA)
                : p.stockBajo
                    ? const Color(0xFFFFF4E5)
                    : null;
            return DataRow(
              color: rowColor != null ? WidgetStateProperty.all(rowColor) : null,
              cells: [
                DataCell(Text(p.cod)),
                DataCell(Text(p.producto)),
                DataCell(Text('${p.entrada}')),
                DataCell(Text('${p.salida}')),
                DataCell(Text('${p.stock}')),
                DataCell(Text(p.categoria)),
                DataCell(Text(p.ubicacion)),
                DataCell(Text('${p.stockMinimo}')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
