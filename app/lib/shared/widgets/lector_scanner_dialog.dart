import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_theme.dart';

/// Pantalla de escaneo reutilizable: se abre con `Navigator.push` y devuelve
/// el código leído (`pop(context, codigo)`), o `null` si el usuario vuelve
/// atrás sin escanear nada. Compartida entre features (Taller de Motos,
/// Productos) — no es específica de ningún módulo.
///
/// Si en el mismo cuadro hay más de un código (p.ej. un QR pegado junto al
/// código de barras del producto), no elige uno al azar: pausa y pregunta
/// cuál guardar, mostrando el tipo de cada uno para que sea obvio cuál es
/// cuál.
class LectorScannerDialog extends StatefulWidget {
  final String titulo;
  const LectorScannerDialog({super.key, this.titulo = 'Escaneando Código'});

  @override
  State<LectorScannerDialog> createState() => _LectorScannerDialogState();
}

class _LectorScannerDialogState extends State<LectorScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _procesando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _tipoDe(Barcode b) => b.format == BarcodeFormat.qrCode ? 'Código QR' : 'Código de barras';

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_procesando) return;

    final vistos = <String>{};
    final codigos = <Barcode>[];
    for (final b in capture.barcodes) {
      final valor = b.rawValue;
      if (valor == null || valor.isEmpty || !vistos.add(valor)) continue;
      codigos.add(b);
    }
    if (codigos.isEmpty) return;

    if (codigos.length == 1) {
      if (mounted) Navigator.pop(context, codigos.first.rawValue);
      return;
    }

    setState(() => _procesando = true);
    await _controller.stop();
    if (!mounted) return;

    final elegido = await showModalBottomSheet<Barcode>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Se detectaron varios códigos a la vez', style: AppText.sectionTitle),
              const SizedBox(height: 4),
              const Text('Elige cuál quieres guardar.', style: AppText.bodySecondary),
              const SizedBox(height: 12),
              ...codigos.map((b) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        b.format == BarcodeFormat.qrCode ? Icons.qr_code_2 : Icons.barcode_reader,
                        color: AppColors.primary,
                      ),
                      title: Text(_tipoDe(b)),
                      subtitle: Text(b.rawValue ?? '', style: const TextStyle(fontFamily: 'monospace')),
                      onTap: () => Navigator.pop(context, b),
                    ),
                  )),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ninguno, seguir escaneando'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (elegido != null) {
      Navigator.pop(context, elegido.rawValue);
      return;
    }
    setState(() => _procesando = false);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Si hay un QR cerca del código de barras, tápalo con el dedo\n'
                  'o acércate hasta que solo se vea el código que quieres.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
