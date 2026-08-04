import '../../../core/modulos.dart';
import '../../../core/supabase_config.dart';
import '../domain/resultado_carga.dart';

class CargaMasivaRepository {
  final ModuloTablas tablas;

  const CargaMasivaRepository(this.tablas);

  List<List<String>> _parsearCsv(String texto) {
    return texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => l.split(',').map((c) => c.trim()).toList())
        .toList();
  }

  DateTime? _parsearFecha(String texto) {
    final partes = texto.trim().split('/');
    if (partes.length != 3) return null;
    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    var anio = int.tryParse(partes[2]);
    if (dia == null || mes == null || anio == null) return null;
    if (anio < 100) anio += 2000;
    return DateTime(anio, mes, dia, 12);
  }

  Future<ResultadoCarga> cargarProductos(String csv) async {
    final filas = _parsearCsv(csv);
    final errores = <String>[];
    final validas = <Map<String, dynamic>>[];

    for (var i = 0; i < filas.length; i++) {
      final f = filas[i];
      if (f.length < 2 || f[0].isEmpty || f[1].isEmpty) {
        errores.add('Fila ${i + 1}: Código y producto son obligatorios.');
        continue;
      }
      validas.add({
        'cod': f[0],
        'producto': f[1],
        'categoria': f.length > 2 ? f[2] : '',
        'ubicacion': f.length > 3 ? f[3] : '',
        'stock_minimo': f.length > 4 ? (num.tryParse(f[4]) ?? 0) : 0,
      });
    }

    if (validas.isNotEmpty) {
      await supabase.from(tablas.productos).upsert(validas, onConflict: 'cod');
    }

    return ResultadoCarga(agregados: validas.length, actualizados: 0, errores: errores);
  }

  Future<ResultadoCarga> migrarEntradas({
    required String csv,
    required String usuarioId,
    required String usuarioNombre,
  }) async {
    final filas = _parsearCsv(csv);
    final errores = <String>[];
    final porFecha = <String, List<Map<String, dynamic>>>{};

    for (var i = 0; i < filas.length; i++) {
      final f = filas[i];
      if (f.length < 4) {
        errores.add('Fila ${i + 1}: se esperan 4 columnas (COD, PRODUCTO, FECHA, CANTIDAD).');
        continue;
      }
      final cod = f[0];
      final producto = f[1];
      final fecha = _parsearFecha(f[2]);
      final cantidad = num.tryParse(f[3]);

      if (cod.isEmpty || producto.isEmpty) {
        errores.add('Fila ${i + 1}: código y producto son obligatorios.');
        continue;
      }
      if (fecha == null) {
        errores.add('Fila ${i + 1}: fecha inválida "${f[2]}" (use dd/mm/yyyy).');
        continue;
      }
      if (cantidad == null || cantidad <= 0) {
        errores.add('Fila ${i + 1}: cantidad inválida "${f[3]}".');
        continue;
      }

      final clave = '${fecha.year}-${fecha.month}-${fecha.day}';
      porFecha.putIfAbsent(clave, () => []).add({
        'cod': cod,
        'producto': producto,
        'cantidad': cantidad,
        'fecha': fecha,
      });
    }

    var procesados = 0;
    for (final entry in porFecha.entries) {
      final items = entry.value;
      final transaccion = await supabase
          .from(tablas.transaccionesEntrada)
          .insert({
            'fecha_hora': (items.first['fecha'] as DateTime).toIso8601String(),
            'proveedor': 'Migración histórica',
            'observaciones': 'Datos migrados del sistema anterior',
            'usuario_id': usuarioId,
            'usuario_nombre': usuarioNombre,
          })
          .select()
          .single();

      final idTransaccion = transaccion['id_transaccion'] as String;

      await supabase.from(tablas.detalleEntradas).insert(items
          .map((i) => {
                'id_transaccion': idTransaccion,
                'cod': i['cod'],
                'producto': i['producto'],
                'cantidad': i['cantidad'],
              })
          .toList());

      procesados += items.length;
    }

    return ResultadoCarga(agregados: procesados, actualizados: 0, errores: errores);
  }

  Future<ResultadoCarga> migrarSalidas({
    required String csv,
    required String usuarioId,
    required String usuarioNombre,
  }) async {
    final filas = _parsearCsv(csv);
    final errores = <String>[];
    final porGrupo = <String, List<Map<String, dynamic>>>{};

    for (var i = 0; i < filas.length; i++) {
      final f = filas[i];
      if (f.length < 5) {
        errores.add(
            'Fila ${i + 1}: se esperan 5 columnas (COD, PRODUCTO, FECHA, CANTIDAD, ${tablas.etiquetaVehiculo.toUpperCase()}).');
        continue;
      }
      final cod = f[0];
      final producto = f[1];
      final fecha = _parsearFecha(f[2]);
      final cantidad = num.tryParse(f[3]);
      final bote = f[4];

      if (cod.isEmpty || producto.isEmpty) {
        errores.add('Fila ${i + 1}: código y producto son obligatorios.');
        continue;
      }
      if (fecha == null) {
        errores.add('Fila ${i + 1}: fecha inválida "${f[2]}" (use dd/mm/yyyy).');
        continue;
      }
      if (cantidad == null || cantidad <= 0) {
        errores.add('Fila ${i + 1}: cantidad inválida "${f[3]}".');
        continue;
      }

      final clave = '${fecha.year}-${fecha.month}-${fecha.day}_$bote';
      porGrupo.putIfAbsent(clave, () => []).add({
        'cod': cod,
        'producto': producto,
        'cantidad': cantidad,
        'fecha': fecha,
        'bote': bote,
      });
    }

    var procesados = 0;
    for (final entry in porGrupo.entries) {
      final items = entry.value;
      try {
        final transaccion = await supabase
            .from(tablas.transaccionesSalida)
            .insert({
              'fecha_hora': (items.first['fecha'] as DateTime).toIso8601String(),
              'bote': items.first['bote'],
              'a_quien_entrega': 'Migración histórica',
              'proposito': 'Salida migrada del sistema anterior',
              'usuario_id': usuarioId,
              'usuario_nombre': usuarioNombre,
            })
            .select()
            .single();

        final idTransaccion = transaccion['id_transaccion'] as String;

        await supabase.from(tablas.detalleSalidas).insert(items
            .map((i) => {
                  'id_transaccion': idTransaccion,
                  'cod': i['cod'],
                  'producto': i['producto'],
                  'cantidad': i['cantidad'],
                })
            .toList());

        procesados += items.length;
      } catch (e) {
        errores.add('Grupo ${entry.key}: $e');
      }
    }

    return ResultadoCarga(agregados: procesados, actualizados: 0, errores: errores);
  }
}
