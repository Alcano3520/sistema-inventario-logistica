import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../domain/descuento_nomina.dart';
import '../domain/resultado_exportacion.dart';

class ExportadorDescuentos {
  static final _formatoFecha = DateFormat('dd/MM/yyyy');

  Future<ResultadoExportacion> exportarExcel(List<DescuentoNomina> descuentos, {required String lote}) async {
    final libro = Excel.createExcel();
    final hoja = libro['Descuentos'];
    libro.setDefaultSheet('Descuentos');

    hoja.appendRow([
      TextCellValue('Cédula'),
      TextCellValue('Nombre'),
      TextCellValue('Cargo'),
      TextCellValue('Artículo'),
      TextCellValue('Valor'),
      TextCellValue('Fecha Entrega'),
      TextCellValue('Lote'),
    ].map((e) => e as CellValue).toList());

    for (final d in descuentos) {
      hoja.appendRow([
        TextCellValue(d.empleadoCedula),
        TextCellValue(d.empleadoNombre),
        TextCellValue(d.empleadoCargo ?? ''),
        TextCellValue(d.articuloDescripcion),
        DoubleCellValue(d.valorDescuento.toDouble()),
        TextCellValue(_formatoFecha.format(d.fechaEntrega)),
        TextCellValue(lote),
      ]);
    }

    final datos = libro.save();
    if (datos == null) throw Exception('No se pudo generar el archivo Excel.');

    final nombreArchivo = 'Descuentos_$lote.xlsx';
    final ruta = await FilePicker.saveFile(
      dialogTitle: 'Guardar como',
      fileName: nombreArchivo,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: Uint8List.fromList(datos),
    );
    if (ruta == null) return const ResultadoExportacion(cancelado: true);
    return ResultadoExportacion(ruta: ruta);
  }
}
