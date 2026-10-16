import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Genera el acta de constancia cuando se corrige una Entrada/factura ya
/// registrada: deja huella de qué cambió, quién lo autorizó y por qué, con
/// líneas en blanco para que firmen tanto quien tuvo el error original
/// como quien autorizó la corrección — se imprime y se firma a mano, no
/// lleva una firma digital ya capturada como las demás actas de la app.
class ActaCorreccionPdfService {
  static Future<Uint8List> generarPdfActa({
    required String idTransaccion,
    required String usuarioOriginal,
    required String usuarioCorrector,
    required DateTime fechaCorreccion,
    required String observacionCorreccion,
    required List<(String campo, String antes, String despues)> cambios,
  }) async {
    final pdf = pw.Document();
    final fechaStr = '${fechaCorreccion.day.toString().padLeft(2, '0')}/'
        '${fechaCorreccion.month.toString().padLeft(2, '0')}/${fechaCorreccion.year}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('INSEVIG CÍA. LTDA.',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('ACTA DE CORRECCIÓN DE FACTURA',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text('Entrada/Factura N°: $idTransaccion'),
                pw.Text('Fecha de la corrección: $fechaStr'),
                pw.Text('Registrado originalmente por: $usuarioOriginal'),
                pw.Text('Corrección autorizada por: $usuarioCorrector'),
                pw.SizedBox(height: 15),
                pw.Text('Cambios realizados:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: ['Campo', 'Valor anterior', 'Valor corregido'],
                  data: cambios.map((c) => [c.$1, c.$2, c.$3]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 15),
                pw.Text('Observación de la corrección:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(observacionCorreccion),
                pw.Spacer(),
                pw.Text(
                  'Con mi firma reconozco el error en el registro original y la corrección aquí descrita.',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 200, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 4),
                        pw.Text(usuarioOriginal, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Firma de quien registró el error', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 200, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 4),
                        pw.Text(usuarioCorrector, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Firma de quien autorizó la corrección', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> imprimirOCompartirPdf(Uint8List bytesPdf, String nombreArchivo) async {
    await Printing.layoutPdf(onLayout: (_) async => bytesPdf, name: nombreArchivo);
  }
}
