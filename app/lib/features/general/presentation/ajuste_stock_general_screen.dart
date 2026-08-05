import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/articulo_general.dart';
import 'general_providers.dart';

enum _TipoAjuste { entrada, baja, ajuste }

class AjusteStockGeneralScreen extends ConsumerStatefulWidget {
  const AjusteStockGeneralScreen({super.key});

  @override
  ConsumerState<AjusteStockGeneralScreen> createState() => _AjusteStockGeneralScreenState();
}

class _AjusteStockGeneralScreenState extends ConsumerState<AjusteStockGeneralScreen> {
  final _busquedaController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _motivoController = TextEditingController();
  ArticuloGeneral? _articulo;
  _TipoAjuste _tipo = _TipoAjuste.entrada;
  bool _guardando = false;
  String? _error;
  String? _exito;

  @override
  void dispose() {
    _busquedaController.dispose();
    _cantidadController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _error = null;
      _exito = null;
    });

    final cantidad = num.tryParse(_cantidadController.text);
    if (_articulo == null) {
      setState(() => _error = 'Seleccione un artículo.');
      return;
    }
    if (cantidad == null || cantidad <= 0) {
      setState(() => _error = 'Ingrese una cantidad válida.');
      return;
    }

    final perfil = ref.read(perfilActualProvider).valueOrNull;
    if (perfil == null) return;

    setState(() => _guardando = true);
    try {
      final repo = ref.read(movimientosGeneralRepositoryProvider);
      switch (_tipo) {
        case _TipoAjuste.entrada:
          await repo.registrarEntradaStock(
            articuloId: _articulo!.id,
            cantidad: cantidad,
            stockActual: _articulo!.stockDisponible,
            usuarioId: perfil.id,
            usuarioNombre: perfil.nombre,
            motivo: _motivoController.text,
          );
          break;
        case _TipoAjuste.baja:
          await repo.registrarBaja(
            articuloId: _articulo!.id,
            cantidad: cantidad,
            stockActual: _articulo!.stockDisponible,
            usuarioId: perfil.id,
            usuarioNombre: perfil.nombre,
            motivo: _motivoController.text,
          );
          break;
        case _TipoAjuste.ajuste:
          await repo.registrarAjuste(
            articuloId: _articulo!.id,
            stockAnterior: _articulo!.stockDisponible,
            stockNuevo: cantidad,
            usuarioId: perfil.id,
            usuarioNombre: perfil.nombre,
            motivo: _motivoController.text,
          );
          break;
      }

      await ref.read(articulosGeneralProvider.notifier).refrescar();

      if (mounted) {
        setState(() {
          _exito = 'Movimiento registrado exitosamente.';
          _articulo = null;
          _busquedaController.clear();
          _cantidadController.clear();
          _motivoController.clear();
        });
      }
    } catch (e) {
      setState(() => _error = 'Error al registrar el movimiento: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final articulos = ref.watch(articulosGeneralProvider).valueOrNull ?? [];
    final busqueda = _busquedaController.text.trim().toLowerCase();
    final filtrados = busqueda.isEmpty
        ? const <ArticuloGeneral>[]
        : articulos
            .where((a) =>
                a.descripcion.toLowerCase().contains(busqueda) ||
                a.codigoInterno.toLowerCase().contains(busqueda))
            .take(15)
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚖️ Ajuste de Inventario',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          if (_articulo != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FD),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                        '${_articulo!.descripcion} — Stock actual: ${_articulo!.stockDisponible}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close), onPressed: () => setState(() => _articulo = null)),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _busquedaController,
              decoration: const InputDecoration(hintText: 'Buscar artículo...'),
              onChanged: (_) => setState(() {}),
            ),
            ...filtrados.map((a) => ListTile(
                  dense: true,
                  title: Text(a.descripcion),
                  subtitle: Text('${a.codigoInterno} · Stock: ${a.stockDisponible}'),
                  onTap: () => setState(() {
                    _articulo = a;
                    _busquedaController.clear();
                  }),
                )),
          ],
          const SizedBox(height: 16),
          SegmentedButton<_TipoAjuste>(
            segments: const [
              ButtonSegment(value: _TipoAjuste.entrada, label: Text('Entrada')),
              ButtonSegment(value: _TipoAjuste.baja, label: Text('Baja')),
              ButtonSegment(value: _TipoAjuste.ajuste, label: Text('Fijar stock')),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => setState(() => _tipo = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cantidadController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _tipo == _TipoAjuste.ajuste ? 'Nuevo stock total' : 'Cantidad',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivoController,
            decoration: const InputDecoration(labelText: 'Motivo'),
          ),
          if (_error != null) ...[const SizedBox(height: 16), _mensaje(_error!, exito: false)],
          if (_exito != null) ...[const SizedBox(height: 16), _mensaje(_exito!, exito: true)],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('💾 Registrar Movimiento'),
          ),
        ],
      ),
    );
  }

  Widget _mensaje(String texto, {required bool exito}) {
    final color = exito ? AppColors.success : AppColors.error;
    final bg = exito ? const Color(0xFFE8F8F5) : const Color(0xFFFDEAEA);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Text(texto, style: TextStyle(color: color)),
    );
  }
}
