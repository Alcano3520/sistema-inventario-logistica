import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

import '../../../core/app_theme.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../productos/presentation/productos_providers.dart';
import '../data/movimientos_repository.dart';
import '../domain/item_movimiento.dart';
import 'firma_widget.dart';
import 'item_row_widget.dart';

final movimientosRepositoryProvider = Provider((ref) => MovimientosRepository());

class EntradaScreen extends ConsumerStatefulWidget {
  const EntradaScreen({super.key});

  @override
  ConsumerState<EntradaScreen> createState() => _EntradaScreenState();
}

class _EntradaScreenState extends ConsumerState<EntradaScreen> {
  DateTime _fecha = DateTime.now();
  final _proveedorController = TextEditingController();
  final _numFacturaController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _items = <ItemMovimiento>[];
  final _firmaController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  bool _guardando = false;
  String? _error;
  String? _exito;

  @override
  void dispose() {
    _proveedorController.dispose();
    _numFacturaController.dispose();
    _observacionesController.dispose();
    _firmaController.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    setState(() {
      _fecha = DateTime.now();
      _proveedorController.clear();
      _numFacturaController.clear();
      _observacionesController.clear();
      _items.clear();
      _firmaController.clear();
      _error = null;
      _exito = null;
    });
  }

  Future<void> _guardar() async {
    setState(() {
      _error = null;
      _exito = null;
    });

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
            proveedor: _proveedorController.text,
            numFactura: _numFacturaController.text,
            observaciones: _observacionesController.text,
            usuarioId: perfil.id,
            usuarioNombre: perfil.nombre,
            items: _items,
            firma: firmaBytes,
          );

      await ref.read(productosProvider.notifier).refrescar();

      if (mounted) {
        setState(() => _exito = 'Entrada registrada exitosamente.');
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📥 Registro de Entrada',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
          _label('Proveedor:'),
          const SizedBox(height: 6),
          TextField(
              controller: _proveedorController,
              decoration: const InputDecoration(hintText: 'Nombre del proveedor')),
          const SizedBox(height: 16),
          _label('Número de Factura/OC:'),
          const SizedBox(height: 6),
          TextField(
              controller: _numFacturaController,
              decoration: const InputDecoration(hintText: 'Opcional')),
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
            titulo: '📦 Productos',
            accion: TextButton(
              onPressed: () => setState(() => _items.add(ItemMovimiento())),
              child: const Text('➕ Agregar Producto'),
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
          _seccion(
            titulo: '✍️ Firma de Recepción',
            child: FirmaWidget(controller: _firmaController),
          ),
          if (_error != null) ...[const SizedBox(height: 16), _mensaje(_error!, exito: false)],
          if (_exito != null) ...[const SizedBox(height: 16), _mensaje(_exito!, exito: true)],
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
                    : const Text('💾 Guardar Entrada'),
              ),
              OutlinedButton(
                onPressed: _guardando ? null : _limpiarFormulario,
                child: const Text('🔄 Limpiar Formulario'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String texto) => Text(texto,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary));

  Widget _seccion({required String titulo, Widget? accion, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(titulo,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              ?accion,
            ],
          ),
          const SizedBox(height: 10),
          child,
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
