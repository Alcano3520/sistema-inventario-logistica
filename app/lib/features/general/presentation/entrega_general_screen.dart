import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

import '../../../core/app_theme.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../movimientos/presentation/firma_widget.dart';
import '../domain/articulo_general.dart';
import '../domain/empleado_externo.dart';
import '../domain/item_carrito.dart';
import 'general_providers.dart';

class EntregaGeneralScreen extends ConsumerStatefulWidget {
  const EntregaGeneralScreen({super.key});

  @override
  ConsumerState<EntregaGeneralScreen> createState() => _EntregaGeneralScreenState();
}

class _EntregaGeneralScreenState extends ConsumerState<EntregaGeneralScreen> {
  final _busquedaEmpleadoController = TextEditingController();
  final _nombreManualController = TextEditingController();
  final _cedulaManualController = TextEditingController();
  final _cargoManualController = TextEditingController();
  final _baseManualController = TextEditingController();
  final _busquedaArticuloController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _firmaController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);

  Timer? _debounce;
  List<EmpleadoExterno> _resultadosEmpleado = [];
  bool _buscandoEmpleado = false;
  EmpleadoExterno? _empleadoSeleccionado;
  bool _entradaManual = false;

  final List<ItemCarrito> _carrito = [];
  bool _guardando = false;
  String? _error;
  String? _exito;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaEmpleadoController.dispose();
    _nombreManualController.dispose();
    _cedulaManualController.dispose();
    _cargoManualController.dispose();
    _baseManualController.dispose();
    _busquedaArticuloController.dispose();
    _observacionesController.dispose();
    _firmaController.dispose();
    super.dispose();
  }

  void _buscarEmpleado(String termino) {
    _debounce?.cancel();
    if (termino.trim().length < 2) {
      setState(() => _resultadosEmpleado = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _buscandoEmpleado = true);
      try {
        final resultados = await ref.read(empleadosExternosRepositoryProvider).buscar(termino);
        if (mounted) setState(() => _resultadosEmpleado = resultados);
      } finally {
        if (mounted) setState(() => _buscandoEmpleado = false);
      }
    });
  }

  void _agregarArticulo(ArticuloGeneral articulo) {
    final existente = _carrito.where((i) => i.articulo.id == articulo.id).firstOrNull;
    setState(() {
      if (existente != null) {
        existente.cantidad += 1;
      } else {
        _carrito.add(ItemCarrito(articulo: articulo));
      }
    });
  }

  void _limpiarFormulario() {
    setState(() {
      _empleadoSeleccionado = null;
      _entradaManual = false;
      _busquedaEmpleadoController.clear();
      _nombreManualController.clear();
      _cedulaManualController.clear();
      _cargoManualController.clear();
      _baseManualController.clear();
      _resultadosEmpleado = [];
      _carrito.clear();
      _observacionesController.clear();
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

    if (_empleadoSeleccionado == null &&
        (_nombreManualController.text.trim().isEmpty || _cedulaManualController.text.trim().isEmpty)) {
      setState(() => _error = 'Seleccione un empleado o ingrese nombre y cédula manualmente.');
      return;
    }
    if (_carrito.isEmpty) {
      setState(() => _error = 'Agregue al menos un artículo.');
      return;
    }
    for (final item in _carrito) {
      if (item.cantidad <= 0) {
        setState(() => _error = 'Todas las cantidades deben ser mayores a cero.');
        return;
      }
      if (item.cantidad > item.articulo.stockDisponible) {
        setState(() =>
            _error = 'Stock insuficiente de "${item.articulo.descripcion}" (disponible: ${item.articulo.stockDisponible}).');
        return;
      }
    }

    final perfil = ref.read(perfilActualProvider).valueOrNull;
    if (perfil == null) return;

    setState(() => _guardando = true);
    try {
      final firmaBytes = _firmaController.isNotEmpty ? await _firmaController.toPngBytes() : null;

      final sincronizado = await ref.read(movimientosGeneralRepositoryProvider).registrarEntrega(
            items: _carrito,
            empleado: _empleadoSeleccionado,
            nombreManual: _nombreManualController.text,
            cedulaManual: _cedulaManualController.text,
            cargoManual: _cargoManualController.text,
            baseManual: _baseManualController.text,
            usuarioId: perfil.id,
            usuarioNombre: perfil.nombre,
            observaciones: _observacionesController.text,
            firma: firmaBytes,
          );

      if (sincronizado) {
        await ref.read(articulosGeneralProvider.notifier).refrescar();
      }

      if (mounted) {
        _limpiarFormulario();
        setState(() => _exito = sincronizado
            ? 'Entrega registrada exitosamente.'
            : '📴 Sin conexión: la entrega se guardó localmente y se sincronizará automáticamente.');
      }
    } catch (e) {
      setState(() => _error = 'Error al registrar la entrega: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final articulos = ref.watch(articulosGeneralProvider).valueOrNull ?? [];
    final articulosConStock = articulos.where((a) => a.stockDisponible > 0).toList();
    final busquedaArticulo = _busquedaArticuloController.text.trim().toLowerCase();
    final articulosFiltrados = (busquedaArticulo.isEmpty
            ? articulosConStock
            : articulosConStock.where((a) =>
                a.descripcion.toLowerCase().contains(busquedaArticulo) ||
                a.codigoInterno.toLowerCase().contains(busquedaArticulo)))
        .take(15)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🧾 Nueva Entrega de Dotación',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          _seccion(
            titulo: '👤 Receptor',
            accion: TextButton(
              onPressed: () => setState(() {
                _entradaManual = !_entradaManual;
                _empleadoSeleccionado = null;
              }),
              child: Text(_entradaManual ? 'Buscar en RRHH' : 'Ingresar manualmente'),
            ),
            child: _entradaManual ? _formularioManual() : _buscadorEmpleado(),
          ),
          const SizedBox(height: 20),
          _seccion(
            titulo: '📦 Artículos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (articulos.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(6),
                      border: const Border(left: BorderSide(color: AppColors.warning, width: 4)),
                    ),
                    child: const Text(
                      '⚠️ Todavía no hay artículos registrados en el Inventario General. '
                      'Un Admin debe agregarlos primero en la pestaña "Artículos".',
                    ),
                  )
                else ...[
                  TextField(
                    controller: _busquedaArticuloController,
                    decoration:
                        const InputDecoration(hintText: 'Buscar artículo por código o nombre...'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  if (articulosFiltrados.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        busquedaArticulo.isEmpty
                            ? 'No hay artículos con stock disponible.'
                            : 'No se encontraron artículos con "$busquedaArticulo".',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...articulosFiltrados.map((a) => ListTile(
                          dense: true,
                          title: Text(a.descripcion),
                          subtitle: Text('${a.codigoInterno} · Disponible: ${a.stockDisponible}'),
                          trailing: const Icon(Icons.add_circle, color: AppColors.primary),
                          onTap: () {
                            _agregarArticulo(a);
                            _busquedaArticuloController.clear();
                            setState(() {});
                          },
                        )),
                ],
                const SizedBox(height: 16),
                if (_carrito.isEmpty)
                  const Text('Aún no hay artículos en el carrito.',
                      style: TextStyle(color: AppColors.textSecondary))
                else
                  ..._carrito.map((item) => _ItemCarritoWidget(
                        item: item,
                        onRemove: () => setState(() => _carrito.remove(item)),
                        onChanged: () => setState(() {}),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _seccion(
            titulo: '✍️ Firma de Recepción',
            child: FirmaWidget(controller: _firmaController),
          ),
          const SizedBox(height: 16),
          _label('Observaciones:'),
          const SizedBox(height: 6),
          TextField(
            controller: _observacionesController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Observaciones adicionales (opcional)'),
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
                    : const Text('💾 Guardar Entrega'),
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

  Widget _buscadorEmpleado() {
    if (_empleadoSeleccionado != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F8F5),
          borderRadius: BorderRadius.circular(6),
          border: const Border(left: BorderSide(color: AppColors.success, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_empleadoSeleccionado!.nombreCompleto,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                      'CI: ${_empleadoSeleccionado!.cedula}'
                      '${_empleadoSeleccionado!.cargo != null ? ' · ${_empleadoSeleccionado!.cargo}' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _empleadoSeleccionado = null),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _busquedaEmpleadoController,
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o cédula...',
            suffixIcon: _buscandoEmpleado
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
          onChanged: _buscarEmpleado,
        ),
        if (_resultadosEmpleado.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _resultadosEmpleado.length,
              itemBuilder: (context, i) {
                final e = _resultadosEmpleado[i];
                return ListTile(
                  dense: true,
                  title: Text(e.nombreCompleto),
                  subtitle: Text('CI: ${e.cedula}${e.cargo != null ? ' · ${e.cargo}' : ''}'),
                  onTap: () => setState(() {
                    _empleadoSeleccionado = e;
                    _resultadosEmpleado = [];
                    _busquedaEmpleadoController.clear();
                  }),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _formularioManual() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Nombre completo:'),
        const SizedBox(height: 6),
        TextField(controller: _nombreManualController, decoration: const InputDecoration()),
        const SizedBox(height: 12),
        _label('Cédula:'),
        const SizedBox(height: 6),
        TextField(controller: _cedulaManualController, decoration: const InputDecoration()),
        const SizedBox(height: 12),
        _label('Cargo:'),
        const SizedBox(height: 6),
        TextField(controller: _cargoManualController, decoration: const InputDecoration()),
        const SizedBox(height: 12),
        _label('Base/ubicación:'),
        const SizedBox(height: 6),
        TextField(controller: _baseManualController, decoration: const InputDecoration()),
      ],
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

class _ItemCarritoWidget extends StatelessWidget {
  final ItemCarrito item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemCarritoWidget({required this.item, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.articulo.descripcion,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onRemove,
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: '${item.cantidad}',
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    item.cantidad = num.tryParse(v) ?? item.cantidad;
                    onChanged();
                  },
                ),
              ),
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: item.talla,
                  decoration: const InputDecoration(labelText: 'Talla'),
                  onChanged: (v) {
                    item.talla = v;
                    onChanged();
                  },
                ),
              ),
              if (item.articulo.esDescontable) ...[
                const Text('¿Descontar?', style: TextStyle(fontSize: 13)),
                ToggleButtons(
                  isSelected: [item.aplicaDescuento, !item.aplicaDescuento],
                  onPressed: (i) {
                    item.aplicaDescuento = i == 0;
                    onChanged();
                  },
                  borderRadius: BorderRadius.circular(6),
                  constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
                  children: const [Text('SÍ'), Text('NO')],
                ),
                if (item.aplicaDescuento)
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      initialValue: '${item.valorDescuentoPersonalizado}',
                      decoration: const InputDecoration(labelText: 'Valor \$'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        item.valorDescuentoPersonalizado = num.tryParse(v) ?? item.valorDescuentoPersonalizado;
                        onChanged();
                      },
                    ),
                  ),
              ],
            ],
          ),
          if (item.aplicaDescuento && item.articulo.esDescontable)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Subtotal descuento: \$${item.subtotalDescuento.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}
