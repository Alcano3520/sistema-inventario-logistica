import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/app_theme.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../movimientos/data/acta_correccion_pdf_service.dart';
import '../../movimientos/presentation/entrada_screen.dart' show movimientosRepositoryProvider;
import '../../productos/presentation/productos_providers.dart';
import '../domain/transaccion.dart';
import 'capacidad_edicion.dart';
import 'historial_providers.dart';

/// Igual que `editarEntradaDialog` pero para una Salida — mismo esquema de
/// capacidad (completa el mismo día de registro; solo fecha hasta el día
/// 3; nada después, salvo para quien tenga `puedeEditarFacturas`).
Future<void> editarSalidaDialog(BuildContext context, WidgetRef ref, TransaccionSalida t) async {
  final perfil = ref.read(perfilActualProvider).valueOrNull;
  if (perfil == null) return;

  final capacidad =
      capacidadEdicion(perfil: perfil, usuarioIdRegistro: t.usuarioId, creadoEn: t.createdAt);
  if (capacidad == CapacidadEdicion.ninguna) return;
  final soloFecha = capacidad == CapacidadEdicion.soloFecha;

  var fecha = t.fechaHora.toLocal();
  final boteController = TextEditingController(text: t.bote);
  final aQuienController = TextEditingController(text: t.aQuienEntrega);
  final identificacionController = TextEditingController(text: t.identificacionQuienRecibe);
  final propositoController = TextEditingController(text: t.proposito);
  var confirmacion = t.confirmacionRecepcion;
  final notaController = TextEditingController();
  final itemsControllers = {
    for (final item in t.items)
      if (item.id != null)
        item.id!: (
          producto: TextEditingController(text: item.producto),
          cantidad: TextEditingController(text: '${item.cantidad}'),
        ),
  };

  final guardar = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(soloFecha ? 'Corregir fecha de la salida' : 'Editar datos de la salida'),
        content: SizedBox(
          width: (MediaQuery.of(context).size.width - 64).clamp(0, 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (soloFecha) ...[
                  const Text(
                    'Ya pasó el día del registro — ahora solo puedes corregir la fecha. '
                    'Para cambiar otro dato, pídeselo a un administrador.',
                    style: AppText.bodySecondary,
                  ),
                  const SizedBox(height: 10),
                ],
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
                if (!soloFecha) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: boteController,
                    decoration: const InputDecoration(labelText: 'Bote/Vehículo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: aQuienController,
                    decoration: const InputDecoration(labelText: 'A quién se entrega'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: identificacionController,
                    decoration: const InputDecoration(labelText: 'Identificación de quien recibe'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: propositoController,
                    decoration: const InputDecoration(labelText: 'Propósito'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Confirmación de recepción'),
                    value: confirmacion,
                    onChanged: (v) => setDialogState(() => confirmacion = v ?? false),
                  ),
                  if (itemsControllers.isNotEmpty) ...[
                    const SizedBox(height: 12),
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
                            TextField(
                              controller: c.cantidad,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Cantidad'),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
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
        );
      })
      .toList();

  final cambios = <(String, String, String)>[];
  void comparar(String campo, String antes, String despues) {
    if (antes != despues) cambios.add((campo, antes, despues));
  }

  final fechaOriginalLocal = t.fechaHora.toLocal();
  comparar('Fecha',
      '${fechaOriginalLocal.day.toString().padLeft(2, '0')}/${fechaOriginalLocal.month.toString().padLeft(2, '0')}/${fechaOriginalLocal.year}',
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}');
  comparar('Bote/Vehículo', t.bote, boteController.text.trim());
  comparar('A quién se entrega', t.aQuienEntrega, aQuienController.text.trim());
  comparar('Identificación de quien recibe', t.identificacionQuienRecibe, identificacionController.text.trim());
  comparar('Propósito', t.proposito, propositoController.text.trim());
  comparar('Confirmación de recepción', t.confirmacionRecepcion ? 'Sí' : 'No', confirmacion ? 'Sí' : 'No');
  for (final nuevo in nuevosItems) {
    final original = t.items.firstWhere((i) => i.id == nuevo.id);
    comparar('Producto (${original.cod})', original.producto, nuevo.producto);
    comparar('Cantidad (${original.cod})', '${original.cantidad}', '${nuevo.cantidad}');
  }

  // No hay un campo "observaciones" dedicado en Salida (a diferencia de
  // Entrada) — se deja la nota de corrección en "proposito", el único
  // campo libre disponible. En modo soloFecha el controlador nunca se
  // tocó, así que ya trae el proposito original tal cual.
  final fechaStr = '${DateTime.now().day.toString().padLeft(2, '0')}/'
      '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';
  final nuevaProposito = [
    if (propositoController.text.trim().isNotEmpty) propositoController.text.trim(),
    '[Corregido $fechaStr por ${perfil.nombre}] ${notaController.text.trim()}',
  ].join('\n');

  try {
    await ref.read(movimientosRepositoryProvider).editarSalida(
          idTransaccion: t.idTransaccion,
          fecha: fecha,
          bote: boteController.text.trim(),
          aQuienEntrega: aQuienController.text.trim(),
          identificacionQuienRecibe: identificacionController.text.trim(),
          confirmacionRecepcion: confirmacion,
          proposito: nuevaProposito,
          items: nuevosItems,
        );
    ref.invalidate(historialSalidasProvider);
    await ref.read(productosProvider.notifier).refrescar();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Salida corregida correctamente.')));
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
