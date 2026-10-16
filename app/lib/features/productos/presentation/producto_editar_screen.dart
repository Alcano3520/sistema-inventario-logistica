import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_theme.dart';
import '../../../shared/widgets/lector_scanner_dialog.dart';
import '../data/compresor_imagen.dart';
import '../domain/producto.dart';
import '../../../shared/widgets/campo_sugerido.dart';
import 'productos_providers.dart';

/// Edición completa de un producto ya existente — incluye poder corregir el
/// código (p.ej. si se escaneó/escribió mal), a diferencia de la pantalla de
/// registro rápido que solo crea o ajusta cantidad.
class ProductoEditarScreen extends ConsumerStatefulWidget {
  final Producto producto;
  const ProductoEditarScreen({super.key, required this.producto});

  @override
  ConsumerState<ProductoEditarScreen> createState() => _ProductoEditarScreenState();
}

class _ProductoEditarScreenState extends ConsumerState<ProductoEditarScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _codController = TextEditingController(text: widget.producto.cod);
  late final _nombreController = TextEditingController(text: widget.producto.producto);
  late final _stockMinimoController = TextEditingController(text: '${widget.producto.stockMinimo}');
  late final _codigoBarrasController = TextEditingController(text: widget.producto.codigoBarras ?? '');
  late String _categoria = widget.producto.categoria;
  late String _ubicacion = widget.producto.ubicacion;

  Uint8List? _fotoNueva;
  bool _comprimiendoFoto = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _codController.dispose();
    _nombreController.dispose();
    _stockMinimoController.dispose();
    _codigoBarrasController.dispose();
    super.dispose();
  }

  List<String> _opciones(String Function(Producto) campo) {
    final productos = ref.read(productosProvider).valueOrNull ?? [];
    final valores = productos
        .where((p) => p.cod != widget.producto.cod)
        .map(campo)
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    valores.sort();
    return valores;
  }

  Future<void> _elegirFoto() async {
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

    setState(() => _comprimiendoFoto = true);
    try {
      final bytesOriginales = await foto.readAsBytes();
      final comprimida = await compute(CompresorImagen.comprimir, bytesOriginales);
      if (mounted) setState(() => _fotoNueva = comprimida);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo procesar la foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _comprimiendoFoto = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final repo = ref.read(productosRepositoryProvider);
    final codNuevo = _codController.text.trim();

    try {
      String? fotoUrl;
      if (_fotoNueva != null) {
        fotoUrl = await repo.subirFoto(_fotoNueva!, codNuevo.isEmpty ? widget.producto.cod : codNuevo);
      }

      await repo.actualizarProducto(
        codActual: widget.producto.cod,
        codNuevo: codNuevo,
        producto: _nombreController.text.trim(),
        categoria: _categoria,
        ubicacion: _ubicacion,
        stockMinimo: num.tryParse(_stockMinimoController.text) ?? widget.producto.stockMinimo,
        fotoUrl: fotoUrl,
        codigoBarras: _codigoBarrasController.text,
      );
      await ref.read(productosProvider.notifier).refrescar();

      if (mounted) {
        final actualizado = ref
            .read(productosProvider)
            .valueOrNull
            ?.where((p) => p.cod == (codNuevo.isEmpty ? widget.producto.cod : codNuevo))
            .firstOrNull;
        Navigator.pop(context, actualizado);
      }
    } catch (e) {
      setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar producto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codController,
                    decoration: const InputDecoration(labelText: 'Código'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                _FotoMiniatura(
                  fotoNueva: _fotoNueva,
                  fotoActualUrl: widget.producto.fotoUrl,
                  cargando: _comprimiendoFoto,
                  onTap: _elegirFoto,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'El historial de entradas/salidas anteriores queda con el código viejo si lo cambias.',
                style: AppText.bodySecondary,
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre del producto'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _codigoBarrasController,
              decoration: InputDecoration(
                labelText: 'Código de barras del fabricante (opcional)',
                suffixIcon: IconButton(
                  tooltip: 'Escanear',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final codigo = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                          builder: (_) => const LectorScannerDialog(titulo: 'Escanear código de barras')),
                    );
                    if (codigo != null) _codigoBarrasController.text = codigo;
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            CampoSugerido(
              label: 'Categoría',
              initialValue: _categoria,
              opciones: _opciones((p) => p.categoria),
              onChanged: (v) => _categoria = v,
            ),
            const SizedBox(height: 18),
            CampoSugerido(
              label: 'Ubicación',
              initialValue: _ubicacion,
              opciones: _opciones((p) => p.ubicacion),
              onChanged: (v) => _ubicacion = v,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _stockMinimoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock mínimo'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FotoMiniatura extends StatelessWidget {
  final Uint8List? fotoNueva;
  final String? fotoActualUrl;
  final bool cargando;
  final VoidCallback onTap;

  const _FotoMiniatura({
    required this.fotoNueva,
    required this.fotoActualUrl,
    required this.cargando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cargando ? null : onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: cargando
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: fotoNueva != null
                    ? Image.memory(fotoNueva!, fit: BoxFit.cover, width: 56, height: 56)
                    : fotoActualUrl != null
                        ? Image.network(fotoActualUrl!, fit: BoxFit.cover, width: 56, height: 56)
                        : const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 20),
              ),
      ),
    );
  }
}
