import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../shared/widgets/lector_scanner_dialog.dart';
import '../../../shared/widgets/nota_banner.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/articulo_general.dart';
import '../domain/empleado_externo.dart';
import '../domain/item_carrito.dart';
import 'general_providers.dart';

class DevolucionGeneralScreen extends ConsumerStatefulWidget {
  const DevolucionGeneralScreen({super.key});

  @override
  ConsumerState<DevolucionGeneralScreen> createState() => _DevolucionGeneralScreenState();
}

class _DevolucionGeneralScreenState extends ConsumerState<DevolucionGeneralScreen> {
  final _busquedaEmpleadoController = TextEditingController();
  final _nombreManualController = TextEditingController();
  final _cedulaManualController = TextEditingController();
  final _busquedaArticuloController = TextEditingController();
  final _observacionesController = TextEditingController();

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
    _busquedaArticuloController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _agregarAlCarrito(ArticuloGeneral a) {
    setState(() {
      final existente = _carrito.where((i) => i.articulo.id == a.id).firstOrNull;
      if (existente != null) {
        existente.cantidad += 1;
      } else {
        _carrito.add(ItemCarrito(articulo: a));
      }
    });
  }

  /// El código de barras es opcional en Dotación Empleados (son prendas de
  /// trabajadores, no todas vienen con uno), así que si el artículo
  /// escaneado no tiene código registrado simplemente no se encuentra.
  Future<void> _escanearArticulo() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LectorScannerDialog(titulo: 'Escanear código de barras o QR')),
    );
    if (codigo == null || !mounted) return;

    final articulos = ref.read(articulosGeneralProvider).valueOrNull ?? [];
    final encontrado = articulos
        .where((a) => a.codigoBarras == codigo.trim() || a.codigoInterno.toLowerCase() == codigo.trim().toLowerCase())
        .firstOrNull;

    if (encontrado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se encontró ningún artículo con el código "$codigo".')),
      );
      return;
    }
    _agregarAlCarrito(encontrado);
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

  void _limpiarFormulario() {
    setState(() {
      _empleadoSeleccionado = null;
      _entradaManual = false;
      _busquedaEmpleadoController.clear();
      _nombreManualController.clear();
      _cedulaManualController.clear();
      _resultadosEmpleado = [];
      _carrito.clear();
      _observacionesController.clear();
      _error = null;
      _exito = null;
    });
  }

  Future<void> _confirmarLimpiarItems() async {
    if (_carrito.isEmpty) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Limpiar artículos?'),
        content: const Text('Se perderán los artículos agregados a la devolución.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Limpiar')),
        ],
      ),
    );
    if (confirmar == true) setState(() => _carrito.clear());
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

    final perfil = ref.read(perfilActualProvider).valueOrNull;
    if (perfil == null) return;

    setState(() => _guardando = true);
    try {
      final sincronizado = await ref.read(movimientosGeneralRepositoryProvider).registrarDevolucion(
            items: _carrito,
            empleado: _empleadoSeleccionado,
            nombreManual: _nombreManualController.text,
            cedulaManual: _cedulaManualController.text,
            usuarioId: perfil.id,
            usuarioNombre: perfil.nombre,
            observaciones: _observacionesController.text,
          );

      if (sincronizado) {
        await ref.read(articulosGeneralProvider.notifier).refrescar();
      }

      if (mounted) {
        _limpiarFormulario();
        setState(() => _exito = sincronizado
            ? 'Devolución registrada exitosamente.'
            : 'Sin conexión: la devolución se guardó localmente y se sincronizará automáticamente.');
      }
    } catch (e) {
      setState(() => _error = 'Error al registrar la devolución: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final articulos = ref.watch(articulosGeneralProvider).valueOrNull ?? [];
    final busquedaArticulo = _busquedaArticuloController.text.trim().toLowerCase();
    final articulosFiltrados = (busquedaArticulo.isEmpty
            ? articulos
            : articulos.where((a) =>
                a.descripcion.toLowerCase().contains(busquedaArticulo) ||
                a.codigoInterno.toLowerCase().contains(busquedaArticulo)))
        .take(15)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registro de Devolución', style: AppText.screenTitle),
          const SizedBox(height: 20),
          _seccion(
            titulo: 'Quien devuelve',
            accion: TextButton(
              onPressed: () => setState(() {
                _entradaManual = !_entradaManual;
                _empleadoSeleccionado = null;
              }),
              child: Text(_entradaManual ? 'Buscar en RRHH' : 'Ingresar manualmente'),
            ),
            child: _entradaManual
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nombreManualController,
                        decoration: const InputDecoration(labelText: 'Nombre completo'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cedulaManualController,
                        decoration: const InputDecoration(labelText: 'Cédula'),
                      ),
                    ],
                  )
                : _buscadorEmpleado(),
          ),
          const SizedBox(height: 20),
          _seccion(
            titulo: 'Artículos devueltos',
            accion: _carrito.isNotEmpty
                ? TextButton(onPressed: _confirmarLimpiarItems, child: const Text('Limpiar'))
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (articulos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NotaBanner.texto(
                      'Todavía no hay artículos registrados en Dotación Empleados. '
                      'Un Admin debe agregarlos primero en la pestaña "Artículos".',
                      tipo: TipoNota.advertencia,
                    ),
                  )
                else ...[
                  TextField(
                    controller: _busquedaArticuloController,
                    decoration: InputDecoration(
                      hintText: 'Buscar artículo por código o nombre...',
                      suffixIcon: IconButton(
                        tooltip: 'Escanear código de barras o QR',
                        icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                        onPressed: _escanearArticulo,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  if (articulosFiltrados.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('No se encontraron artículos con "$busquedaArticulo".',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    )
                  else
                    ...articulosFiltrados.map((a) => ListTile(
                          dense: true,
                          title: Text(a.descripcion),
                          subtitle: Text(a.codigoInterno),
                          trailing: const Icon(Icons.add_circle, color: AppColors.primary),
                          onTap: () {
                            _agregarAlCarrito(a);
                            _busquedaArticuloController.clear();
                          },
                        )),
                ],
                const SizedBox(height: 16),
                if (_carrito.isEmpty)
                  const Text('Aún no hay artículos agregados.',
                      style: TextStyle(color: AppColors.textSecondary))
                else
                  ..._carrito.map((item) => _ItemDevolucion(
                        item: item,
                        onRemove: () => setState(() => _carrito.remove(item)),
                        onChanged: () => setState(() {}),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _observacionesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Observaciones (opcional)'),
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
                    : const Text('Guardar Devolución'),
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

  Widget _buscadorEmpleado() {
    if (_empleadoSeleccionado != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                  '${_empleadoSeleccionado!.nombreCompleto} · CI: ${_empleadoSeleccionado!.cedula}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
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
                        height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
          ),
          onChanged: _buscarEmpleado,
        ),
        if (_resultadosEmpleado.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
                border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _resultadosEmpleado.length,
              itemBuilder: (context, i) {
                final e = _resultadosEmpleado[i];
                return ListTile(
                  dense: true,
                  title: Text(e.nombreCompleto),
                  subtitle: Text('CI: ${e.cedula}'),
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

class _ItemDevolucion extends StatelessWidget {
  final ItemCarrito item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemDevolucion({required this.item, required this.onRemove, required this.onChanged});

  static const _condiciones = {
    'BUEN_ESTADO': 'Buen estado',
    'USO_PARCIAL': 'Uso parcial',
    'DESGASTADO': 'Desgastado',
    'DANADO': 'Dañado',
    'INUTILIZABLE': 'Inutilizable',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.articulo.descripcion, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: item.condicion,
                  decoration: const InputDecoration(labelText: 'Condición'),
                  items: _condiciones.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    item.condicion = v ?? item.condicion;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
