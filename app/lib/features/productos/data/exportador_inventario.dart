import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/producto.dart';

/// Resultado de una exportación: la ruta elegida por el usuario, o null si
/// canceló el diálogo de "Guardar como".
class ResultadoExportacion {
  final String? ruta;
  final bool cancelado;

  const ResultadoExportacion({this.ruta, this.cancelado = false});
}

class ExportadorInventario {
  static const _encabezados = [
    'Código',
    'Producto',
    'Entradas',
    'Salidas',
    'Stock',
    'Categoría',
    'Ubicación',
    'Stock Min.'
  ];

  String _nombreArchivo(String extension) {
    final ahora = DateTime.now();
    String p2(int n) => n.toString().padLeft(2, '0');
    return 'Inventario_${ahora.year}${p2(ahora.month)}${p2(ahora.day)}_'
        '${p2(ahora.hour)}${p2(ahora.minute)}.$extension';
  }

  /// Abre el diálogo nativo "Guardar como" para que el usuario elija dónde
  /// guardar el archivo. Devuelve la ruta elegida, o null si canceló.
  Future<ResultadoExportacion> _guardar({
    required Uint8List bytes,
    required String nombreArchivo,
    required String extension,
  }) async {
    final ruta = await FilePicker.saveFile(
      dialogTitle: 'Guardar como',
      fileName: nombreArchivo,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );

    if (ruta == null) {
      return const ResultadoExportacion(cancelado: true);
    }
    return ResultadoExportacion(ruta: ruta);
  }

  Future<ResultadoExportacion> exportarCsv(List<Producto> productos) async {
    final buffer = StringBuffer();
    buffer.writeln(_encabezados.join(','));
    for (final p in productos) {
      buffer.writeln([
        _csv(p.cod),
        _csv(p.producto),
        p.entrada,
        p.salida,
        p.stock,
        _csv(p.categoria),
        _csv(p.ubicacion),
        p.stockMinimo,
      ].join(','));
    }

    // BOM UTF-8 para que Excel reconozca tildes/ñ correctamente.
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);
    return _guardar(bytes: bytes, nombreArchivo: _nombreArchivo('csv'), extension: 'csv');
  }

  String _csv(String valor) {
    if (valor.contains(',') || valor.contains('"') || valor.contains('\n')) {
      return '"${valor.replaceAll('"', '""')}"';
    }
    return valor;
  }

  Future<ResultadoExportacion> exportarExcel(List<Producto> productos) async {
    final libro = Excel.createExcel();
    final hoja = libro['Inventario'];
    libro.setDefaultSheet('Inventario');

    hoja.appendRow(_encabezados.map((e) => TextCellValue(e)).toList());
    for (final p in productos) {
      hoja.appendRow([
        TextCellValue(p.cod),
        TextCellValue(p.producto),
        DoubleCellValue(p.entrada.toDouble()),
        DoubleCellValue(p.salida.toDouble()),
        DoubleCellValue(p.stock.toDouble()),
        TextCellValue(p.categoria),
        TextCellValue(p.ubicacion),
        DoubleCellValue(p.stockMinimo.toDouble()),
      ]);
    }

    final datos = libro.save();
    if (datos == null) {
      throw Exception('No se pudo generar el archivo Excel.');
    }

    return _guardar(
      bytes: Uint8List.fromList(datos),
      nombreArchivo: _nombreArchivo('xlsx'),
      extension: 'xlsx',
    );
  }

  Future<ResultadoExportacion> exportarPdf(List<Producto> productos) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Header(level: 0, text: 'Inventario Actual'),
          pw.TableHelper.fromTextArray(
            headers: _encabezados,
            data: productos
                .map((p) => [
                      p.cod,
                      p.producto,
                      '${p.entrada}',
                      '${p.salida}',
                      '${p.stock}',
                      p.categoria,
                      p.ubicacion,
                      '${p.stockMinimo}',
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    return _guardar(bytes: bytes, nombreArchivo: _nombreArchivo('pdf'), extension: 'pdf');
  }
}
