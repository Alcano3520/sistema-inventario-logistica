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

enum _Vista { entradas, salidas, factura }

class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {
  _Vista _vista = _Vista.entradas;
  final _facturaController = TextEditingController();

  // Filtros de Entradas/Salidas: por rango de fecha y por quién registró el
  // movimiento (para auditoría). No aplican a la vista "Por Factura".
  DateTime? _desde;
  DateTime? _hasta;
  String? _usuarioFiltro;

  @override
  void dispose() {
    _facturaController.dispose();
    super.dispose();
  }

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final busqueda = ref.watch(busquedaHistorialProvider).toLowerCase();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Historial de Transacciones', style: AppText.screenTitle),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _tabSec('Entradas', _vista == _Vista.entradas, () => setState(() => _vista = _Vista.entradas)),
              _tabSec('Salidas', _vista == _Vista.salidas, () => setState(() => _vista = _Vista.salidas)),
              _tabSec('Por Factura', _vista == _Vista.factura, () => setState(() => _vista = _Vista.factura)),
            ],
          ),
          const SizedBox(height: 16),
          if (_vista == _Vista.factura) ...[
            const Text(
              'Escribe el número de factura: se muestra todo lo que se compró en ella, aunque haya quedado repartido en varios registros.',
              style: AppText.bodySecondary,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _facturaController,
              decoration: const InputDecoration(
                hintText: 'N° de factura...',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ] else
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por transacción, proveedor, factura...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => ref.read(busquedaHistorialProvider.notifier).state = v,
            ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (_vista) {
              _Vista.entradas => _listaEntradas(busqueda),
              _Vista.salidas => _listaSalidas(busqueda),
              _Vista.factura => _vistaPorFactura(),
            },
          ),
        ],
      ),
    );
  }

  Widget _vistaPorFactura() {
    final termino = _facturaController.text.trim();
    if (termino.isEmpty) {
      return const Center(
        child: Text('Escribe un número de factura para buscar.', style: AppText.bodySecondary),
      );
    }
    return FutureBuilder<List<TransaccionEntrada>>(
      key: ValueKey(termino),
      future: ref.read(historialRepositoryProvider).buscarEntradasPorFactura(termino),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al buscar: ${snapshot.error}'));
        }
        final transacciones = snapshot.data ?? const [];
        if (transacciones.isEmpty) {
          return Center(
            child: Text('No se encontró ninguna entrada con la factura "$termino".',
                style: AppText.bodySecondary),
          );
        }

        final itemsPorProducto = <String, ({String producto, num cantidad})>{};
        for (final t in transacciones) {
          for (final i in t.items) {
            final actual = itemsPorProducto[i.cod];
            itemsPorProducto[i.cod] = (
              producto: i.producto,
              cantidad: (actual?.cantidad ?? 0) + i.cantidad,
            );
          }
        }

        return ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Factura "$termino" — ${transacciones.length} registro(s), ${itemsPorProducto.length} producto(s) distinto(s)',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...itemsPorProducto.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('•  ${e.value.producto} (${e.key}) — Total: ${e.value.cantidad}'),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Registros de compra:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...transacciones.map((t) => _TransaccionCard(
                  titulo: t.idTransaccion,
                  subtitulo: 'Proveedor: ${t.proveedor.isEmpty ? '-' : t.proveedor} · Recibido por: ${t.usuarioNombre}',
                  info: '${_fmtFecha(t.fechaHora)} · ${t.items.length} ítem(s)',
                  onTap: () => _mostrarDetalleEntrada(context, t),
                )),
          ],
        );
      },
    );
  }

  bool get _hayFiltrosActivos => _desde != null || _hasta != null || _usuarioFiltro != null;

  void _limpiarFiltros() {
    setState(() {
      _desde = null;
      _hasta = null;
      _usuarioFiltro = null;
    });
  }

  List<T> _aplicarFiltroFecha<T>(List<T> lista, DateTime Function(T) fechaDe) {
    if (_desde == null && _hasta == null) return lista;
    return lista.where((t) {
      final f = fechaDe(t);
      if (_desde != null && f.isBefore(DateTime(_desde!.year, _desde!.month, _desde!.day))) return false;
      if (_hasta != null &&
          f.isAfter(DateTime(_hasta!.year, _hasta!.month, _hasta!.day, 23, 59, 59))) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _elegirFecha({required bool esDesde}) async {
    final inicial = (esDesde ? _desde : _hasta) ?? DateTime.now();
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (seleccionada == null) return;
    setState(() {
      if (esDesde) {
        _desde = seleccionada;
      } else {
        _hasta = seleccionada;
      }
    });
  }

  /// Barra de filtros compartida entre Entradas y Salidas: rango de fechas
  /// y, debajo, un desplegable con los nombres que efectivamente registraron
  /// algún movimiento en la lista actual (para auditoría rápida).
  Widget _barraFiltros(List<String> usuariosDisponibles) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: OutlinedButton.icon(
                  onPressed: () => _elegirFecha(esDesde: true),
                  icon: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text(_desde == null ? 'Desde' : _fmtFechaCorta(_desde!)),
                ),
              ),
              SizedBox(
                width: 160,
                child: OutlinedButton.icon(
                  onPressed: () => _elegirFecha(esDesde: false),
                  icon: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text(_hasta == null ? 'Hasta' : _fmtFechaCorta(_hasta!)),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: usuariosDisponibles.contains(_usuarioFiltro) ? _usuarioFiltro : null,
                  decoration: const InputDecoration(
                    labelText: 'Registrado por',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                    ...usuariosDisponibles.map((u) => DropdownMenuItem<String?>(value: u, child: Text(u))),
                  ],
                  onChanged: (v) => setState(() => _usuarioFiltro = v),
                ),
              ),
              if (_hayFiltrosActivos)
                TextButton.icon(
                  onPressed: _limpiarFiltros,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Limpiar filtros'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtFechaCorta(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _tabSec(String texto, bool activo, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? AppColors.primary : Colors.white,
          border: Border.all(color: activo ? AppColors.primary : AppColors.border, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(texto,
            style: TextStyle(color: activo ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _listaEntradas(String busqueda) {
    final asyncData = ref.watch(historialEntradasProvider);
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar historial: $e')),
      data: (transacciones) {
        var filtradas = busqueda.isEmpty
            ? transacciones
            : transacciones
                .where((t) =>
                    t.idTransaccion.toLowerCase().contains(busqueda) ||
                    t.proveedor.toLowerCase().contains(busqueda) ||
                    t.numFactura.toLowerCase().contains(busqueda) ||
                    t.usuarioNombre.toLowerCase().contains(busqueda))
                .toList();
        filtradas = _aplicarFiltroFecha(filtradas, (t) => t.fechaHora);
        if (_usuarioFiltro != null) {
          filtradas = filtradas.where((t) => t.usuarioNombre == _usuarioFiltro).toList();
        }
        final usuarios = transacciones.map((t) => t.usuarioNombre).toSet().toList()..sort();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _barraFiltros(usuarios),
            Expanded(
              child: filtradas.isEmpty
                  ? Center(
                      child: Text(
                        _hayFiltrosActivos
                            ? 'No hay entradas que coincidan con los filtros.'
                            : 'No hay entradas registradas.',
                        style: AppText.bodySecondary,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(historialEntradasProvider),
                      child: ListView.builder(
                        itemCount: filtradas.length,
                        itemBuilder: (context, i) {
                          final t = filtradas[i];
                          return _TransaccionCard(
                            titulo: t.idTransaccion,
                            subtitulo: 'Proveedor: ${t.proveedor.isEmpty ? '-' : t.proveedor}',
                            info: '${_fmtFecha(t.fechaHora)} · ${t.usuarioNombre} · ${t.items.length} ítem(s)',
                            onTap: () => _mostrarDetalleEntrada(context, t),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _listaSalidas(String busqueda) {
    final asyncData = ref.watch(historialSalidasProvider);
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar historial: $e')),
      data: (transacciones) {
        var filtradas = busqueda.isEmpty
            ? transacciones
            : transacciones
                .where((t) =>
                    t.idTransaccion.toLowerCase().contains(busqueda) ||
                    t.aQuienEntrega.toLowerCase().contains(busqueda) ||
                    t.usuarioNombre.toLowerCase().contains(busqueda))
                .toList();
        filtradas = _aplicarFiltroFecha(filtradas, (t) => t.fechaHora);
        if (_usuarioFiltro != null) {
          filtradas = filtradas.where((t) => t.usuarioNombre == _usuarioFiltro).toList();
        }
        final usuarios = transacciones.map((t) => t.usuarioNombre).toSet().toList()..sort();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _barraFiltros(usuarios),
            Expanded(
              child: filtradas.isEmpty
                  ? Center(
                      child: Text(
                        _hayFiltrosActivos
                            ? 'No hay salidas que coincidan con los filtros.'
                            : 'No hay salidas registradas.',
                        style: AppText.bodySecondary,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(historialSalidasProvider),
                      child: ListView.builder(
                        itemCount: filtradas.length,
                        itemBuilder: (context, i) {
                          final t = filtradas[i];
                          return _TransaccionCard(
                            titulo: t.idTransaccion,
                            subtitulo: 'Bote: ${t.bote.isEmpty ? '-' : t.bote} · Entregado a: ${t.aQuienEntrega}',
                            info: '${_fmtFecha(t.fechaHora)} · ${t.usuarioNombre} · ${t.items.length} ítem(s)',
                            onTap: () => _mostrarDetalleSalida(context, t),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDetalleEntrada(BuildContext context, TransaccionEntrada t) {
    final puedeEditar = ref.read(perfilActualProvider).valueOrNull?.puedeEditarFacturas ?? false;
    showDialog(
      context: context,
      builder: (dialogContext) => _DetalleModal(
        titulo: 'Entrada ${t.idTransaccion}',
        campos: [
          'Fecha: ${_fmtFecha(t.fechaHora)}',
          'Proveedor: ${t.proveedor.isEmpty ? '-' : t.proveedor}',
          if (t.numFactura.isNotEmpty) 'N° Factura/OC: ${t.numFactura}',
          if (t.claveAccesoSri != null && t.claveAccesoSri!.isNotEmpty)
            'Clave de acceso SRI: ${t.claveAccesoSri}',
          'Registrado por: ${t.usuarioNombre}',
          if (t.observaciones.isNotEmpty) 'Observaciones: ${t.observaciones}',
        ],
        items: t.items,
        firmaUrl: t.firmaUrl,
        fotoFacturaUrl: t.fotoFacturaUrl,
        onEditar: puedeEditar
            ? () {
                Navigator.of(dialogContext).pop();
                _editarEntrada(t);
              }
            : null,
      ),
    );
  }

  /// Corrige los datos de una factura (Entrada) ya registrada — solo
  /// visible para Admin, sin límite de tiempo. Exige una nota explicando la
  /// corrección, que queda agregada a las observaciones (no borra lo que ya
  /// había). Si cambia alguna cantidad, el stock se recalcula al guardar.
  Future<void> _editarEntrada(TransaccionEntrada t) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Debe escribir una observación explicando la corrección.')));
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

    comparar('Fecha', _fmtFecha(t.fechaHora).split(' ').first,
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}');
    comparar('Proveedor', t.proveedor, proveedorController.text.trim());
    comparar('N° Factura/OC', t.numFactura, numFacturaController.text.trim());
    comparar('Clave de acceso SRI', t.claveAccesoSri ?? '', claveController.text.trim());
    for (final nuevo in nuevosItems) {
      final original = t.items.firstWhere((i) => i.id == nuevo.id);
      comparar('Producto (${original.cod})', original.producto, nuevo.producto);
      comparar('Cantidad (${original.cod})', '${original.cantidad}', '${nuevo.cantidad}');
      comparar('Precio unitario (${original.cod})', '${original.precioUnitario ?? ''}',
          '${nuevo.precioUnitario ?? ''}');
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
      if (mounted) {
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
        await ActaCorreccionPdfService.imprimirOCompartirPdf(
            pdfBytes, 'acta_correccion_${t.idTransaccion}');
      }
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al corregir: $e')));
      }
    }
  }

  void _mostrarDetalleSalida(BuildContext context, TransaccionSalida t) {
    showDialog(
      context: context,
      builder: (_) => _DetalleModal(
        titulo: 'Salida ${t.idTransaccion}',
        campos: [
          'Fecha: ${_fmtFecha(t.fechaHora)}',
          'Bote: ${t.bote.isEmpty ? '-' : t.bote}',
          'Entregado a: ${t.aQuienEntrega}',
          if (t.identificacionQuienRecibe.isNotEmpty)
            'Identificación de quien recibe: ${t.identificacionQuienRecibe}',
          'Confirmación de recepción: ${t.confirmacionRecepcion ? 'Sí' : 'No'}',
          if (t.proposito.isNotEmpty) 'Propósito: ${t.proposito}',
          'Registrado por: ${t.usuarioNombre}',
          if (t.peticionTexto != null && t.peticionTexto!.isNotEmpty) 'Petición de salida: ${t.peticionTexto}',
        ],
        items: t.items,
        firmaUrl: t.firmaUrl,
        peticionFotoUrl: t.peticionFotoUrl,
      ),
    );
  }
}

class _TransaccionCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String info;
  final VoidCallback onTap;

  const _TransaccionCard(
      {required this.titulo, required this.subtitulo, required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitulo, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(info, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _DetalleModal extends StatelessWidget {
  final String titulo;
  final List<String> campos;
  final List<DetalleItem> items;
  final String? firmaUrl;
  final String? peticionFotoUrl;
  final String? fotoFacturaUrl;
  final VoidCallback? onEditar;

  const _DetalleModal(
      {required this.titulo,
      required this.campos,
      required this.items,
      required this.firmaUrl,
      this.peticionFotoUrl,
      this.fotoFacturaUrl,
      this.onEditar});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titulo),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width - 64).clamp(0, 400),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...campos.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(c),
                  )),
              const Divider(height: 24),
              const Text('Productos:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...items.map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('•  ${i.producto} (${i.cod}) — Cant: ${i.cantidad}'),
                  )),
              if (peticionFotoUrl != null) ...[
                const SizedBox(height: 16),
                const Text('Foto de sustento:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _FirmaPreview(path: peticionFotoUrl!),
              ],
              if (fotoFacturaUrl != null) ...[
                const SizedBox(height: 16),
                const Text('Foto de la factura:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _FirmaPreview(path: fotoFacturaUrl!),
              ],
              if (firmaUrl != null) ...[
                const SizedBox(height: 16),
                const Text('Firma:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _FirmaPreview(path: firmaUrl!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (onEditar != null)
          TextButton(onPressed: onEditar, child: const Text('Editar factura')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    );
  }
}

class _FirmaPreview extends ConsumerWidget {
  final String path;

  const _FirmaPreview({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.read(historialRepositoryProvider).firmaUrlFirmada(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox(
              height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return Container(
          decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: BorderRadius.circular(6)),
          child: Image.network(snapshot.data!, fit: BoxFit.contain, height: 120),
        );
      },
    );
  }
}
