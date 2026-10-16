import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
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
    showDialog(
      context: context,
      builder: (_) => _DetalleModal(
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
      ),
    );
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

  const _DetalleModal(
      {required this.titulo,
      required this.campos,
      required this.items,
      required this.firmaUrl,
      this.peticionFotoUrl,
      this.fotoFacturaUrl});

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
