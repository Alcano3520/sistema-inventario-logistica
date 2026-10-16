import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Genera el acta de baja de chatarra (piezas retiradas y dadas de baja
/// formalmente) con la firma del supervisor, con el mismo membrete
/// institucional que el resto de reportes PDF de la app.
class ActaBajaPdfService {
  static Future<Uint8List> generarPdfActa({
    required String codigoActa,
    required String nombreSupervisor,
    required String motivo,
    required List<Map<String, dynamic>> piezasBaja,
    required Uint8List bytesFirmaSupervisor,
  }) async {
    final pdf = pw.Document();
    final imageFirma = pw.MemoryImage(bytesFirmaSupervisor);

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
                    pw.Text('ACTA DE BAJA DE CHATARRA',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text('Código de Acta: $codigoActa'),
                pw.Text('Fecha: ${DateTime.now().toString().split(' ')[0]}'),
                pw.Text('Supervisor: $nombreSupervisor'),
                pw.SizedBox(height: 10),
                pw.Text('Motivo: $motivo', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 15),
                pw.Text('Repuestos Chatarrizados:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: ['Repuesto', 'Cantidad', 'Estado', 'Origen OT'],
                  data: piezasBaja
                      .map((p) => [
                            p['nombre_repuesto'] ?? 'Desconocido',
                            p['cantidad'].toString(),
                            p['estado_pieza'] ?? 'DAÑADO',
                            p['codigo_ot'] ?? 'N/A',
                          ])
                      .toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Column(
                      children: [
                        pw.Image(imageFirma, width: 150, height: 60),
                        pw.Container(width: 200, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 4),
                        pw.Text(nombreSupervisor, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Firma de Auditoría / Supervisión'),
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
    await Printing.sharePdf(bytes: bytesPdf, filename: '$nombreArchivo.pdf');
  }
}
