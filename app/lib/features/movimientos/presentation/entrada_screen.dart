import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../../core/app_theme.dart';
import '../../../core/modulos.dart';
import '../../../core/plataforma.dart';
import '../../../shared/widgets/campo_sugerido.dart';
import '../../../shared/widgets/lector_scanner_dialog.dart';
import '../../../shared/widgets/nota_banner.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../historial/presentation/historial_providers.dart';
import '../../productos/data/compresor_imagen.dart';
import '../../productos/domain/producto.dart';
import '../../productos/presentation/productos_providers.dart';
import '../data/lector_factura_imagen.dart';
import '../data/lector_factura_pdf.dart';
import '../data/movimientos_repository.dart';
import '../domain/factura_extraida.dart';
import '../domain/item_movimiento.dart';
import 'firma_widget.dart';
import 'item_row_widget.dart';

final movimientosRepositoryProvider = Provider<MovimientosRepository>(
  (ref) => MovimientosRepository(ref.watch(tablasActivasProvider)),
);

class EntradaScreen extends ConsumerStatefulWidget {
  const EntradaScreen({super.key});

  @override
  ConsumerState<EntradaScreen> createState() => _EntradaScreenState();
}

class _EntradaScreenState extends ConsumerState<EntradaScreen> {
  DateTime _fecha = DateTime.now();
  String _proveedor = '';
  final _numFacturaController = TextEditingController();
  final _claveAccesoController = TextEditingController();
  final _observacionesController = TextEditingController();
  Uint8List? _fotoFactura;
  final _items = <ItemMovimiento>[];
  final _firmaController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  bool _guardando = false;
  bool _leyendoFactura = false;
  String? _error;
  String? _exito;
  int _formVersion = 0;

  @override
  void dispose() {
    _numFacturaController.dispose();
    _claveAccesoController.dispose();
    _observacionesController.dispose();
    _firmaController.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    setState(() {
      _fecha = DateTime.now();
      _proveedor = '';
      _numFacturaController.clear();
      _claveAccesoController.clear();
      _observacionesController.clear();
      _fotoFactura = null;
      _items.clear();
      _firmaController.clear();
      _error = null;
      _exito = null;
      _formVersion++;
    });
  }

  Future<void> _elegirFotoFactura() async {
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
    if (mounted) setState(() => _fotoFactura = comprimida);
  }

  /// Lee el PDF de la factura y pre-llena lo que se pueda detectar. Nunca
  /// sobrescribe un campo que la persona ya haya escrito, y los ítems
  /// detectados se muestran para que elija cuáles agregar — nunca se
  /// agregan solos ni se auto-selecciona el producto del catálogo.
  Future<void> _leerFactura() async {
    setState(() => _error = null);
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final bytes = resultado?.files.single.bytes;
    if (bytes == null || !mounted) return;

    setState(() => _leyendoFactura = true);
    FacturaExtraida? factura;
    String? errorLectura;
    try {
      factura = await LectorFacturaPdf.extraer(bytes);
    } catch (e) {
      errorLectura = '$e';
    } finally {
      if (mounted) setState(() => _leyendoFactura = false);
    }
    if (!mounted) return;

    if (errorLectura != null) {
      setState(() => _error = 'No se pudo leer el PDF de la factura: $errorLectura');
      return;
    }
    if (factura == null || !factura.tieneAlgo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se detectó ningún dato reconocible en ese PDF. Complete el formulario a mano.')));
      return;
    }

    await _mostrarResultadoFactura(factura);
  }

  /// Igual que [_leerFactura] pero a partir de una FOTO de la factura
  /// (OCR con Google ML Kit) en vez del PDF — solo disponible en Android,
  /// la pantalla solo muestra este botón cuando [kOcrFacturaDisponible].
  Future<void> _leerFacturaFoto() async {
    setState(() => _error = null);
    final foto = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    if (foto == null || !mounted) return;

    setState(() => _leyendoFactura = true);
    FacturaExtraida? factura;
    String? errorLectura;
    try {
      factura = await LectorFacturaImagen.extraer(foto.path);
    } catch (e) {
      errorLectura = '$e';
    } finally {
      if (mounted) setState(() => _leyendoFactura = false);
    }
    if (!mounted) return;

    if (errorLectura != null) {
      setState(() => _error = 'No se pudo leer la foto de la factura: $errorLectura');
      return;
    }
    if (factura == null || !factura.tieneAlgo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No se detectó ningún dato reconocible en esa foto. Procure que la factura se vea completa, '
              'derecha y con buena luz, o complete el formulario a mano.')));
      return;
    }

    await _mostrarResultadoFactura(factura);
  }

  /// Empareja el código tal como viene en la factura (del proveedor) contra
  /// el catálogo, por código interno o código de barras — solo si coincide
  /// EXACTO. Si no hay coincidencia exacta, devuelve null y la persona debe
  /// elegir el producto a mano: nunca se inventa ni se fuerza un código.
  Producto? _buscarPorCodigoProveedor(List<Producto> productos, String? codigoProveedor) {
    if (codigoProveedor == null || codigoProveedor.trim().isEmpty) return null;
    final buscado = codigoProveedor.trim().toLowerCase();
    for (final p in productos) {
      if (p.cod.toLowerCase() == buscado) return p;
    }
    for (final p in productos) {
      if (p.codigoBarras != null && p.codigoBarras!.toLowerCase() == buscado) return p;
    }
    return null;
  }

  Future<void> _mostrarResultadoFactura(FacturaExtraida factura) async {
    final seleccionados = <int>{for (var i = 0; i < factura.items.length; i++) i};
    final productos = ref.read(productosProvider).valueOrNull ?? [];
    final coincidencias = <int, Producto>{};
    for (var i = 0; i < factura.items.length; i++) {
      final match = _buscarPorCodigoProveedor(productos, factura.items[i].codigoProveedor);
      if (match != null) coincidencias[i] = match;
    }
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Datos detectados en la factura'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revise antes de aplicar — la detección es automática y puede no ser exacta para todos los formatos de factura.',
                    style: AppText.bodySecondary,
                  ),
                  const SizedBox(height: 12),
                  if (factura.proveedor != null) Text('Proveedor: ${factura.proveedor}'),
                  if (factura.numFactura != null) Text('N° de Factura: ${factura.numFactura}'),
                  if (factura.claveAcceso != null)
                    Text('Clave de acceso SRI: ${factura.claveAcceso!.substring(0, 12)}…'),
                  if (factura.fecha != null)
                    Text('Fecha: ${factura.fecha!.day.toString().padLeft(2, '0')}/'
                        '${factura.fecha!.month.toString().padLeft(2, '0')}/${factura.fecha!.year}'),
                  if (factura.proveedor == null &&
                      factura.numFactura == null &&
                      factura.claveAcceso == null &&
                      factura.fecha == null)
                    const Text('No se detectaron campos de encabezado.', style: AppText.bodySecondary),
                  if (factura.items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      coincidencias.isEmpty
                          ? 'Ítems detectados (${factura.items.length}) — elija cuáles agregar:'
                          : 'Ítems detectados (${factura.items.length}) — ${coincidencias.length} '
                              'coinciden con su catálogo por código, elija cuáles agregar:',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cuando el código de la factura coincide exacto con uno de su catálogo, el producto ya '
                      'queda elegido; si no, trae solo la descripción y debe buscarlo a mano en esa fila.',
                      style: AppText.bodySecondary,
                    ),
                    const SizedBox(height: 6),
                    ...factura.items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final match = coincidencias[i];
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: seleccionados.contains(i),
                        onChanged: (v) => setDialogState(() {
                          if (v == true) {
                            seleccionados.add(i);
                          } else {
                            seleccionados.remove(i);
                          }
                        }),
                        title: Text(match?.producto ?? item.descripcion, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          '${match != null ? '✓ Coincide: ${match.cod}  ·  ' : ''}'
                          'Cant: ${item.cantidad ?? '-'}'
                          '${item.precioUnitario != null ? '  ·  \$${item.precioUnitario!.toStringAsFixed(2)} c/u' : ''}',
                          style: TextStyle(
                              fontSize: 11, color: match != null ? AppColors.success : AppColors.textSecondary),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _aplicarFactura(factura, seleccionados, coincidencias);
              },
              child: const Text('Usar estos datos'),
            ),
          ],
        ),
      ),
    );
  }

  void _aplicarFactura(
      FacturaExtraida factura, Set<int> itemsSeleccionados, Map<int, Producto> coincidencias) {
    setState(() {
      if (factura.proveedor != null && _proveedor.trim().isEmpty) {
        _proveedor = factura.proveedor!;
        _formVersion++;
      }
      if (factura.numFactura != null && _numFacturaController.text.trim().isEmpty) {
        _numFacturaController.text = factura.numFactura!;
      }
      if (factura.claveAcceso != null && _claveAccesoController.text.trim().isEmpty) {
        _claveAccesoController.text = factura.claveAcceso!;
      }
      if (factura.fecha != null) {
        _fecha = factura.fecha!;
      }
      for (final i in itemsSeleccionados) {
        if (i < 0 || i >= factura.items.length) continue;
        final detectado = factura.items[i];
        final match = coincidencias[i];
        _items.add(ItemMovimiento(
          cod: match?.cod ?? '',
          producto: match?.producto ?? detectado.descripcion,
          cantidad: detectado.cantidad?.toString() ?? '',
          precioUnitario: detectado.precioUnitario != null
              ? detectado.precioUnitario!.toStringAsFixed(2)
              : '',
        ));
      }
      _exito = null;
    });
    final nCoincidencias =
        itemsSeleccionados.where((i) => coincidencias.containsKey(i)).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nCoincidencias > 0
            ? 'Datos de la factura aplicados — $nCoincidencias ítem(s) ya quedaron con su producto del catálogo. Revise antes de guardar.'
            : 'Datos de la factura aplicados. Revise antes de guardar.'),
      ),
    );
  }

  Future<void> _guardar() async {
    setState(() {
      _error = null;
      _exito = null;
    });

    if (_proveedor.trim().isEmpty) {
      setState(() => _error = 'Debe indicar el proveedor.');
      return;
    }
    if (_numFacturaController.text.trim().isEmpty) {
      setState(() => _error = 'Debe indicar el número de factura/OC.');
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

      await ref.read(movimientosRepositoryProvider).registrarEntrada(
            fecha: _fecha,
            proveedor: _proveedor,
            numFactura: _numFacturaController.text,
            observaciones: _observacionesController.text,
            usuarioId: perfil.id,
            usuarioNombre: perfil.nombre,
            items: _items,
            firma: firmaBytes,
            claveAccesoSri: _claveAccesoController.text,
            fotoFactura: _fotoFactura,
          );

      await ref.read(productosProvider.notifier).refrescar();

      if (mounted) {
        _limpiarFormulario();
        setState(() => _exito = 'Entrada registrada exitosamente.');
      }
    } catch (e) {
      setState(() => _error = 'Error al registrar entrada: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(productosProvider).valueOrNull ?? [];
    final historialEntradas = ref.watch(historialEntradasProvider).valueOrNull ?? [];
    final proveedoresPrevios = historialEntradas
        .map((t) => t.proveedor)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registro de Entrada', style: AppText.screenTitle),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_outlined, color: AppColors.info, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kOcrFacturaDisponible
                        ? 'Puede leer el PDF o una foto de la factura para pre-llenar proveedor, N° de factura, clave SRI, fecha e ítems.'
                        : 'Puede leer el PDF de la factura para pre-llenar proveedor, N° de factura, clave SRI, fecha e ítems.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 10),
                if (_leyendoFactura)
                  const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _leerFactura,
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Leer PDF'),
                      ),
                      if (kOcrFacturaDisponible)
                        OutlinedButton.icon(
                          onPressed: _leerFacturaFoto,
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text('Leer foto'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
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
                        mostrarPrecio: true,
                        onRemove: () => setState(() => _items.remove(item)),
                        onChanged: () => setState(() {}),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          _label('Fecha de Entrada:'),
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
          _labelRequerido('Proveedor:'),
          const SizedBox(height: 6),
          CampoSugerido(
            key: ValueKey('proveedor-$_formVersion'),
            label: 'Nombre del proveedor',
            initialValue: _proveedor,
            opciones: proveedoresPrevios,
            onChanged: (v) => _proveedor = v,
          ),
          const SizedBox(height: 16),
          _labelRequerido('Número de Factura/OC:'),
          const SizedBox(height: 6),
          TextField(
              controller: _numFacturaController,
              decoration: const InputDecoration(hintText: 'Obligatorio — respalda la compra')),
          const SizedBox(height: 16),
          _label('Clave de acceso SRI (opcional):'),
          const SizedBox(height: 4),
          const Text(
            'El código de 49 dígitos del código de barras de la factura electrónica (RIDE) — sirve como respaldo oficial, no reemplaza el N° de factura de arriba.',
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _claveAccesoController,
            decoration: InputDecoration(
              hintText: 'Escanear o pegar los 49 dígitos',
              suffixIcon: IconButton(
                tooltip: 'Escanear código de barras de la factura',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () async {
                  final codigo = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                        builder: (_) => const LectorScannerDialog(titulo: 'Escanear código de barras de la factura')),
                  );
                  if (codigo != null) _claveAccesoController.text = codigo;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('Foto de la factura (opcional):'),
          const SizedBox(height: 4),
          const Text(
            'Una foto de la factura física, como respaldo adicional.',
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_fotoFactura != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(_fotoFactura!, width: 48, height: 48, fit: BoxFit.cover),
                ),
              if (_fotoFactura != null) const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _elegirFotoFactura,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(_fotoFactura == null ? 'Tomar foto de la factura' : 'Cambiar foto'),
              ),
              if (_fotoFactura != null)
                IconButton(
                  onPressed: () => setState(() => _fotoFactura = null),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Observaciones:'),
          const SizedBox(height: 6),
          TextField(
            controller: _observacionesController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Observaciones adicionales (opcional)'),
          ),
          const SizedBox(height: 20),
          _seccion(
            titulo: 'Firma de Recepción',
            child: FirmaWidget(controller: _firmaController),
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
                    : const Text('Guardar Entrada'),
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
