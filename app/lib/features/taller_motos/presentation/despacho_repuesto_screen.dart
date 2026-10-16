import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/app_theme.dart';
import '../../../shared/widgets/visor_foto.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../productos/data/compresor_imagen.dart';
import 'taller_providers.dart';

class DespachoRepuestoScreen extends ConsumerStatefulWidget {
  final String ordenTrabajoId;
  final String vehiculoCod;
  final String? descripcionFallo;
  final String? fotoFallaUrl;
  final String? fotoRepuestoNuevoUrl;

  const DespachoRepuestoScreen({
    super.key,
    required this.ordenTrabajoId,
    required this.vehiculoCod,
    this.descripcionFallo,
    this.fotoFallaUrl,
    this.fotoRepuestoNuevoUrl,
  });

  @override
  ConsumerState<DespachoRepuestoScreen> createState() => _DespachoRepuestoScreenState();
}

class _DespachoRepuestoScreenState extends ConsumerState<DespachoRepuestoScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _procesando = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetectarCodigo(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || _procesando) return;
    final String? codigo = barcodes.first.rawValue;
    if (codigo == null) return;

    setState(() => _procesando = true);
    _scannerController.stop();

    try {
      final repo = ref.read(tallerRepositoryProvider);
      final repuesto = await repo.buscarRepuestoPorCodigo(codigo);
      if (!mounted) return;

      if (repuesto == null) {
        _mostrarError('Repuesto no encontrado con el código: $codigo');
        _reiniciarScanner();
        return;
      }
      if (repuesto.stockActual <= 0) {
        _mostrarError('El repuesto ${repuesto.nombre} NO tiene stock disponible.');
        _reiniciarScanner();
        return;
      }

      Uint8List? bytesFoto;
      if (repuesto.requierePiezaUsada) {
        bytesFoto = await _capturarFotoPiezaUsada();
        if (bytesFoto == null) {
          _mostrarError('PROCESO CANCELADO: Es obligatorio fotografiar la pieza usada.');
          _reiniciarScanner();
          return;
        }
      }

      final usuarioActual = ref.read(perfilActualProvider).valueOrNull;
      if (usuarioActual == null) {
        _mostrarError('No se pudo identificar al usuario actual.');
        _reiniciarScanner();
        return;
      }

      await repo.despacharRepuestoConPiezaUsada(
        ordenTrabajoId: widget.ordenTrabajoId,
        repuestoId: repuesto.id,
        vehiculoCod: widget.vehiculoCod,
        cantidad: 1,
        bodegueroId: usuarioActual.id,
        bytesFotoPiezaUsada: bytesFoto,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Repuesto ${repuesto.nombre} despachado exitosamente.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _mostrarError('Error al procesar: $e');
      _reiniciarScanner();
    }
  }

  Future<Uint8List?> _capturarFotoPiezaUsada() async {
    final ImagePicker picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (foto == null) return null;
    final bytesOriginales = await foto.readAsBytes();
    return compute(CompresorImagen.comprimir, bytesOriginales);
  }

  void _reiniciarScanner() {
    setState(() => _procesando = false);
    _scannerController.start();
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  bool get _tieneEvidencia =>
      (widget.descripcionFallo?.isNotEmpty ?? false) ||
      widget.fotoFallaUrl != null ||
      widget.fotoRepuestoNuevoUrl != null;

  Widget _miniaturaEvidencia(String? path, String titulo) {
    if (path == null) return const SizedBox.shrink();
    return FutureBuilder<String?>(
      future: ref.read(tallerRepositoryProvider).fotoUrlFirmada(path),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) return const SizedBox(width: 64, height: 64);
        return GestureDetector(
          onTap: () => VisorFotoScreen.abrir(context, url: url, titulo: titulo),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(url, width: 64, height: 64, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear Repuesto para OT')),
      body: Column(
        children: [
          if (_tieneEvidencia)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.surfaceAlt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reporte del mecánico:', style: AppText.label),
                  if (widget.descripcionFallo?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(widget.descripcionFallo!, style: AppText.bodySecondary),
                  ],
                  if (widget.fotoFallaUrl != null || widget.fotoRepuestoNuevoUrl != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _miniaturaEvidencia(widget.fotoFallaUrl, 'Repuesto/pieza dañada'),
                        _miniaturaEvidencia(widget.fotoRepuestoNuevoUrl, 'Repuesto nuevo'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(controller: _scannerController, onDetect: _onDetectarCodigo),
                if (_procesando) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
