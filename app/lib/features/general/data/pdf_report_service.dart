import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/articulo_general.dart';
import '../domain/movimiento_general.dart';

/// Genera reportes PDF con el membrete institucional de Insevig, usados por
/// el módulo General (Inventario/Movimientos/Ajustes).
class PdfReportService {
  static const _nombreEmpresa = 'INSEVIG CIA. LTDA.';
  static const _subtitulo = 'Sistema de Control de Inventario y Logística';
  static final _formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

  pw.Widget _encabezado(String titulo) {
    return pw.Container(
      color: PdfColors.blue900,
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_nombreEmpresa,
                  style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(_subtitulo, style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
                color: PdfColors.white, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(titulo,
                style: pw.TextStyle(
                    color: PdfColors.blue900, fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  pw.Widget _pie(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        '$_nombreEmpresa — Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  Future<Uint8List> generarReporteInventario(List<ArticuloGeneral> articulos) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (_) => _encabezado('INVENTARIO GENERAL'),
        footer: _pie,
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text('Generado: ${_formatoFecha.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Código', 'Descripción', 'Categoría', 'Disponible', 'Consig.', 'Descont.', 'Baja', 'Mínimo'],
            data: articulos
                .map((a) => [
                      a.codigoInterno,
                      a.descripcion,
                      a.categoria,
                      '${a.stockDisponible}',
                      '${a.stockConsignacion}',
                      '${a.stockDescontado}',
                      '${a.stockBaja}',
                      '${a.stockMinimo}',
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> generarReporteMovimientos(List<MovimientoGeneral> movimientos, {String? titulo}) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (_) => _encabezado(titulo ?? 'MOVIMIENTOS'),
        footer: _pie,
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text('Generado: ${_formatoFecha.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Fecha', 'Tipo', 'Artículo', 'Cant.', 'Empleado', 'Descuento'],
            data: movimientos
                .map((m) => [
                      _formatoFecha.format(m.fechaMovimiento.toLocal()),
                      m.tipoMovimiento,
                      m.articuloDescripcion ?? '',
                      '${m.cantidad}',
                      m.empleadoNombre ?? '',
                      m.aplicaDescuento ? '\$${m.valorDescuento}' : '-',
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> imprimir(Uint8List bytes, String nombreArchivo) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: nombreArchivo);
  }

  Future<void> compartir(Uint8List bytes, String nombreArchivo) async {
    await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
  }
}
