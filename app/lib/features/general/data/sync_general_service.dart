import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'movimientos_general_repository.dart';
import 'offline_queue_general.dart';

/// Drena la cola offline del módulo General (ver [OfflineQueueGeneral])
/// apenas hay conexión, y además cada 5 minutos por si acaso. Cada entrada
/// se reproduce llamando al mismo método `*Cruda` del repositorio que usa
/// el camino en línea — el stock lo aplica el trigger de Postgres, nunca
/// esta clase, así que no hay riesgo de doble conteo entre dispositivos.
class SyncGeneralService {
  SyncGeneralService._();
  static final SyncGeneralService instance = SyncGeneralService._();

  final _repo = MovimientosGeneralRepository();
  StreamSubscription<List<ConnectivityResult>>? _conexionSub;
  Timer? _timer;
  bool _sincronizando = false;

  final _estadoController = StreamController<int>.broadcast();

  /// Emite la cantidad de operaciones pendientes cada vez que cambia.
  Stream<int> get pendientesStream => _estadoController.stream;

  int get pendientes => OfflineQueueGeneral.cantidadPendiente;

  void iniciar() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => sincronizar());

    _conexionSub?.cancel();
    _conexionSub = Connectivity().onConnectivityChanged.listen((resultado) {
      if (!resultado.contains(ConnectivityResult.none) && OfflineQueueGeneral.cantidadPendiente > 0) {
        sincronizar();
      }
    });
  }

  void detener() {
    _timer?.cancel();
    _conexionSub?.cancel();
  }

  void dispose() {
    detener();
    _estadoController.close();
  }

  Future<void> sincronizar() async {
    if (_sincronizando) return;
    final resultado = await Connectivity().checkConnectivity();
    if (resultado.contains(ConnectivityResult.none)) return;

    _sincronizando = true;
    try {
      for (final operacion in OfflineQueueGeneral.pendientes()) {
        final id = operacion['id'] as String;
        final tipo = operacion['tipo'] as String;
        final datos = Map<String, dynamic>.from(operacion['datos'] as Map);
        try {
          if (tipo == 'entrega') {
            await _repo.registrarEntregaCruda(datos);
          } else if (tipo == 'devolucion') {
            await _repo.registrarDevolucionCruda(datos);
          }
          await OfflineQueueGeneral.marcarProcesada(id);
        } catch (_) {
          await OfflineQueueGeneral.incrementarIntento(id);
        }
      }
    } finally {
      _sincronizando = false;
      _estadoController.add(OfflineQueueGeneral.cantidadPendiente);
    }
  }
}
