import 'package:hive_flutter/hive_flutter.dart';

/// Cola de operaciones pendientes de sincronizar cuando el módulo General
/// trabaja sin conexión. Cada entrada guarda el tipo de operación y sus
/// parámetros en bruto (tal como los recibiría el repositorio), para poder
/// "reproducirla" contra Supabase apenas vuelva la conexión.
///
/// A diferencia del sistema original portado, el cálculo de stock nunca se
/// hace en el cliente: cada operación reproducida simplemente vuelve a
/// llamar al mismo método del repositorio, que inserta una fila en
/// `inv_general_movimientos` y deja que el trigger atómico en Postgres
/// aplique el stock — así se evita la condición de carrera de doble conteo.
class OfflineQueueGeneral {
  static const _boxName = 'general_operaciones_pendientes';
  static Box<Map>? _box;

  static Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  static Box<Map> get _caja {
    final box = _box;
    if (box == null) throw StateError('OfflineQueueGeneral.init() no fue llamado.');
    return box;
  }

  static Future<void> encolar(String tipo, Map<String, dynamic> datos) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _caja.put(id, {
      'id': id,
      'tipo': tipo,
      'datos': datos,
      'creado_en': DateTime.now().toIso8601String(),
      'intentos': 0,
    });
  }

  static List<Map<String, dynamic>> pendientes() {
    return _caja.values.map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => (a['creado_en'] as String).compareTo(b['creado_en'] as String));
  }

  static int get cantidadPendiente => _caja.length;

  static Future<void> marcarProcesada(String id) async {
    await _caja.delete(id);
  }

  static Future<void> incrementarIntento(String id) async {
    final actual = _caja.get(id);
    if (actual == null) return;
    final copia = Map<String, dynamic>.from(actual);
    copia['intentos'] = (copia['intentos'] as int? ?? 0) + 1;
    await _caja.put(id, copia);
  }
}
