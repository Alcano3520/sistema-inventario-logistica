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

  /// Carga masiva de entradas de stock históricas: CODIGO, CANTIDAD, MOTIVO.
  /// Cada fila válida genera un movimiento ENTRADA (el trigger de Postgres
  /// aplica el stock de forma atómica, igual que una entrada manual).
  Future<ResultadoCarga> cargarEntradas({
    required String csv,
    required String usuarioId,
    required String usuarioNombre,
  }) async {
    final filas = _parsearCsv(csv);
    final errores = <String>[];
    var procesados = 0;

    for (var i = 0; i < filas.length; i++) {
      final f = filas[i];
      if (f.length < 2 || f[0].isEmpty) {
        errores.add('Fila ${i + 1}: código y cantidad son obligatorios.');
        continue;
      }
      final codigo = f[0];
      final cantidad = num.tryParse(f[1]);
      final motivo = f.length > 2 ? f[2] : 'Carga masiva';

      if (cantidad == null || cantidad <= 0) {
        errores.add('Fila ${i + 1}: cantidad inválida "${f.length > 1 ? f[1] : ''}".');
        continue;
      }

      try {
        final articulo = await supabase
            .from('inv_general_articulos')
            .select('id, stock_disponible')
            .eq('codigo_interno', codigo)
            .maybeSingle();

        if (articulo == null) {
          errores.add('Fila ${i + 1}: no existe un artículo con código "$codigo".');
          continue;
        }

        await supabase.from('inv_general_movimientos').insert({
          'articulo_id': articulo['id'],
          'tipo_movimiento': 'ENTRADA',
          'cantidad': cantidad,
          'stock_anterior': articulo['stock_disponible'],
          'stock_nuevo': (articulo['stock_disponible'] as num) + cantidad,
          'usuario_id': usuarioId,
          'usuario_nombre': usuarioNombre,
          'motivo': motivo,
          'observaciones': 'Carga masiva de entradas',
        });
        procesados++;
      } catch (e) {
        errores.add('Fila ${i + 1}: $e');
      }
    }

    return ResultadoCarga(agregados: procesados, actualizados: 0, errores: errores);
  }
}
