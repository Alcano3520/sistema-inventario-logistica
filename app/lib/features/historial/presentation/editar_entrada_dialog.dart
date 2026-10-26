import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/app_theme.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../movimientos/data/acta_correccion_pdf_service.dart';
import '../../movimientos/presentation/entrada_screen.dart' show movimientosRepositoryProvider;
import '../../productos/presentation/productos_providers.dart';
import '../domain/transaccion.dart';
import 'historial_providers.dart';

/// Corrige los datos de una Entrada/factura ya registrada — solo pensado
/// para quien tenga `puedeEditarFacturas`, sin límite de tiempo. Exige una
/// nota explicando la corrección (se agrega a las observaciones, sin borrar
/// lo que ya había) y, si algo cambió, genera un acta en PDF para firmar.
/// Compartido entre Historial (pestaña "Por Factura") y la ficha de un
/// producto puntual (kardex), que son las dos pantallas desde las que tiene
/// sentido abrir esta corrección.
Future<void> editarEntradaDialog(BuildContext context, WidgetRef ref, TransaccionEntrada t) async {
  final perfil = ref.read(perfilActualProvider).valueOrNull;
  if (perfil == null) return;

  var fecha = t.fechaHora;
  final proveedorController = TextEditingController(text: t.proveedor);
  final numFacturaController = TextEditingController(text: t.numFactura);
  final claveController = TextEditingController(text: t.claveAccesoSri ?? '');
  final notaController = TextEditingController();
  final itemsControllers = {
    for (final item in t.items)
      if (item.id != null)
        item.id!: (
          producto: TextEditingController(text: item.producto),
          cantidad: TextEditingController(text: '${item.cantidad}'),
          precio: TextEditingController(text: item.precioUnitario?.toString() ?? ''),
        ),
  };

  final guardar = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Editar datos de la factura'),
        content: SizedBox(
          width: (MediaQuery.of(context).size.width - 64).clamp(0, 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    final seleccionada = await showDatePicker(
                      context: context,
                      initialDate: fecha,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (seleccionada != null) setDialogState(() => fecha = seleccionada);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha'),
                    child: Text('${fecha.day.toString().padLeft(2, '0')}/'
                        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: proveedorController,
                  decoration: const InputDecoration(labelText: 'Proveedor'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: numFacturaController,
                  decoration: const InputDecoration(labelText: 'N° Factura/OC'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: claveController,
                  decoration: const InputDecoration(labelText: 'Clave de acceso SRI'),
                ),
                if (itemsControllers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Productos:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...t.items.where((i) => i.id != null).map((item) {
                    final c = itemsControllers[item.id]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.cod, style: AppText.bodySecondary),
                          TextField(
                            controller: c.producto,
                            decoration: const InputDecoration(labelText: 'Producto'),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: c.cantidad,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Cantidad'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: c.precio,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Precio unitario'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: notaController,
                  maxLines: 2,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Observación de esta corrección (obligatoria)',
                    hintText: 'Qué se corrigió y por qué',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    ),
  );
  if (guardar != true) return;

  if (notaController.text.trim().isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe escribir una observación explicando la corrección.')));
    }
    return;
  }

  final nuevosItems = t.items
      .where((i) => i.id != null)
      .map((i) {
        final c = itemsControllers[i.id]!;
        return DetalleItem(
          id: i.id,
          cod: i.cod,
          producto: c.producto.text.trim(),
          cantidad: num.tryParse(c.cantidad.text) ?? i.cantidad,
          precioUnitario: num.tryParse(c.precio.text),
        );
      })
      .toList();

  // Solo los campos/ítems que realmente cambiaron, para que el acta de
  // corrección quede clara (no liste "lo mismo" como si hubiera cambiado).
  final cambios = <(String, String, String)>[];
  void comparar(String campo, String antes, String despues) {
    if (antes != despues) cambios.add((campo, antes, despues));
  }

  comparar('Fecha',
      '${t.fechaHora.day.toString().padLeft(2, '0')}/${t.fechaHora.month.toString().padLeft(2, '0')}/${t.fechaHora.year}',
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}');
  comparar('Proveedor', t.proveedor, proveedorController.text.trim());
  comparar('N° Factura/OC', t.numFactura, numFacturaController.text.trim());
  comparar('Clave de acceso SRI', t.claveAccesoSri ?? '', claveController.text.trim());
  for (final nuevo in nuevosItems) {
    final original = t.items.firstWhere((i) => i.id == nuevo.id);
    comparar('Producto (${original.cod})', original.producto, nuevo.producto);
    comparar('Cantidad (${original.cod})', '${original.cantidad}', '${nuevo.cantidad}');
    comparar(
        'Precio unitario (${original.cod})', '${original.precioUnitario ?? ''}', '${nuevo.precioUnitario ?? ''}');
  }

  final fechaStr = '${DateTime.now().day.toString().padLeft(2, '0')}/'
      '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';
  final nuevaObservacion = [
    if (t.observaciones.isNotEmpty) t.observaciones,
    '[Corregido $fechaStr por ${perfil.nombre}] ${notaController.text.trim()}',
  ].join('\n');

  try {
    await ref.read(movimientosRepositoryProvider).editarEntrada(
          idTransaccion: t.idTransaccion,
          fecha: fecha,
          proveedor: proveedorController.text.trim(),
          numFactura: numFacturaController.text.trim(),
          observaciones: nuevaObservacion,
          claveAccesoSri: claveController.text,
          items: nuevosItems,
        );
    ref.invalidate(historialEntradasProvider);
    await ref.read(productosProvider.notifier).refrescar();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Factura corregida correctamente.')));
    }
    if (cambios.isNotEmpty) {
      final pdfBytes = await ActaCorreccionPdfService.generarPdfActa(
        idTransaccion: t.idTransaccion,
        usuarioOriginal: t.usuarioNombre,
        usuarioCorrector: perfil.nombre,
        fechaCorreccion: DateTime.now(),
        observacionCorreccion: notaController.text.trim(),
        cambios: cambios,
      );
      await ActaCorreccionPdfService.imprimirOCompartirPdf(pdfBytes, 'acta_correccion_${t.idTransaccion}');
    }
  } on PostgrestException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al corregir: $e')));
    }
  }
}
