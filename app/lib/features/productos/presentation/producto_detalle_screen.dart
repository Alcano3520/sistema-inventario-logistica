import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../../../shared/widgets/visor_foto.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../historial/domain/transaccion.dart';
import '../../historial/presentation/editar_entrada_dialog.dart';
import '../../historial/presentation/historial_providers.dart';
import '../domain/producto.dart';
import 'producto_editar_screen.dart';
import 'productos_providers.dart';

/// Ficha del producto: foto (ampliable), existencias y el código de barras
/// mostrado en pantalla — para poder fotografiarlo y enviarlo, o reimprimir
/// una etiqueta perdida. El código en sí se genera al crear el producto
/// (pantalla de registro), no aquí — aquí solo se muestra/imprime el que
/// ya tiene.
class ProductoDetalleScreen extends ConsumerStatefulWidget {
  final Producto producto;
  const ProductoDetalleScreen({super.key, required this.producto});

  @override
  ConsumerState<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends ConsumerState<ProductoDetalleScreen> {
  late Producto _producto = widget.producto;
  bool _generandoPdf = false;
  bool _descargandoFicha = false;
  bool _exportandoExcel = false;
  bool _ordenAscendente = false;
  late Future<List<MovimientoProducto>> _historialFuture = _cargarHistorial();

  Future<List<MovimientoProducto>> _cargarHistorial() =>
      ref.read(historialRepositoryProvider).obtenerHistorialProducto(_producto.cod);

  Future<void> _imprimirEtiqueta() async {
    setState(() => _generandoPdf = true);
    try {
      final servicio = ref.read(barcodePdfServiceProvider);
      final bytes = await servicio.generarEtiqueta(cod: _producto.cod, nombre: _producto.producto);
      await servicio.imprimir(bytes, 'etiqueta_${_producto.cod}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo generar la etiqueta: $e')));
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  Future<void> _descargarFicha() async {
    setState(() => _descargandoFicha = true);
    try {
      final servicio = ref.read(fichaPdfServiceProvider);
      final bytes = await servicio.generarFicha(_producto);
      await servicio.compartir(bytes, 'ficha_${_producto.cod}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo generar la ficha: $e')));
      }
    } finally {
      if (mounted) setState(() => _descargandoFicha = false);
    }
  }

  Future<void> _editar() async {
    final actualizado = await Navigator.of(context).push<Producto>(
      MaterialPageRoute(builder: (_) => ProductoEditarScreen(producto: _producto)),
    );
    if (actualizado != null && mounted) {
      setState(() {
        _producto = actualizado;
        _historialFuture = _cargarHistorial();
      });
    }
  }

  Future<void> _exportarExcel() async {
    setState(() => _exportandoExcel = true);
    try {
      final movimientos = await _historialFuture;
      final resultado =
          await ref.read(exportadorInventarioProvider).exportarHistorialProducto(_producto, movimientos);
      if (mounted && !resultado.cancelado) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Guardado en: ${resultado.ruta}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportandoExcel = false);
    }
  }

  /// Abre la corrección de la factura/Entrada de la que vino este
  /// movimiento del kardex — reutiliza el mismo flujo de Historial (nota
  /// obligatoria, acta PDF, recálculo de stock). Al terminar, refresca el
  /// kardex y el stock mostrado arriba, por si la cantidad cambió.
  Future<void> _editarMovimiento(MovimientoProducto m) async {
    final transaccion = await ref.read(historialRepositoryProvider).obtenerEntradaPorId(m.idTransaccion);
    if (transaccion == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se encontró la factura de este movimiento.')));
      }
      return;
    }
    if (!mounted) return;
    await editarEntradaDialog(context, ref, transaccion);
    if (!mounted) return;
    final actualizado = ref.read(productosProvider).valueOrNull?.where((p) => p.cod == _producto.cod).firstOrNull;
    setState(() {
      if (actualizado != null) _producto = actualizado;
      _historialFuture = _cargarHistorial();
    });
  }

  void _verFoto() {
    if (_producto.fotoUrl == null) return;
    VisorFotoScreen.abrir(context, url: _producto.fotoUrl!, titulo: _producto.producto);
  }

  @override
  Widget build(BuildContext context) {
    final p = _producto;
    final puedeEditar = ref.watch(perfilActualProvider).valueOrNull?.puedeGestionarProductos ?? false;
    final Color colorEstado = p.sinStock
        ? AppColors.error
        : p.stockBajo
            ? AppColors.warning
            : AppColors.success;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.producto, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: _descargandoFicha
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_outlined),
            tooltip: 'Descargar ficha del producto',
            onPressed: _descargandoFicha ? null : _descargarFicha,
          ),
          if (puedeEditar)
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar', onPressed: _editar),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: p.fotoUrl != null ? _verFoto : null,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: p.fotoUrl != null
                        ? Image.network(
                            p.fotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const _FotoVacia(),
                          )
                        : const _FotoVacia(),
                  ),
                ),
                if (p.fotoUrl != null)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration:
                          BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.producto, style: AppText.sectionTitle),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: colorEstado.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text('Stock: ${p.stock}',
                          style: TextStyle(color: colorEstado, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _dato('Código', p.cod),
                if (p.codigoBarras != null && p.codigoBarras!.isNotEmpty)
                  _dato('Código de barras (fabricante)', p.codigoBarras!),
                if (p.categoria.isNotEmpty) _dato('Categoría', p.categoria),
                if (p.ubicacion.isNotEmpty) _dato('Ubicación', p.ubicacion),
                _dato('Entradas', '${p.entrada}'),
                _dato('Salidas', '${p.salida}'),
                _dato('Stock mínimo', '${p.stockMinimo}'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Código de barras', style: AppText.sectionTitle),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Puedes fotografiar esta pantalla para compartir el código, o reimprimir la etiqueta.',
                    style: AppText.bodySecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: p.cod,
                    color: Colors.black,
                    height: 90,
                    drawText: true,
                    style: const TextStyle(color: Colors.black, fontSize: 13, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _generandoPdf ? null : _imprimirEtiqueta,
                    icon: _generandoPdf
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print_outlined, size: 18),
                    label: Text(_generandoPdf ? 'Generando…' : 'Imprimir código de barras'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _seccionHistorial(),
        ],
      ),
    );
  }

  Widget _seccionHistorial() {
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    final puedeEditarFacturas = ref.watch(perfilActualProvider).valueOrNull?.puedeEditarFacturas ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Historial de este producto', style: AppText.sectionTitle)),
              IconButton(
                tooltip: _ordenAscendente
                    ? 'Mostrar lo más reciente primero'
                    : 'Mostrar lo más antiguo primero',
                icon: Icon(_ordenAscendente ? Icons.arrow_downward : Icons.arrow_upward, size: 20),
                onPressed: () => setState(() => _ordenAscendente = !_ordenAscendente),
              ),
              _exportandoExcel
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      tooltip: 'Descargar Excel del historial',
                      icon: const Icon(Icons.file_download_outlined, size: 20),
                      onPressed: _exportarExcel,
                    ),
            ],
          ),
          Text(
            _ordenAscendente
                ? 'En orden: primero lo más antiguo, con el saldo que queda después de cada movimiento.'
                : 'En orden: primero lo más reciente, con el saldo que queda después de cada movimiento.',
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<MovimientoProducto>>(
            key: ValueKey(_producto.cod),
            future: _historialFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              if (snapshot.hasError) {
                return Text('No se pudo cargar el historial: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.error, fontSize: 13));
              }
              final movimientos = snapshot.data ?? const [];
              if (movimientos.isEmpty) {
                return const Text('Este producto todavía no tiene entradas ni salidas registradas.',
                    style: AppText.bodySecondary);
              }
              final lista = _ordenAscendente ? movimientos : movimientos.reversed.toList();
              return Column(
                children: lista.map((m) {
                  final esEntrada = m.tipo == 'Entrada';
                  final color = esEntrada ? AppColors.success : AppColors.info;
                  final fondo = esEntrada ? AppColors.successBg : AppColors.infoBg;
                  final fechaTexto = formatoFecha.format(m.fecha.toLocal());
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fondo,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: color, width: 4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(esEntrada ? Icons.call_received : Icons.call_made, size: 18, color: color),
                            const SizedBox(width: 6),
                            Text(esEntrada ? 'ENTRADA' : 'SALIDA',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                            const Spacer(),
                            Text(
                              '${esEntrada ? '+' : '−'}${m.cantidad}',
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (esEntrada && puedeEditarFacturas) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _editarMovimiento(m),
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        _filaDato('Fecha', fechaTexto),
                        if (esEntrada) ...[
                          _filaDato('Proveedor',
                              (m.proveedor != null && m.proveedor!.isNotEmpty) ? m.proveedor! : 'No especificado'),
                          if (m.numFactura != null && m.numFactura!.isNotEmpty)
                            _filaDato('N° de Factura', m.numFactura!,
                                onTap: () => _verFacturaCompleta(context, m.numFactura!),
                                accionTexto: 'Ver todo lo comprado'),
                          _filaEvidencia('Ver firma de quien recibió', m.firmaUrl,
                              onTap: () => _abrirEvidencia(m.firmaUrl, 'Firma — $fechaTexto')),
                          _filaEvidencia('Ver foto de la factura', m.fotoFacturaUrl,
                              onTap: () => _abrirEvidencia(m.fotoFacturaUrl, 'Factura — $fechaTexto')),
                        ] else ...[
                          _filaDato('Entregado a',
                              (m.aQuien != null && m.aQuien!.isNotEmpty) ? m.aQuien! : 'No especificado'),
                          if (m.proposito != null && m.proposito!.isNotEmpty)
                            _filaDato('Propósito', m.proposito!),
                          _filaEvidencia('Ver foto de sustento', m.fotoSustentoUrl,
                              onTap: () => _abrirEvidencia(m.fotoSustentoUrl, 'Foto de sustento — $fechaTexto'),
                              advertirSiFalta: true),
                          _filaEvidencia('Ver firma de quien recibió', m.firmaUrl,
                              onTap: () => _abrirEvidencia(m.firmaUrl, 'Firma — $fechaTexto')),
                        ],
                        const Divider(height: 18),
                        _filaDato('Saldo después de este movimiento', '${m.saldo}', destacado: true),
                        if (m.saldo < 0) ...[
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.error_outline, size: 14, color: AppColors.error),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Saldo negativo — hay más salidas registradas que entradas hasta este punto. Revisar.',
                                  style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Abre en pantalla completa una foto de evidencia o firma guardada en el
  /// bucket de firmas (requiere firmar la URL, no es pública).
  Future<void> _abrirEvidencia(String? path, String titulo) async {
    if (path == null || path.isEmpty) return;
    final url = await ref.read(historialRepositoryProvider).firmaUrlFirmada(path);
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudo cargar la evidencia.')));
      return;
    }
    VisorFotoScreen.abrir(context, url: url, titulo: titulo);
  }

  /// Muestra un enlace tocable para ver una foto/firma de evidencia, o una
  /// advertencia cuando falta (p.ej. salidas registradas antes de que la
  /// foto de sustento fuera obligatoria).
  Widget _filaEvidencia(String etiqueta, String? path,
      {required VoidCallback onTap, bool advertirSiFalta = false}) {
    if (path == null || path.isEmpty) {
      if (!advertirSiFalta) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 3),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'Sin evidencia — registro anterior a que la foto fuera obligatoria',
                style: TextStyle(fontSize: 12, color: AppColors.warning, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 3),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(etiqueta,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline)),
          ],
        ),
      ),
    );
  }

  /// Una fila de "Etiqueta: valor" clara, sin truncar — opcionalmente
  /// tocable (p.ej. para abrir el detalle completo de una factura).
  Widget _filaDato(String etiqueta, String valor, {bool destacado = false, VoidCallback? onTap, String? accionTexto}) {
    final contenido = Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$etiqueta: ',
            style: TextStyle(
              fontSize: destacado ? 14 : 13,
              color: AppColors.textSecondary,
              fontWeight: destacado ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          TextSpan(
            text: valor,
            style: TextStyle(
              fontSize: destacado ? 15 : 13,
              color: onTap != null ? AppColors.primary : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              decoration: onTap != null ? TextDecoration.underline : null,
            ),
          ),
          if (accionTexto != null)
            TextSpan(
              text: '  ·  $accionTexto',
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
        ]),
      ),
    );
    if (onTap == null) return contenido;
    return InkWell(onTap: onTap, child: contenido);
  }

  /// Esta línea del kardex es solo lo que le tocó a ESTE producto; una
  /// factura puede haber traído varios productos a la vez. Este diálogo
  /// muestra todo lo que se compró bajo esa misma factura.
  Future<void> _verFacturaCompleta(BuildContext context, String numFactura) async {
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Factura $numFactura'),
        content: SizedBox(
          width: 420,
          child: FutureBuilder<List<TransaccionEntrada>>(
            future: ref.read(historialRepositoryProvider).buscarEntradasPorFactura(numFactura),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                    height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final transacciones = snapshot.data ?? const [];
              if (transacciones.isEmpty) {
                return const Text('No se encontraron registros con esta factura.');
              }
              final itemsPorProducto = <String, ({String producto, num cantidad})>{};
              for (final t in transacciones) {
                for (final i in t.items) {
                  final actual = itemsPorProducto[i.cod];
                  itemsPorProducto[i.cod] =
                      (producto: i.producto, cantidad: (actual?.cantidad ?? 0) + i.cantidad);
                }
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${transacciones.length} registro(s) de compra bajo esta factura:',
                        style: AppText.bodySecondary),
                    const SizedBox(height: 10),
                    ...itemsPorProducto.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('•  ${e.value.producto} (${e.key}) — ${e.value.cantidad}'),
                        )),
                    const Divider(height: 24),
                    ...transacciones.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${formatoFecha.format(t.fechaHora.toLocal())} · ${t.proveedor.isEmpty ? 'Sin proveedor' : t.proveedor} · Recibido por: ${t.usuarioNombre}',
                            style: AppText.bodySecondary,
                          ),
                        )),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _dato(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          TextSpan(
              text: valor,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _FotoVacia extends StatelessWidget {
  const _FotoVacia();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 48, color: AppColors.textSecondary),
    );
  }
}
