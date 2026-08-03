import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/producto.dart';

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

  Future<Directory> _directorioDestino() async {
    try {
      final descargas = await getDownloadsDirectory();
      if (descargas != null) return descargas;
    } catch (_) {
      // Plataforma sin carpeta de descargas (ej. Android/iOS): usar documentos de la app.
    }
    return getApplicationDocumentsDirectory();
  }

  String _nombreArchivo(String extension) {
    final ahora = DateTime.now();
    String p2(int n) => n.toString().padLeft(2, '0');
    return 'Inventario_${ahora.year}${p2(ahora.month)}${p2(ahora.day)}_'
        '${p2(ahora.hour)}${p2(ahora.minute)}.$extension';
  }

  Future<String> exportarCsv(List<Producto> productos) async {
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

    final dir = await _directorioDestino();
    final file = File('${dir.path}/${_nombreArchivo('csv')}');
    // BOM UTF-8 para que Excel reconozca tildes/ñ correctamente.
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);
    return file.path;
  }

  String _csv(String valor) {
    if (valor.contains(',') || valor.contains('"') || valor.contains('\n')) {
      return '"${valor.replaceAll('"', '""')}"';
    }
    return valor;
  }

  Future<String> exportarExcel(List<Producto> productos) async {
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

    final bytes = libro.save();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo Excel.');
    }

    final dir = await _directorioDestino();
    final file = File('${dir.path}/${_nombreArchivo('xlsx')}');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String> exportarPdf(List<Producto> productos) async {
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
    final dir = await _directorioDestino();
    final file = File('${dir.path}/${_nombreArchivo('pdf')}');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
