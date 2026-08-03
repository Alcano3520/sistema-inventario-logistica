import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../domain/transaccion.dart';
import 'historial_providers.dart';

class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {
  bool _mostrandoEntradas = true;

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
          const Text(
            '📜 Historial de Transacciones',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _tabSec('Entradas', _mostrandoEntradas, () => setState(() => _mostrandoEntradas = true)),
              _tabSec('Salidas', !_mostrandoEntradas, () => setState(() => _mostrandoEntradas = false)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(hintText: '🔍 Buscar transacción...'),
            onChanged: (v) => ref.read(busquedaHistorialProvider.notifier).state = v,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _mostrandoEntradas ? _listaEntradas(busqueda) : _listaSalidas(busqueda),
          ),
        ],
      ),
    );
  }

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
            style: TextStyle(color: activo ? Colors.white : const Color(0xFF5A6C7D))),
      ),
    );
  }

  Widget _listaEntradas(String busqueda) {
    final asyncData = ref.watch(historialEntradasProvider);
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar historial: $e')),
      data: (transacciones) {
        final filtradas = busqueda.isEmpty
            ? transacciones
            : transacciones
                .where((t) =>
                    t.idTransaccion.toLowerCase().contains(busqueda) ||
                    t.proveedor.toLowerCase().contains(busqueda) ||
                    t.usuarioNombre.toLowerCase().contains(busqueda))
                .toList();
        if (filtradas.isEmpty) {
          return const Center(child: Text('No hay entradas registradas.'));
        }
        return RefreshIndicator(
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
        final filtradas = busqueda.isEmpty
            ? transacciones
            : transacciones
                .where((t) =>
                    t.idTransaccion.toLowerCase().contains(busqueda) ||
                    t.aQuienEntrega.toLowerCase().contains(busqueda) ||
                    t.usuarioNombre.toLowerCase().contains(busqueda))
                .toList();
        if (filtradas.isEmpty) {
          return const Center(child: Text('No hay salidas registradas.'));
        }
        return RefreshIndicator(
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
        );
      },
    );
  }

  void _mostrarDetalleEntrada(BuildContext context, TransaccionEntrada t) {
    showDialog(
      context: context,
      builder: (_) => _DetalleModal(
        titulo: '📥 Entrada ${t.idTransaccion}',
        campos: [
          'Fecha: ${_fmtFecha(t.fechaHora)}',
          'Proveedor: ${t.proveedor.isEmpty ? '-' : t.proveedor}',
          if (t.numFactura.isNotEmpty) 'N° Factura/OC: ${t.numFactura}',
          'Registrado por: ${t.usuarioNombre}',
          if (t.observaciones.isNotEmpty) 'Observaciones: ${t.observaciones}',
        ],
        items: t.items,
        firmaUrl: t.firmaUrl,
      ),
    );
  }

  void _mostrarDetalleSalida(BuildContext context, TransaccionSalida t) {
    showDialog(
      context: context,
      builder: (_) => _DetalleModal(
        titulo: '📤 Salida ${t.idTransaccion}',
        campos: [
          'Fecha: ${_fmtFecha(t.fechaHora)}',
          'Bote: ${t.bote.isEmpty ? '-' : t.bote}',
          'Entregado a: ${t.aQuienEntrega}',
          if (t.proposito.isNotEmpty) 'Propósito: ${t.proposito}',
          'Registrado por: ${t.usuarioNombre}',
        ],
        items: t.items,
        firmaUrl: t.firmaUrl,
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
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(6),
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

  const _DetalleModal(
      {required this.titulo, required this.campos, required this.items, required this.firmaUrl});

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
