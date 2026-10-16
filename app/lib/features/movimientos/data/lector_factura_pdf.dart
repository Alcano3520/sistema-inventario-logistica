import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../domain/factura_extraida.dart';
import 'analizador_texto_factura.dart';

/// Lee el PDF de una factura (RIDE de factura electrónica del SRI) y, con
/// [AnalizadorTextoFactura], detecta por heurística de texto los campos más
/// comunes para pre-llenar el formulario de Entrada.
class LectorFacturaPdf {
  static Future<FacturaExtraida> extraer(Uint8List bytes) async {
    final doc = await PdfDocument.openData(bytes, sourceName: 'factura_entrada');
    try {
      final buffer = StringBuffer();
      for (final pagina in doc.pages) {
        final texto = await pagina.loadStructuredText();
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(texto.fullText);
      }
      return AnalizadorTextoFactura.analizar(buffer.toString());
    } finally {
      await doc.dispose();
    }
  }
}
