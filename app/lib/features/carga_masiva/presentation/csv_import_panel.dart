import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../shared/widgets/nota_banner.dart';
import '../domain/resultado_carga.dart';

class CsvImportPanel extends StatefulWidget {
  final String infoTitulo;
  final String infoTexto;
  final String hint;
  final String botonTexto;
  final Future<ResultadoCarga> Function(String csv) onProcesar;
  final String etiquetaExito;

  const CsvImportPanel({
    super.key,
    required this.infoTitulo,
    required this.infoTexto,
    required this.hint,
    required this.botonTexto,
    required this.onProcesar,
    required this.etiquetaExito,
  });

  @override
  State<CsvImportPanel> createState() => _CsvImportPanelState();
}

class _CsvImportPanelState extends State<CsvImportPanel> {
  final _controller = TextEditingController();
  bool _procesando = false;
  ResultadoCarga? _resultado;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _procesar() async {
    if (_controller.text.trim().isEmpty) {
      setState(() {
        _error = 'Pegue al menos una fila de datos antes de continuar.';
        _resultado = null;
      });
      return;
    }
    setState(() {
      _procesando = true;
      _resultado = null;
      _error = null;
    });
    try {
      final resultado = await widget.onProcesar(_controller.text);
      setState(() => _resultado = resultado);
    } catch (e) {
      setState(() => _error = 'Error al procesar: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: NotaBanner(
            tipo: TipoNota.info,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${widget.infoTitulo}\n', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: widget.infoTexto),
              ]),
              style: AppText.body,
            ),
          ),
        ),
        const Text('Datos (CSV):',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          maxLines: 10,
          decoration: InputDecoration(hintText: widget.hint),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton(
              onPressed: _procesando ? null : _procesar,
              child: _procesando
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.botonTexto),
            ),
            OutlinedButton(
              onPressed: _procesando
                  ? null
                  : () => setState(() {
                        _controller.clear();
                        _resultado = null;
                        _error = null;
                      }),
              child: const Text('Limpiar'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          NotaBanner.texto(_error!, tipo: TipoNota.error),
        ],
        if (_resultado != null) ...[
          const SizedBox(height: 16),
          NotaBanner.texto(
            '${widget.etiquetaExito}: ${_resultado!.agregados}'
            '${_resultado!.tieneErrores ? '\n${_resultado!.errores.length} fila(s) con errores' : ''}',
            tipo: TipoNota.exito,
          ),
          if (_resultado!.tieneErrores)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _resultado!.errores
                      .take(20)
                      .map((e) => Text('• $e', style: const TextStyle(fontSize: 12)))
                      .toList(),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
