import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_theme.dart';
import '../../../core/modulos.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../productos/data/compresor_imagen.dart';
import '../../productos/presentation/productos_providers.dart';
import '../domain/orden_trabajo.dart';
import 'despacho_repuesto_screen.dart';
import 'ingreso_repuestos_screen.dart';
import 'repuestos_retirados_screen.dart';
import 'taller_providers.dart';

class OrdenesTrabajoScreen extends ConsumerWidget {
  const OrdenesTrabajoScreen({super.key});

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'COMPLETADA':
        return AppColors.success;
      case 'CANCELADA':
        return AppColors.error;
      case 'EN_PROCESO':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordenesAsync = ref.watch(ordenesTrabajoProvider);
    final perfil = ref.watch(perfilActualProvider).valueOrNull;
    final tablas = ref.watch(tablasActivasProvider);
    final esMecanico = perfil?.esMecanico ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(esMecanico ? 'Mis Pedidos' : 'Taller de ${tablas.etiquetaVehiculo}s'),
        actions: esMecanico
            ? null
            : [
                IconButton(
                  tooltip: 'Ingreso de stock',
                  icon: const Icon(Icons.move_to_inbox),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const IngresoRepuestoScreen())),
                ),
                IconButton(
                  tooltip: 'Piezas retiradas (chatarra)',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const RepuestosRetiradosScreen())),
                ),
              ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirDialogoNuevaOt(context, ref),
        icon: const Icon(Icons.add),
        label: Text(esMecanico ? 'Nuevo Pedido' : 'Nueva OT'),
      ),
      body: ordenesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error al cargar órdenes: $e')),
        data: (todasLasOrdenes) {
          final ordenes = esMecanico
              ? todasLasOrdenes.where((o) => o.mecanicoId == perfil!.id).toList()
              : todasLasOrdenes;
          return ordenes.isEmpty
              ? Center(
                  child: Text(esMecanico
                      ? 'Todavía no has hecho ningún pedido.'
                      : 'No hay órdenes de trabajo todavía.'),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(ordenesTrabajoProvider.notifier).refrescar(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: ordenes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _TarjetaOt(
                      orden: ordenes[i],
                      color: _colorEstado(ordenes[i].estado),
                      etiquetaMedidor: tablas.etiquetaMedidor,
                      onTap: esMecanico
                          ? (ordenes[i].abierta ? () => _abrirDialogoEditarOt(context, ref, ordenes[i]) : () {})
                          : () => _abrirOt(context, ref, ordenes[i]),
                      onEditar: ordenes[i].abierta ? () => _abrirDialogoEditarOt(context, ref, ordenes[i]) : null,
                      onCerrar: (!esMecanico && ordenes[i].abierta)
                          ? () async {
                              await ref.read(tallerRepositoryProvider).cerrarOrdenTrabajo(ordenes[i].id);
                              ref.read(ordenesTrabajoProvider.notifier).refrescar();
                            }
                          : null,
                    ),
                  ),
                );
        },
      ),
    );
  }

  Future<void> _abrirOt(BuildContext context, WidgetRef ref, OrdenTrabajo orden) async {
    if (!orden.abierta) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DespachoRepuestoScreen(
          ordenTrabajoId: orden.id,
          vehiculoCod: orden.vehiculoCod,
          descripcionFallo: orden.descripcionFallo,
          fotoFallaUrl: orden.fotoFallaUrl,
          fotoRepuestoNuevoUrl: orden.fotoRepuestoNuevoUrl,
        ),
      ),
    );
    ref.read(ordenesTrabajoProvider.notifier).refrescar();
  }

  Future<Uint8List?> _elegirYComprimirFoto(BuildContext context) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (origen == null || !context.mounted) return null;

    final foto = await ImagePicker().pickImage(source: origen, imageQuality: 90);
    if (foto == null) return null;

    final bytesOriginales = await foto.readAsBytes();
    return compute(CompresorImagen.comprimir, bytesOriginales);
  }

  Widget _previewFotoVacia() => Container(
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
        child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
      );

  Widget _filaFotoOt({
    required Widget preview,
    required String etiqueta,
    required String textoBoton,
    required VoidCallback onElegir,
    VoidCallback? onQuitar,
  }) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(width: 48, height: 48, child: preview),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(etiqueta, style: AppText.bodySecondary)),
        TextButton(onPressed: onElegir, child: Text(textoBoton)),
        if (onQuitar != null) IconButton(onPressed: onQuitar, icon: const Icon(Icons.close, size: 18)),
      ],
    );
  }

  Future<void> _abrirDialogoNuevaOt(BuildContext context, WidgetRef ref) async {
    final tablas = ref.read(tablasActivasProvider);
    final vehiculos = ref.read(productosProvider).valueOrNull ?? [];
    final perfil = ref.read(perfilActualProvider).valueOrNull;
    if (perfil == null) return;

    String? vehiculoCod = vehiculos.isNotEmpty ? vehiculos.first.cod : null;
    final medidorController = TextEditingController();
    final fallaController = TextEditingController();
    Uint8List? fotoFalla;
    Uint8List? fotoRepuestoNuevo;

    Widget miniaturaFoto(Uint8List? bytes, String etiqueta, VoidCallback onElegir, VoidCallback onQuitar) {
      return _filaFotoOt(
        preview: bytes != null ? Image.memory(bytes, fit: BoxFit.cover) : _previewFotoVacia(),
        etiqueta: etiqueta,
        textoBoton: bytes == null ? 'Agregar' : 'Cambiar',
        onElegir: onElegir,
        onQuitar: bytes != null ? onQuitar : null,
      );
    }

    final creado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nueva orden de trabajo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: vehiculoCod,
                  decoration: InputDecoration(labelText: tablas.etiquetaVehiculo),
                  items: vehiculos
                      .map((v) => DropdownMenuItem(value: v.cod, child: Text('${v.cod} · ${v.producto}')))
                      .toList(),
                  onChanged: (v) => setState(() => vehiculoCod = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: medidorController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tablas.etiquetaMedidor),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fallaController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción de la falla'),
                ),
                const SizedBox(height: 16),
                const Text('Evidencia fotográfica (opcional):', style: AppText.label),
                const SizedBox(height: 8),
                miniaturaFoto(
                  fotoFalla,
                  'Foto del repuesto/pieza dañada',
                  () async {
                    final bytes = await _elegirYComprimirFoto(context);
                    if (bytes != null) setState(() => fotoFalla = bytes);
                  },
                  () => setState(() => fotoFalla = null),
                ),
                const SizedBox(height: 8),
                miniaturaFoto(
                  fotoRepuestoNuevo,
                  'Foto del repuesto nuevo (si ya lo tiene)',
                  () async {
                    final bytes = await _elegirYComprimirFoto(context);
                    if (bytes != null) setState(() => fotoRepuestoNuevo = bytes);
                  },
                  () => setState(() => fotoRepuestoNuevo = null),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: vehiculoCod == null
                  ? null
                  : () async {
                      final medidor = int.tryParse(medidorController.text.trim()) ?? 0;
                      if (fallaController.text.trim().isEmpty) return;
                      await ref.read(tallerRepositoryProvider).crearOrdenTrabajo(
                            vehiculoCod: vehiculoCod!,
                            mecanicoId: perfil.id,
                            kilometrajeActual: medidor,
                            descripcionFallo: fallaController.text.trim(),
                            bytesFotoFalla: fotoFalla,
                            bytesFotoRepuestoNuevo: fotoRepuestoNuevo,
                          );
                      if (context.mounted) Navigator.pop(context, true);
                    },
              child: const Text('CREAR OT'),
            ),
          ],
        ),
      ),
    );

    if (creado == true) {
      ref.read(ordenesTrabajoProvider.notifier).refrescar();
    }
  }

  /// Corrección de una OT ya creada: el mecánico puede equivocarse (vehículo,
  /// kilometraje/horas, descripción o fotos) y tanto logística como el
  /// bodeguero deben poder arreglarlo.
  Future<void> _abrirDialogoEditarOt(BuildContext context, WidgetRef ref, OrdenTrabajo orden) async {
    final tablas = ref.read(tablasActivasProvider);
    final vehiculos = ref.read(productosProvider).valueOrNull ?? [];
    final repo = ref.read(tallerRepositoryProvider);

    String? vehiculoCod = orden.vehiculoCod;
    final medidorController = TextEditingController(text: orden.kilometrajeActual.toString());
    final fallaController = TextEditingController(text: orden.descripcionFallo);
    Uint8List? fotoFallaNueva;
    Uint8List? fotoRepuestoNuevoNueva;

    final urlFotoFallaActual = await repo.fotoUrlFirmada(orden.fotoFallaUrl);
    final urlFotoRepuestoActual = await repo.fotoUrlFirmada(orden.fotoRepuestoNuevoUrl);
    if (!context.mounted) return;

    final editado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Corregir orden de trabajo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: vehiculoCod,
                  decoration: InputDecoration(labelText: tablas.etiquetaVehiculo),
                  items: vehiculos
                      .map((v) => DropdownMenuItem(value: v.cod, child: Text('${v.cod} · ${v.producto}')))
                      .toList(),
                  onChanged: (v) => setState(() => vehiculoCod = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: medidorController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tablas.etiquetaMedidor),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fallaController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción de la falla'),
                ),
                const SizedBox(height: 16),
                const Text('Evidencia fotográfica:', style: AppText.label),
                const SizedBox(height: 8),
                _filaFotoOt(
                  preview: fotoFallaNueva != null
                      ? Image.memory(fotoFallaNueva!, fit: BoxFit.cover)
                      : (urlFotoFallaActual != null
                          ? Image.network(urlFotoFallaActual, fit: BoxFit.cover)
                          : _previewFotoVacia()),
                  etiqueta: 'Foto del repuesto/pieza dañada',
                  textoBoton: 'Cambiar',
                  onElegir: () async {
                    final bytes = await _elegirYComprimirFoto(context);
                    if (bytes != null) setState(() => fotoFallaNueva = bytes);
                  },
                ),
                const SizedBox(height: 8),
                _filaFotoOt(
                  preview: fotoRepuestoNuevoNueva != null
                      ? Image.memory(fotoRepuestoNuevoNueva!, fit: BoxFit.cover)
                      : (urlFotoRepuestoActual != null
                          ? Image.network(urlFotoRepuestoActual, fit: BoxFit.cover)
                          : _previewFotoVacia()),
                  etiqueta: 'Foto del repuesto nuevo (si ya lo tiene)',
                  textoBoton: 'Cambiar',
                  onElegir: () async {
                    final bytes = await _elegirYComprimirFoto(context);
                    if (bytes != null) setState(() => fotoRepuestoNuevoNueva = bytes);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: vehiculoCod == null
                  ? null
                  : () async {
                      final medidor = int.tryParse(medidorController.text.trim()) ?? 0;
                      if (fallaController.text.trim().isEmpty) return;
                      await repo.editarOrdenTrabajo(
                        ordenTrabajoId: orden.id,
                        vehiculoCod: vehiculoCod!,
                        kilometrajeActual: medidor,
                        descripcionFallo: fallaController.text.trim(),
                        bytesFotoFallaNueva: fotoFallaNueva,
                        bytesFotoRepuestoNuevoNueva: fotoRepuestoNuevoNueva,
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    },
              child: const Text('GUARDAR CAMBIOS'),
            ),
          ],
        ),
      ),
    );

    if (editado == true) {
      ref.read(ordenesTrabajoProvider.notifier).refrescar();
    }
  }
}

class _TarjetaOt extends StatelessWidget {
  final OrdenTrabajo orden;
  final Color color;
  final String etiquetaMedidor;
  final VoidCallback onTap;
  final VoidCallback? onEditar;
  final VoidCallback? onCerrar;

  const _TarjetaOt({
    required this.orden,
    required this.color,
    required this.etiquetaMedidor,
    required this.onTap,
    this.onEditar,
    this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.build, color: color),
        ),
        title: Text('${orden.codigoOt} · ${orden.vehiculoProducto ?? orden.vehiculoCod}'),
        subtitle: Text(
          '${orden.descripcionFallo}\nMecánico: ${orden.mecanicoNombre ?? '-'} · $etiquetaMedidor: ${orden.kilometrajeActual}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(orden.estado, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEditar != null)
                  IconButton(
                    tooltip: 'Corregir datos de la OT',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onEditar,
                  ),
                if (onCerrar != null)
                  TextButton(onPressed: onCerrar, child: const Text('Completar', style: TextStyle(fontSize: 12))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
