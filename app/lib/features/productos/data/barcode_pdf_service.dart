import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Genera una etiqueta imprimible con el código de barras de un producto —
/// para productos que no tienen una etiqueta física pegada todavía, o para
/// reimprimir una que se dañó/perdió.
class BarcodePdfService {
  Future<Uint8List> generarEtiqueta({required String cod, required String nombre}) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 50 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(8),
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                nombre,
                textAlign: pw.TextAlign.center,
                maxLines: 2,
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 6),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: cod,
                width: 220,
                height: 70,
                drawText: true,
                textStyle: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  Future<void> imprimir(Uint8List bytes, String nombreArchivo) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: nombreArchivo);
  }
}
