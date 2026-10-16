import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:postgrest/postgrest.dart';
import 'package:signature/signature.dart';

import '../../../core/app_theme.dart';
import '../../../core/modulos.dart';
import '../../../shared/widgets/campo_sugerido.dart';
import '../../../shared/widgets/nota_banner.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../historial/presentation/historial_providers.dart';
import '../../productos/data/compresor_imagen.dart';
import '../../productos/presentation/productos_providers.dart';
import 'entrada_screen.dart' show movimientosRepositoryProvider;
import '../domain/item_movimiento.dart';
import 'firma_widget.dart';
import 'item_row_widget.dart';

class SalidaScreen extends ConsumerStatefulWidget {
  const SalidaScreen({super.key});

  @override
  ConsumerState<SalidaScreen> createState() => _SalidaScreenState();
}

class _SalidaScreenState extends ConsumerState<SalidaScreen> {
  DateTime _fecha = DateTime.now();
  String _vehiculo = '';
  String _aQuien = '';
  final _identificacionController = TextEditingController();
  bool _confirmacionRecepcion = false;
  final _propositoController = TextEditingController();
  final _peticionController = TextEditingController();
  Uint8List? _fotoPeticion;
  final _items = <ItemMovimiento>[];
  final _firmaController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  bool _guardando = false;
  String? _error;
  String? _exito;
  int _formVersion = 0;

  @override
  void dispose() {
    _identificacionController.dispose();
    _propositoController.dispose();
    _peticionController.dispose();
    _firmaController.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    setState(() {
      _fecha = DateTime.now();
      _vehiculo = '';
      _aQuien = '';
      _identificacionController.clear();
      _confirmacionRecepcion = false;
      _propositoController.clear();
      _peticionController.clear();
      _fotoPeticion = null;
      _items.clear();
      _firmaController.clear();
      _error = null;
      _exito = null;
      _formVersion++;
    });
  }

  Future<void> _elegirFotoPeticion() async {
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
    if (origen == null || !mounted) return;

    final foto = await ImagePicker().pickImage(source: origen, imageQuality: 90);
    if (foto == null || !mounted) return;

    final bytesOriginales = await foto.readAsBytes();
    final comprimida = await compute(CompresorImagen.comprimirSustento, bytesOriginales);
    if (mounted) setState(() => _fotoPeticion = comprimida);
  }

  Future<void> _guardar() async {
    setState(() {
      _error = null;
      _exito = null;
    });

    final tablas = ref.read(tablasActivasProvider);
    if (_vehiculo.trim().isEmpty) {
      setState(() => _error = 'Debe especificar el campo "${tablas.etiquetaVehiculo}".');
      return;
    }
    if (_aQuien.trim().isEmpty) {
      setState(() => _error = 'Debe especificar a quién se entrega.');
      return;
    }
    if (_identificacionController.text.trim().isEmpty) {
      setState(() => _error = 'Debe especificar la identificación (cédula) de quien recibe.');
      return;
    }
    if (!_confirmacionRecepcion) {
      setState(() => _error = 'Debe confirmar que la persona recibió los artículos.');
      return;
    }
    if (_fotoPeticion == null) {
      setState(() => _error = 'Debe adjuntar una foto como sustento de la salida.');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Debe agregar al menos un ítem.');
      return;
    }
    for (final item in _items) {
      if (item.cod.isEmpty || item.cantidad.isEmpty || num.tryParse(item.cantidad) == null) {
        setState(() => _error = 'Complete producto y cantidad válida en todos los ítems.');
        return;
      }
    }

    final perfil = ref.read(perfilActualProvider).valueOrNull;
    if (perfil == null) return;

    setState(() => _guardando = true);
    try {
      final firmaBytes = _firmaController.isNotEmpty ? await _firmaController.toPngBytes() : null;

      await ref.read(movimientosRepositoryProvider).registrarSalida(
            fecha: _fecha,
            bote: _vehiculo,
            aQuienEntrega: _aQuien,
            identificacionQuienRecibe: _identificacionController.text.trim(),
            confirmacionRecepcion: _confirmacionRecepcion,
            proposito: _propositoController.text,
            usuarioId: perfil.id,
            usuarioNombre: perfil.nombre,
            items: _items,
            firma: firmaBytes,
            peticionTexto: _peticionController.text,
            bytesFotoPeticion: _fotoPeticion,
          );

      await ref.read(productosProvider.notifier).refrescar();

      if (mounted) {
        _limpiarFormulario();
        setState(() => _exito = 'Salida registrada exitosamente.');
      }
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error al registrar salida: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(productosProvider).valueOrNull ?? [];
    final tablas = ref.watch(tablasActivasProvider);
    final historialSalidas = ref.watch(historialSalidasProvider).valueOrNull ?? [];
    final vehiculosPrevios = historialSalidas
        .map((t) => t.bote)
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final destinatariosPrevios = historialSalidas
        .map((t) => t.aQuienEntrega)
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registro de Salida', style: AppText.screenTitle),
          const SizedBox(height: 20),
          _seccion(
            titulo: 'Productos',
            accion: TextButton.icon(
              onPressed: () => setState(() => _items.add(ItemMovimiento())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar Producto'),
            ),
            child: Column(
              children: _items
                  .map((item) => ItemRowWidget(
                        key: ValueKey(item),
                        item: item,
                        productos: productos,
                        onRemove: () => setState(() => _items.remove(item)),
                        onChanged: () => setState(() {}),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          _label('Fecha de Salida:'),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final seleccionada = await showDatePicker(
                context: context,
                initialDate: _fecha,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (seleccionada != null) setState(() => _fecha = seleccionada);
            },
            child: InputDecorator(
              decoration: const InputDecoration(),
              child: Text('${_fecha.day.toString().padLeft(2, '0')}/'
                  '${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}'),
            ),
          ),
          const SizedBox(height: 16),
          _labelRequerido('${tablas.etiquetaVehiculo}:'),
          const SizedBox(height: 6),
          CampoSugerido(
            key: ValueKey('vehiculo-$_formVersion'),
            label: tablas.hintVehiculo,
            initialValue: _vehiculo,
            opciones: vehiculosPrevios,
            onChanged: (v) => _vehiculo = v,
          ),
          const SizedBox(height: 16),
          _labelRequerido('A quién se entrega:'),
          const SizedBox(height: 6),
          CampoSugerido(
            key: ValueKey('aquien-$_formVersion'),
            label: 'Nombre de la persona que recibe',
            initialValue: _aQuien,
            opciones: destinatariosPrevios,
            onChanged: (v) => _aQuien = v,
          ),
          const SizedBox(height: 16),
          _labelRequerido('Identificación (cédula) de quien recibe:'),
          const SizedBox(height: 6),
          TextField(
            controller: _identificacionController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(hintText: 'Número de cédula de la persona que recibe'),
          ),
          const SizedBox(height: 16),
          _label('Propósito de la salida:'),
          const SizedBox(height: 6),
          TextField(
            controller: _propositoController,
            maxLines: 2,
            decoration: const InputDecoration(
                hintText: 'Para qué se utilizarán los repuestos (opcional)'),
          ),
          const SizedBox(height: 16),
          _label('Petición de salida (opcional):'),
          const SizedBox(height: 4),
          const Text(
            'Si esta salida responde a una petición (por ejemplo, del administrador), puedes anotar quién la pidió.',
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _peticionController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Quién pidió y para qué (opcional)'),
          ),
          const SizedBox(height: 20),
          _labelRequerido('Foto de sustento de la salida:'),
          const SizedBox(height: 4),
          const Text(
            'Obligatoria en toda salida — es la evidencia de que el despacho realmente ocurrió.',
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_fotoPeticion != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(_fotoPeticion!, width: 48, height: 48, fit: BoxFit.cover),
                ),
              if (_fotoPeticion != null) const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _elegirFotoPeticion,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(_fotoPeticion == null ? 'Tomar foto de sustento' : 'Cambiar foto'),
              ),
              if (_fotoPeticion != null)
                IconButton(
                  onPressed: () => setState(() => _fotoPeticion = null),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _seccion(
            titulo: 'Firma de Recepción',
            child: FirmaWidget(controller: _firmaController),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _confirmacionRecepcion = !_confirmacionRecepcion),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _confirmacionRecepcion,
                  onChanged: (v) => setState(() => _confirmacionRecepcion = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Text(
                      'Confirmo que la persona indicada arriba recibió los artículos de esta salida.',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 16), NotaBanner.texto(_error!, tipo: TipoNota.error)],
          if (_exito != null) ...[const SizedBox(height: 16), NotaBanner.texto(_exito!, tipo: TipoNota.exito)],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar Salida'),
              ),
              OutlinedButton(
                onPressed: _guardando ? null : _limpiarFormulario,
                child: const Text('Limpiar Formulario'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String texto) => Text(texto,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary));

  Widget _labelRequerido(String texto) => Text.rich(
        TextSpan(children: [
          const TextSpan(text: '* ', style: TextStyle(color: AppColors.error)),
          TextSpan(text: texto),
        ]),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
      );

  Widget _seccion({required String titulo, Widget? accion, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(titulo, style: AppText.sectionTitle)),
              ?accion,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
