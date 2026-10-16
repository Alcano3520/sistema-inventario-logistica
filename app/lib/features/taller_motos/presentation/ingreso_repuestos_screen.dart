import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/lector_scanner_dialog.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../productos/data/compresor_imagen.dart';
import '../domain/repuesto.dart';
import 'taller_providers.dart';

class IngresoRepuestoScreen extends ConsumerStatefulWidget {
  const IngresoRepuestoScreen({super.key});

  @override
  ConsumerState<IngresoRepuestoScreen> createState() => _IngresoRepuestoScreenState();
}

class _IngresoRepuestoScreenState extends ConsumerState<IngresoRepuestoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _proveedorController = TextEditingController();

  Uint8List? _fotoComprobanteBytes;
  bool _cargando = false;

  @override
  void dispose() {
    _codigoController.dispose();
    _cantidadController.dispose();
    _proveedorController.dispose();
    super.dispose();
  }

  Future<void> _escanearCodigo() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LectorScannerDialog(titulo: 'Escanear código de repuesto')),
    );
    if (codigo != null && mounted) {
      setState(() => _codigoController.text = codigo);
    }
  }

  Future<void> _tomarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (foto == null) return;
    final bytesOriginales = await foto.readAsBytes();
    final comprimida = await compute(CompresorImagen.comprimir, bytesOriginales);
    setState(() => _fotoComprobanteBytes = comprimida);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingreso de Stock a Bodega')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _codigoController,
                decoration: InputDecoration(
                  labelText: 'Código de Barras',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _escanearCodigo,
                  ),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Escanee o ingrese un código' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad Ingresada'),
                validator: (val) {
                  final n = int.tryParse(val?.trim() ?? '');
                  if (n == null || n <= 0) return 'Ingrese una cantidad válida';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _proveedorController,
                decoration: const InputDecoration(labelText: 'Proveedor / Marca'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _tomarFoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Foto Factura / Pieza'),
                  ),
                  const SizedBox(width: 12),
                  if (_fotoComprobanteBytes != null) const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _guardarIngreso,
                  child: _cargando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('REGISTRAR ENTRADA DE STOCK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardarIngreso() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    try {
      final repo = ref.read(tallerRepositoryProvider);
      final codigo = _codigoController.text.trim();
      final repuesto = await repo.buscarRepuestoPorCodigo(codigo);

      if (repuesto == null) {
        final vincular = await _mostrarDialogoVincular();
        if (!mounted) return;
        if (vincular == true) {
          await _vincularYRegistrar(codigo);
        } else if (vincular == false) {
          await _crearRepuestoYRegistrar(codigo);
        }
      } else {
        await _registrarIngreso(repuesto);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<bool?> _mostrarDialogoVincular() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código Nuevo'),
        content: const Text(
            'Este código de barras no existe. ¿Es un producto nuevo o es un repuesto existente de otro proveedor?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CREAR NUEVO')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('VINCULAR A EXISTENTE')),
        ],
      ),
    );
  }

  Future<void> _crearRepuestoYRegistrar(String codigo) async {
    final nombreController = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo repuesto'),
        content: TextField(
          controller: nombreController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del repuesto'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nombreController.text.trim()),
            child: const Text('CREAR'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty || !mounted) return;

    final repo = ref.read(tallerRepositoryProvider);
    final repuesto = await repo.crearRepuesto(codigoBarras: codigo, nombre: nombre);
    await _registrarIngreso(repuesto);
  }

  Future<void> _vincularYRegistrar(String codigo) async {
    final repo = ref.read(tallerRepositoryProvider);
    final repuestos = await repo.obtenerRepuestos();
    if (!mounted) return;

    final elegido = await showDialog<Repuesto>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Vincular a repuesto existente'),
        children: repuestos.isEmpty
            ? [const Padding(padding: EdgeInsets.all(16), child: Text('No hay repuestos registrados aún.'))]
            : repuestos
                .map((r) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, r),
                      child: Text('${r.nombre} (${r.codigoBarras})'),
                    ))
                .toList(),
      ),
    );
    if (elegido == null || !mounted) return;

    await repo.vincularCodigoBarras(
      repuestoId: elegido.id,
      codigoBarras: codigo,
      proveedorNombre: _proveedorController.text.trim(),
    );
    await _registrarIngreso(elegido);
  }

  /// El vínculo del código escaneado a un repuesto (crear o vincular) ya se
  /// resolvió antes de llegar aquí, así que este método solo registra el
  /// movimiento de entrada.
  Future<void> _registrarIngreso(Repuesto repuesto) async {
    final usuario = ref.read(perfilActualProvider).valueOrNull;
    if (usuario == null) return;

    final repo = ref.read(tallerRepositoryProvider);
    await repo.registrarIngresoStock(
      repuestoId: repuesto.id,
      cantidad: int.parse(_cantidadController.text.trim()),
      bodegueroId: usuario.id,
      proveedor: _proveedorController.text.trim(),
      bytesFotoFactura: _fotoComprobanteBytes,
    );

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Stock actualizado exitosamente.')));
      Navigator.pop(context);
    }
  }
}
