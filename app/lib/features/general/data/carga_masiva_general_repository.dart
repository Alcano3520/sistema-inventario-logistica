import '../../../core/supabase_config.dart';
import '../../carga_masiva/domain/resultado_carga.dart';

class CargaMasivaGeneralRepository {
  List<List<String>> _parsearCsv(String texto) {
    return texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => l.split(',').map((c) => c.trim()).toList())
        .toList();
  }

  Future<ResultadoCarga> cargarArticulos(String csv) async {
    final filas = _parsearCsv(csv);
    final errores = <String>[];
    final validas = <Map<String, dynamic>>[];

    for (var i = 0; i < filas.length; i++) {
      final f = filas[i];
      if (f.length < 2 || f[0].isEmpty || f[1].isEmpty) {
        errores.add('Fila ${i + 1}: código y descripción son obligatorios.');
        continue;
      }
      validas.add({
        'codigo_interno': f[0],
        'descripcion': f[1],
        'categoria': f.length > 2 ? f[2] : '',
        'valor_unitario': f.length > 3 ? (num.tryParse(f[3]) ?? 0) : 0,
        'stock_minimo': f.length > 4 ? (num.tryParse(f[4]) ?? 1) : 1,
      });
    }

    if (validas.isNotEmpty) {
      await supabase.from('inv_general_articulos').upsert(validas, onConflict: 'codigo_interno');
    }

    return ResultadoCarga(agregados: validas.length, actualizados: 0, errores: errores);
  }
}
