import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/app_theme.dart';
import '../../../shared/widgets/lector_scanner_dialog.dart';
import '../../../shared/widgets/nota_banner.dart';
import '../../../shared/widgets/visor_foto.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/compresor_imagen.dart';
import '../data/similitud_texto.dart';
import '../domain/producto.dart';
import '../../../shared/widgets/campo_sugerido.dart';
import 'producto_detalle_screen.dart';
import 'productos_providers.dart';

/// Registro rápido de productos pensado para un conteo físico de
/// inventario: escanear (o escribir) el código, y según exista o no, crear
/// el producto con su cantidad inicial o corregir la cantidad de uno ya
/// registrado — todo sin salir de la pantalla, listo para escanear el
/// siguiente de inmediato.
class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

enum _ModoProductos { registro, buscar }

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final _codController = TextEditingController();
  final _scrollController = ScrollController();

  _ModoProductos _modo = _ModoProductos.registro;
  bool _verificando = false;
  String? _codigoActivo;
  Producto? _productoExistente;
  bool _codigoGenerado = false;

  int _registrados = 0;
  int _corregidos = 0;

  @override
  void dispose() {
    _codController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _procesarCodigo(String codigoCrudo, {bool generado = false}) async {
    final codigo = codigoCrudo.trim();
    if (codigo.isEmpty) return;
    _codigoGenerado = generado;

    setState(() => _verificando = true);
    try {
      final existente = await ref.read(productosRepositoryProvider).buscarPorCodigo(codigo);
      if (!mounted) return;
      setState(() {
        _codigoActivo = codigo;
        _productoExistente = existente;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo verificar el código: $e')));
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LectorScannerDialog(titulo: 'Escanear producto')),
    );
    if (codigo != null) await _procesarCodigo(codigo);
  }

  /// Para productos que no vienen con un código de barras físico: genera
  /// uno interno único acá mismo, al crear el producto — después de creado
  /// ya no hay nada que generar, solo reimprimir el mismo código.
  Future<void> _generarCodigo() async {
    final marca = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final aleatorio = Random().nextInt(1296).toRadixString(36).padLeft(2, '0').toUpperCase();
    await _procesarCodigo('INT$marca$aleatorio', generado: true);
  }

  void _cancelar() {
    setState(() {
      _codigoActivo = null;
      _productoExistente = null;
      _codigoGenerado = false;
      _codController.clear();
    });
  }

  void _onGuardado({required bool esNuevo}) {
    setState(() {
      if (esNuevo) {
        _registrados++;
      } else {
        _corregidos++;
      }
      _codigoActivo = null;
      _productoExistente = null;
      _codController.clear();
    });
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<_ModoProductos>(
            segments: const [
              ButtonSegment(
                  value: _ModoProductos.registro,
                  label: Text('Registro rápido'),
                  icon: Icon(Icons.qr_code_scanner, size: 18)),
              ButtonSegment(
                  value: _ModoProductos.buscar,
                  label: Text('Buscar / Editar'),
                  icon: Icon(Icons.search, size: 18)),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() => _modo = s.first),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _modo == _ModoProductos.registro ? _vistaRegistro() : const _BuscarYEditar(),
          ),
        ],
      ),
    );
  }

  Widget _vistaRegistro() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Registrar Producto', style: AppText.screenTitle)),
              if (_registrados + _corregidos > 0) _ContadorSesion(nuevos: _registrados, corregidos: _corregidos),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Escanea el código de barras — si el producto no existe lo creas con su cantidad inicial; '
            'si ya existe, corriges la cantidad contada.',
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: 20),
          if (_codigoActivo == null)
            _BuscadorCodigo(
              controller: _codController,
              onEscanear: _escanear,
              onConfirmar: _procesarCodigo,
              onGenerar: _generarCodigo,
            ),
          if (_verificando) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (!_verificando && _codigoActivo != null && _productoExistente == null)
            _FormularioNuevoProducto(
              codigo: _codigoActivo!,
              codigoGenerado: _codigoGenerado,
              onCancelar: _cancelar,
              onGuardado: () => _onGuardado(esNuevo: true),
            ),
          if (!_verificando && _codigoActivo != null && _productoExistente != null)
            _FormularioCorregirCantidad(
              producto: _productoExistente!,
              onCancelar: _cancelar,
              onGuardado: () => _onGuardado(esNuevo: false),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Buscar entre los productos ya registrados y tocar uno para editarlo —
/// cambiar nombre, categoría, ubicación, stock mínimo o el código mismo.
class _BuscarYEditar extends ConsumerWidget {
  const _BuscarYEditar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productosAsync = ref.watch(productosProvider);
    final filtrados = ref.watch(productosFiltradosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar por código o nombre...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => ref.read(busquedaProductosProvider.notifier).state = v,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: productosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error al cargar productos: $e')),
            data: (_) {
              if (filtrados.isEmpty) {
                return const Center(child: Text('No se encontraron productos.'));
              }
              return ListView.separated(
                itemCount: filtrados.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = filtrados[i];
                  return _FilaProductoEditable(producto: p);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilaProductoEditable extends StatelessWidget {
  final Producto producto;
  const _FilaProductoEditable({required this.producto});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: producto)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: producto.fotoUrl != null
                  ? Image.network(producto.fotoUrl!, width: 40, height: 40, fit: BoxFit.cover)
                  : Container(
                      width: 40,
                      height: 40,
                      color: AppColors.surfaceAlt,
                      child: const Icon(Icons.image_outlined, size: 16, color: AppColors.textSecondary),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto.producto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Cód: ${producto.cod} · Stock: ${producto.stock}', style: AppText.bodySecondary),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ContadorSesion extends StatelessWidget {
  final int nuevos;
  final int corregidos;

  const _ContadorSesion({required this.nuevos, required this.corregidos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(6)),
      child: Text(
        '$nuevos nuevos · $corregidos corregidos',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
      ),
    );
  }
}

class _BuscadorCodigo extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEscanear;
  final ValueChanged<String> onConfirmar;
  final VoidCallback onGenerar;

  const _BuscadorCodigo({
    required this.controller,
    required this.onEscanear,
    required this.onConfirmar,
    required this.onGenerar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onEscanear,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear código de barras'),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: const [
          Expanded(child: Divider()),
          Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('o', style: AppText.bodySecondary)),
          Expanded(child: Divider()),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Escribir código manualmente',
            prefixIcon: Icon(Icons.keyboard_outlined),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: onConfirmar,
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onGenerar,
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: const Text('El producto no tiene código de barras — generar uno'),
        ),
      ],
    );
  }
}

/// Producto nuevo: nombre + cantidad inicial + foto al frente; categoría,
/// ubicación y stock mínimo quedan colapsados porque no son indispensables
/// para avanzar rápido en un conteo.
class _FormularioNuevoProducto extends ConsumerStatefulWidget {
  final String codigo;
  final bool codigoGenerado;
  final VoidCallback onCancelar;
  final VoidCallback onGuardado;

  const _FormularioNuevoProducto({
    required this.codigo,
    this.codigoGenerado = false,
    required this.onCancelar,
    required this.onGuardado,
  });

  @override
  ConsumerState<_FormularioNuevoProducto> createState() => _FormularioNuevoProductoState();
}

class _FormularioNuevoProductoState extends ConsumerState<_FormularioNuevoProducto> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');
  final _stockMinimoController = TextEditingController(text: '5');
  final _facturaController = TextEditingController();
  final _precioController = TextEditingController();
  final _codigoBarrasController = TextEditingController();
  String _categoria = '';
  String _ubicacion = '';

  Uint8List? _fotoComprimida;
  bool _comprimiendoFoto = false;
  bool _guardando = false;
  String? _error;
  List<Producto> _parecidos = const [];

  @override
  void initState() {
    super.initState();
    _nombreController.addListener(_verificarNombreParecido);
  }

  @override
  void dispose() {
    _nombreController.removeListener(_verificarNombreParecido);
    _nombreController.dispose();
    _cantidadController.dispose();
    _stockMinimoController.dispose();
    _facturaController.dispose();
    _precioController.dispose();
    _codigoBarrasController.dispose();
    super.dispose();
  }

  /// Valores ya usados por otros productos del catálogo (sin vacíos, sin
  /// repetidos) — para ofrecerlos como sugerencia en Categoría/Ubicación.
  List<String> _opciones(String Function(Producto) campo) {
    final productos = ref.read(productosProvider).valueOrNull ?? [];
    final valores = productos.map(campo).where((v) => v.isNotEmpty).toSet().toList();
    valores.sort();
    return valores;
  }

  void _verificarNombreParecido() {
    final nombre = _nombreController.text.trim();
    if (nombre.length < 3) {
      if (_parecidos.isNotEmpty) setState(() => _parecidos = const []);
      return;
    }
    final productos = ref.read(productosProvider).valueOrNull ?? [];
    final coincidencias =
        productos.where((p) => SimilitudTexto.sonParecidos(p.producto, nombre)).toList();
    setState(() => _parecidos = coincidencias);
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
      if (mounted) setState(() => _fotoComprimida = comprimida);
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
    final usuario = ref.read(perfilActualProvider).valueOrNull;
    if (usuario == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final repo = ref.read(productosRepositoryProvider);
    final nombre = _nombreController.text.trim();
    final cantidadInicial = num.tryParse(_cantidadController.text.trim()) ?? 0;

    try {
      String? fotoUrl;
      if (_fotoComprimida != null) {
        fotoUrl = await repo.subirFoto(_fotoComprimida!, widget.codigo);
      }

      await repo.agregarProducto(
        cod: widget.codigo,
        producto: nombre,
        categoria: _categoria,
        ubicacion: _ubicacion,
        stockMinimo: num.tryParse(_stockMinimoController.text) ?? 5,
        fotoUrl: fotoUrl,
        codigoBarras: _codigoBarrasController.text,
      );

      if (cantidadInicial > 0) {
        await repo.registrarConteoFisico(
          cod: widget.codigo,
          producto: nombre,
          stockActual: 0,
          cantidadContada: cantidadInicial,
          usuarioId: usuario.id,
          usuarioNombre: usuario.nombre,
          numFactura: _facturaController.text,
          precioUnitario: num.tryParse(_precioController.text.trim()),
        );
      }

      await ref.read(productosProvider.notifier).refrescar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$nombre registrado con $cantidadInicial en stock.')),
        );
        if (widget.codigoGenerado) {
          await _ofrecerImprimir(nombre);
        }
        widget.onGuardado();
      }
    } on PostgrestException catch (e) {
      setState(() => _error = e.code == '23505' ? 'Ese código ya fue registrado.' : 'Error: ${e.message}');
    } catch (e) {
      setState(() => _error = 'No se pudo guardar el producto.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _ofrecerImprimir(String nombre) async {
    final imprimir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código generado'),
        content: Text(
            'Se generó el código ${widget.codigo} para "$nombre". ¿Imprimir la etiqueta ahora para pegarla en el producto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Más tarde')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Imprimir ahora')),
        ],
      ),
    );
    if (imprimir != true || !mounted) return;
    try {
      final servicio = ref.read(barcodePdfServiceProvider);
      final bytes = await servicio.generarEtiqueta(cod: widget.codigo, nombre: nombre);
      await servicio.imprimir(bytes, 'etiqueta_${widget.codigo}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo generar la etiqueta: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.fiber_new_outlined, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Producto nuevo · ${widget.codigo}',
                    style: AppText.sectionTitle, overflow: TextOverflow.ellipsis),
              ),
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: widget.onCancelar, tooltip: 'Cancelar'),
            ]),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nombreController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre del producto'),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            if (_parecidos.isNotEmpty) ...[
              const SizedBox(height: 10),
              NotaBanner(
                tipo: TipoNota.advertencia,
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(
                        text: 'Ya existe un producto con nombre parecido:\n',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(
                      text: _parecidos
                          .map((p) => '${p.producto} (${p.cod})')
                          .join('\n'),
                    ),
                  ]),
                  style: AppText.body,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cantidadController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cantidad inicial (stock)'),
                    validator: (v) => (num.tryParse(v?.trim() ?? '') == null) ? 'Número inválido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FotoPicker(
                    foto: _fotoComprimida,
                    cargando: _comprimiendoFoto,
                    onTap: _elegirFoto,
                    onQuitar: () => setState(() => _fotoComprimida = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Más detalles (opcional)', style: AppText.bodySecondary),
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [
                TextFormField(
                  controller: _codigoBarrasController,
                  decoration: InputDecoration(
                    labelText: 'Código de barras del fabricante (opcional)',
                    helperText: 'Distinto del código de producto (${widget.codigo}) — es el que trae de fábrica.',
                    helperMaxLines: 2,
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
                const SizedBox(height: 14),
                CampoSugerido(
                  label: 'Categoría',
                  initialValue: _categoria,
                  opciones: _opciones((p) => p.categoria),
                  onChanged: (v) => _categoria = v,
                ),
                const SizedBox(height: 14),
                CampoSugerido(
                  label: 'Ubicación',
                  initialValue: _ubicacion,
                  opciones: _opciones((p) => p.ubicacion),
                  onChanged: (v) => _ubicacion = v,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _stockMinimoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock mínimo'),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 4),
                const Text('Compra que respalda la cantidad inicial (opcional):', style: AppText.bodySecondary),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _facturaController,
                  decoration: const InputDecoration(labelText: 'N° de factura'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _precioController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Precio unitario de compra', prefixText: '\$'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar y escanear siguiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Producto que ya existe (de los que "están mal"): corrige la cantidad
/// contada. Se traduce a una Entrada o Salida real — nunca se sobreescribe
/// `stock` directo.
class _FormularioCorregirCantidad extends ConsumerStatefulWidget {
  final Producto producto;
  final VoidCallback onCancelar;
  final VoidCallback onGuardado;

  const _FormularioCorregirCantidad({required this.producto, required this.onCancelar, required this.onGuardado});

  @override
  ConsumerState<_FormularioCorregirCantidad> createState() => _FormularioCorregirCantidadState();
}

class _FormularioCorregirCantidadState extends ConsumerState<_FormularioCorregirCantidad> {
  late final _cantidadController = TextEditingController(text: '${widget.producto.stock}');
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final contada = num.tryParse(_cantidadController.text.trim());
    if (contada == null) {
      setState(() => _error = 'Ingresa un número válido.');
      return;
    }
    final usuario = ref.read(perfilActualProvider).valueOrNull;
    if (usuario == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref.read(productosRepositoryProvider).registrarConteoFisico(
            cod: widget.producto.cod,
            producto: widget.producto.producto,
            stockActual: widget.producto.stock,
            cantidadContada: contada,
            usuarioId: usuario.id,
            usuarioNombre: usuario.nombre,
          );
      await ref.read(productosProvider.notifier).refrescar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.producto.producto}: stock corregido a $contada.')),
        );
        widget.onGuardado();
      }
    } catch (e) {
      setState(() => _error = 'No se pudo registrar la corrección.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.fact_check_outlined, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Ya existe — corregir cantidad', style: AppText.sectionTitle)),
            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: widget.onCancelar, tooltip: 'Cancelar'),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              if (p.fotoUrl != null) ...[
                GestureDetector(
                  onTap: () => VisorFotoScreen.abrir(context, url: p.fotoUrl!, titulo: p.producto),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(p.fotoUrl!, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.producto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Código: ${p.cod} · Sistema dice: ${p.stock}', style: AppText.bodySecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cantidadController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cantidad real contada'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              child: _guardando
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar corrección y escanear siguiente'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FotoPicker extends StatelessWidget {
  final Uint8List? foto;
  final bool cargando;
  final VoidCallback onTap;
  final VoidCallback onQuitar;

  const _FotoPicker({required this.foto, required this.cargando, required this.onTap, required this.onQuitar});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cargando ? null : onTap,
      child: Stack(
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: cargando
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : foto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.memory(foto!, fit: BoxFit.cover, width: double.infinity, height: 56),
                      )
                    : const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 20),
          ),
          if (foto != null && !cargando)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onQuitar,
                child: const CircleAvatar(
                  radius: 9,
                  backgroundColor: AppColors.error,
                  child: Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
