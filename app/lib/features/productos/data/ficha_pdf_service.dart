import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/producto.dart';

/// Genera la "ficha" descargable de un producto: la misma información que
/// se ve en la pantalla de detalle (foto, código, stock, entradas, salidas)
/// pero como PDF para guardar o enviar.
class FichaPdfService {
  static const _nombreEmpresa = 'INSEVIG CIA. LTDA.';

  Future<Uint8List> generarFicha(Producto p) async {
    pw.MemoryImage? foto;
    if (p.fotoUrl != null) {
      try {
        final respuesta = await http.get(Uri.parse(p.fotoUrl!));
        if (respuesta.statusCode == 200) foto = pw.MemoryImage(respuesta.bodyBytes);
      } catch (_) {
        // Sin foto no se rompe la ficha, solo se omite esa parte.
      }
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              color: PdfColors.blue900,
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: pw.Text(_nombreEmpresa,
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 100,
                  height: 100,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                  child: foto != null
                      ? pw.Image(foto, fit: pw.BoxFit.cover)
                      : pw.Center(
                          child: pw.Text('Sin foto', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(p.producto, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text('Código: ${p.cod}', style: const pw.TextStyle(fontSize: 10)),
                      if (p.categoria.isNotEmpty)
                        pw.Text('Categoría: ${p.categoria}', style: const pw.TextStyle(fontSize: 10)),
                      if (p.ubicacion.isNotEmpty)
                        pw.Text('Ubicación: ${p.ubicacion}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: ['Stock actual', 'Entradas', 'Salidas', 'Stock mínimo'],
              data: [
                ['${p.stock}', '${p.entrada}', '${p.salida}', '${p.stockMinimo}'],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              cellStyle: const pw.TextStyle(fontSize: 11),
              cellAlignment: pw.Alignment.center,
            ),
            pw.SizedBox(height: 20),
            pw.Text('Código de barras', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: p.cod, width: 200, height: 70),
            ),
            pw.SizedBox(height: 24),
            pw.Text('Generado: ${DateTime.now().toString().split('.').first}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> compartir(Uint8List bytes, String nombreArchivo) async {
    await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
  }
}
