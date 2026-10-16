import 'dart:typed_data';

import '../../../core/modulos.dart';
import '../../../core/supabase_config.dart';
import '../domain/orden_trabajo.dart';
import '../domain/repuesto.dart';
import '../domain/repuesto_retirado.dart';

/// Repositorio del taller (repuestos, órdenes de trabajo, despacho y
/// custodia de piezas retiradas). Compartido por Barcos y Motos: cada
/// instancia trabaja contra el set de tablas de [tablas], igual que
/// `MovimientosRepository`. El stock de repuestos nunca se calcula aquí:
/// los triggers de Postgres lo aplican al insertar en `otConsumo` /
/// `repuestosIngresos`, igual que el resto de la app.
class TallerRepository {
  final ModuloTablas tablas;

  const TallerRepository(this.tablas);

  String _rutaFirma(String subcarpeta, String nombreArchivo) {
    final prefijo = tablas.carpetaFirmas.isEmpty ? '' : '${tablas.carpetaFirmas}/';
    return '$prefijo$subcarpeta/$nombreArchivo.png';
  }

  Future<List<OrdenTrabajo>> obtenerOrdenesActivas() async {
    final res = await supabase
        .from(tablas.ordenesTrabajo)
        .select('*, vehiculo_info:${tablas.productos}(producto), inv_perfiles(nombre)')
        .order('created_at', ascending: false);
    return (res as List).map((e) => OrdenTrabajo.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// [bytesFotoFalla]/[bytesFotoRepuestoNuevo] son la evidencia que deja el
  /// propio mecánico al reportar la falla (antes de que bodega despache
  /// nada) — distinta de la foto de la pieza retirada que toma el bodeguero
  /// al momento del despacho.
  Future<void> crearOrdenTrabajo({
    required String vehiculoCod,
    required String mecanicoId,
    required int kilometrajeActual,
    required String descripcionFallo,
    Uint8List? bytesFotoFalla,
    Uint8List? bytesFotoRepuestoNuevo,
  }) async {
    final codigoOt = 'OT-${DateTime.now().millisecondsSinceEpoch}';

    Future<String?> subir(Uint8List? bytes, String carpeta) async {
      if (bytes == null) return null;
      final path = _rutaFirma(carpeta, codigoOt);
      await supabase.storage.from('inv-firmas').uploadBinary(path, bytes);
      return path;
    }

    final fotoFallaUrl = await subir(bytesFotoFalla, 'ot_falla');
    final fotoRepuestoNuevoUrl = await subir(bytesFotoRepuestoNuevo, 'ot_repuesto_nuevo');

    await supabase.from(tablas.ordenesTrabajo).insert({
      'codigo_ot': codigoOt,
      'vehiculo_cod': vehiculoCod,
      'mecanico_id': mecanicoId,
      'kilometraje_actual': kilometrajeActual,
      'descripcion_fallo': descripcionFallo,
      'foto_falla_url': fotoFallaUrl,
      'foto_repuesto_nuevo_url': fotoRepuestoNuevoUrl,
    });
  }

  /// Corrección de una OT ya creada: el mecánico puede equivocarse al
  /// describir la falla, el kilometraje/horas o el vehículo, y tanto
  /// logística como el bodeguero deben poder arreglarlo (no solo el Admin o
  /// el mecánico que la creó). Las fotos solo se reemplazan si se pasa una
  /// nueva.
  Future<void> editarOrdenTrabajo({
    required String ordenTrabajoId,
    required String vehiculoCod,
    required int kilometrajeActual,
    required String descripcionFallo,
    Uint8List? bytesFotoFallaNueva,
    Uint8List? bytesFotoRepuestoNuevoNueva,
  }) async {
    final patch = <String, dynamic>{
      'vehiculo_cod': vehiculoCod,
      'kilometraje_actual': kilometrajeActual,
      'descripcion_fallo': descripcionFallo,
    };

    if (bytesFotoFallaNueva != null) {
      final path = _rutaFirma('ot_falla', '${DateTime.now().millisecondsSinceEpoch}');
      await supabase.storage.from('inv-firmas').uploadBinary(path, bytesFotoFallaNueva);
      patch['foto_falla_url'] = path;
    }
    if (bytesFotoRepuestoNuevoNueva != null) {
      final path = _rutaFirma('ot_repuesto_nuevo', '${DateTime.now().millisecondsSinceEpoch}');
      await supabase.storage.from('inv-firmas').uploadBinary(path, bytesFotoRepuestoNuevoNueva);
      patch['foto_repuesto_nuevo_url'] = path;
    }

    await supabase.from(tablas.ordenesTrabajo).update(patch).eq('id', ordenTrabajoId);
  }

  Future<void> cerrarOrdenTrabajo(String ordenTrabajoId) async {
    await supabase.from(tablas.ordenesTrabajo).update({
      'estado': 'COMPLETADA',
      'closed_at': DateTime.now().toIso8601String(),
    }).eq('id', ordenTrabajoId);
  }

  /// Busca un repuesto por su código principal o por un código de barras
  /// alterno (otro proveedor) registrado en [tablas.repuestosCodigos].
  Future<Repuesto?> buscarRepuestoPorCodigo(String codigoEscaneado) async {
    final codigo = codigoEscaneado.trim();

    final alias = await supabase
        .from(tablas.repuestosCodigos)
        .select('repuesto_id')
        .eq('codigo_barras', codigo)
        .maybeSingle();

    final query = supabase.from(tablas.repuestos).select();
    final res = alias != null
        ? await query.eq('id', alias['repuesto_id'] as String).maybeSingle()
        : await query.eq('codigo_barras', codigo).maybeSingle();

    if (res == null) return null;
    return Repuesto.fromMap(res);
  }

  Future<List<Repuesto>> obtenerRepuestos() async {
    final res = await supabase.from(tablas.repuestos).select().order('nombre');
    return (res as List).map((e) => Repuesto.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Repuesto> crearRepuesto({
    required String codigoBarras,
    required String nombre,
    int stockMinimo = 2,
    int kilometrajeVidaUtil = 5000,
    bool requierePiezaUsada = true,
  }) async {
    final res = await supabase
        .from(tablas.repuestos)
        .insert({
          'codigo_barras': codigoBarras.trim(),
          'nombre': nombre.trim(),
          'stock_minimo': stockMinimo,
          'kilometraje_vida_util': kilometrajeVidaUtil,
          'requiere_pieza_usada': requierePiezaUsada,
        })
        .select()
        .single();
    return Repuesto.fromMap(res);
  }

  Future<void> vincularCodigoBarras({
    required String repuestoId,
    required String codigoBarras,
    String? proveedorNombre,
  }) async {
    await supabase.from(tablas.repuestosCodigos).upsert({
      'repuesto_id': repuestoId,
      'codigo_barras': codigoBarras.trim(),
      'proveedor_nombre': proveedorNombre,
    }, onConflict: 'codigo_barras');
  }

  /// Registra el despacho de un repuesto contra una OT. Deja la pieza
  /// reemplazada en custodia ([tablas.repuestosRetirados]) con su foto de
  /// evidencia, como control anti-robo.
  Future<void> despacharRepuestoConPiezaUsada({
    required String ordenTrabajoId,
    required String repuestoId,
    required String vehiculoCod,
    required int cantidad,
    required String bodegueroId,
    Uint8List? bytesFotoPiezaUsada,
  }) async {
    String? fotoUrl;
    if (bytesFotoPiezaUsada != null) {
      final path = _rutaFirma('repuestos_usados', '${DateTime.now().millisecondsSinceEpoch}');
      await supabase.storage.from('inv-firmas').uploadBinary(path, bytesFotoPiezaUsada);
      fotoUrl = path;
    }

    await supabase.from(tablas.otConsumo).insert({
      'orden_trabajo_id': ordenTrabajoId,
      'repuesto_id': repuestoId,
      'cantidad': cantidad,
      'bodeguero_id': bodegueroId,
      'foto_evidencia_url': fotoUrl,
    });

    await supabase.from(tablas.repuestosRetirados).insert({
      'orden_trabajo_id': ordenTrabajoId,
      'repuesto_original_id': repuestoId,
      'vehiculo_cod': vehiculoCod,
      'cantidad': cantidad,
      'estado_pieza': 'DANADO_REEMPLAZADO',
      'estado_gestion': 'EN_CUSTODIA',
      'foto_evidencia_url': fotoUrl,
    });
  }

  /// Ingreso de compras a bodega. Si `nuevoCodigoBarras` viene, lo vincula
  /// como alias del repuesto (otro proveedor con su propio código).
  Future<void> registrarIngresoStock({
    required String repuestoId,
    required int cantidad,
    required String bodegueroId,
    required String proveedor,
    String? nuevoCodigoBarras,
    Uint8List? bytesFotoFactura,
  }) async {
    String? fotoUrl;
    if (bytesFotoFactura != null) {
      final path = _rutaFirma('ingresos', '${DateTime.now().millisecondsSinceEpoch}');
      await supabase.storage.from('inv-firmas').uploadBinary(path, bytesFotoFactura);
      fotoUrl = path;
    }

    if (nuevoCodigoBarras != null && nuevoCodigoBarras.trim().isNotEmpty) {
      await vincularCodigoBarras(
        repuestoId: repuestoId,
        codigoBarras: nuevoCodigoBarras,
        proveedorNombre: proveedor,
      );
    }

    await supabase.from(tablas.repuestosIngresos).insert({
      'repuesto_id': repuestoId,
      'bodeguero_id': bodegueroId,
      'cantidad': cantidad,
      'proveedor': proveedor,
      'foto_comprobante_url': fotoUrl,
    });
  }

  /// `inv-firmas` es un bucket privado — las fotos de evidencia se sirven
  /// con URL firmada de 1 hora, igual que las firmas del resto de la app.
  Future<String?> fotoUrlFirmada(String? path) async {
    if (path == null) return null;
    try {
      return await supabase.storage.from('inv-firmas').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  /// Piezas retiradas (chatarra) en custodia, pendientes de que un
  /// supervisor las revise y las dé de baja formalmente.
  Future<List<RepuestoRetirado>> obtenerRetirados({String? estadoGestion = 'EN_CUSTODIA'}) async {
    var query = supabase
        .from(tablas.repuestosRetirados)
        .select('*, repuesto_info:${tablas.repuestos}(nombre), ot_info:${tablas.ordenesTrabajo}(codigo_ot)');
    if (estadoGestion != null) query = query.eq('estado_gestion', estadoGestion);
    final res = await query.order('created_at', ascending: false);
    return (res as List).map((e) => RepuestoRetirado.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Marca las piezas [retiradoIds] como reutilizables: el supervisor
  /// determinó que están en buen estado, así que vuelven al stock del
  /// repuesto (mismo criterio que una devolución en buen estado en
  /// Dotación). El trigger de Postgres aplica el incremento de stock.
  Future<void> reacondicionar(List<String> retiradoIds) async {
    if (retiradoIds.isEmpty) return;
    await supabase
        .from(tablas.repuestosRetirados)
        .update({'estado_gestion': 'REACONDICIONADO'})
        .inFilter('id', retiradoIds);
  }

  /// Cierra formalmente la baja de las piezas [retiradoIds]: crea el acta,
  /// la vincula a cada pieza, y marca cada una como `DADO_DE_BAJA`.
  Future<void> darDeBaja({
    required List<String> retiradoIds,
    required String supervisorId,
    required String motivoBaja,
    required Uint8List firmaSupervisor,
  }) async {
    if (retiradoIds.isEmpty) return;

    final codigoActa = 'BAJA-${DateTime.now().millisecondsSinceEpoch}';
    final path = _rutaFirma('actas_baja', codigoActa);
    await supabase.storage.from('inv-firmas').uploadBinary(path, firmaSupervisor);

    final acta = await supabase
        .from(tablas.actasBaja)
        .insert({
          'codigo_acta': codigoActa,
          'supervisor_id': supervisorId,
          'motivo_baja': motivoBaja,
          'foto_acta_firmada_url': path,
        })
        .select()
        .single();
    final actaId = acta['id'] as String;

    await supabase.from(tablas.actasBajaDetalle).insert(
          retiradoIds.map((id) => {'acta_id': actaId, 'retirado_id': id}).toList(),
        );

    await supabase
        .from(tablas.repuestosRetirados)
        .update({'estado_gestion': 'DADO_DE_BAJA'})
        .inFilter('id', retiradoIds);
  }
}
