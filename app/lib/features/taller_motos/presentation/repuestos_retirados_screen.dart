import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

import '../../../core/app_theme.dart';
import '../../../core/modulos.dart';
import '../../../shared/widgets/nota_banner.dart';
import '../../../shared/widgets/visor_foto.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../movimientos/presentation/firma_widget.dart';
import '../data/acta_baja_pdf_service.dart';
import '../domain/repuesto_retirado.dart';
import 'taller_providers.dart';

/// Piezas retiradas en cada despacho (control anti-robo: nada se bota,
/// todo queda en custodia con foto hasta que un supervisor la revisa). Ahí
/// el supervisor decide, igual que una devolución en Dotación: si está en
/// buen estado vuelve al stock del repuesto (Reutilizar), y si no, se da
/// de baja formalmente con un acta firmada.
class RepuestosRetiradosScreen extends ConsumerStatefulWidget {
  const RepuestosRetiradosScreen({super.key});

  @override
  ConsumerState<RepuestosRetiradosScreen> createState() => _RepuestosRetiradosScreenState();
}

class _RepuestosRetiradosScreenState extends ConsumerState<RepuestosRetiradosScreen> {
  final _formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
  final Set<String> _seleccionados = {};
  bool _procesando = false;

  Future<void> _abrirDialogoBaja(List<RepuestoRetirado> retirados) async {
    final elegidos = retirados.where((r) => _seleccionados.contains(r.id)).toList();
    if (elegidos.isEmpty) return;

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoDarDeBaja(piezas: elegidos),
    );

    if (resultado == true) {
      setState(() => _seleccionados.clear());
      ref.read(repuestosRetiradosProvider.notifier).refrescar();
    }
  }

  Future<void> _reutilizar(List<RepuestoRetirado> retirados) async {
    final elegidos = retirados.where((r) => _seleccionados.contains(r.id)).toList();
    if (elegidos.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Reutilizar estas piezas?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quedaron en buen estado y volverán al stock disponible del repuesto:'),
              const SizedBox(height: 10),
              ...elegidos.map((p) => Text('• ${p.repuestoNombre ?? 'Repuesto'} (Cant: ${p.cantidad})')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRMAR')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      await ref.read(tallerRepositoryProvider).reacondicionar(elegidos.map((p) => p.id).toList());
      if (mounted) {
        setState(() => _seleccionados.clear());
        ref.read(repuestosRetiradosProvider.notifier).refrescar();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Piezas devueltas al stock.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final retiradosAsync = ref.watch(repuestosRetiradosProvider);
    final retirados = retiradosAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Piezas Retiradas')),
      body: retiradosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error al cargar: $e')),
        data: (retirados) {
          if (retirados.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay piezas en custodia pendientes de revisión.',
                    style: AppText.bodySecondary, textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(repuestosRetiradosProvider.notifier).refrescar(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                NotaBanner.texto(
                  'Selecciona las piezas ya revisadas: si sirven, reutilízalas (vuelven al stock); '
                  'si no, dales de baja con acta firmada.',
                  tipo: TipoNota.info,
                ),
                const SizedBox(height: 12),
                ...retirados.map((r) => _FilaRetirado(
                      retirado: r,
                      seleccionado: _seleccionados.contains(r.id),
                      onSeleccionar: (v) => setState(() {
                        if (v) {
                          _seleccionados.add(r.id);
                        } else {
                          _seleccionados.remove(r.id);
                        }
                      }),
                      formatoFecha: _formatoFecha,
                    )),
                const SizedBox(height: 90),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _seleccionados.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _procesando ? null : () => _reutilizar(retirados),
                        icon: const Icon(Icons.replay_outlined),
                        label: Text('Reutilizar (${_seleccionados.length})'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _procesando ? null : () => _abrirDialogoBaja(retirados),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text('Dar de baja (${_seleccionados.length})'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FilaRetirado extends ConsumerWidget {
  final RepuestoRetirado retirado;
  final bool seleccionado;
  final ValueChanged<bool> onSeleccionar;
  final DateFormat formatoFecha;

  const _FilaRetirado({
    required this.retirado,
    required this.seleccionado,
    required this.onSeleccionar,
    required this.formatoFecha,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablas = ref.watch(tablasActivasProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: seleccionado ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: seleccionado ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: seleccionado, onChanged: (v) => onSeleccionar(v ?? false)),
          FutureBuilder<String?>(
            future: ref.read(tallerRepositoryProvider).fotoUrlFirmada(retirado.fotoEvidenciaUrl),
            builder: (context, snapshot) {
              final url = snapshot.data;
              return GestureDetector(
                onTap: url != null
                    ? () => VisorFotoScreen.abrir(context,
                        url: url, titulo: retirado.repuestoNombre ?? 'Pieza retirada')
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: url != null
                      ? Image.network(url, width: 56, height: 56, fit: BoxFit.cover)
                      : Container(
                          width: 56,
                          height: 56,
                          color: AppColors.surfaceAlt,
                          child: const Icon(Icons.image_outlined, size: 20, color: AppColors.textSecondary),
                        ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(retirado.repuestoNombre ?? 'Repuesto',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                    '${tablas.etiquetaVehiculo}: ${retirado.vehiculoCod} · OT: ${retirado.codigoOt ?? '-'} · Cant: ${retirado.cantidad}',
                    style: AppText.bodySecondary),
                Text(formatoFecha.format(retirado.creadoEn.toLocal()), style: AppText.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoDarDeBaja extends ConsumerStatefulWidget {
  final List<RepuestoRetirado> piezas;
  const _DialogoDarDeBaja({required this.piezas});

  @override
  ConsumerState<_DialogoDarDeBaja> createState() => _DialogoDarDeBajaState();
}

class _DialogoDarDeBajaState extends ConsumerState<_DialogoDarDeBaja> {
  final _motivoController = TextEditingController();
  final _firmaController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _motivoController.dispose();
    _firmaController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_motivoController.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el motivo de la baja.');
      return;
    }
    if (_firmaController.isEmpty) {
      setState(() => _error = 'Falta la firma del supervisor.');
      return;
    }
    final perfil = ref.read(perfilActualProvider).valueOrNull;
    if (perfil == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final firmaBytes = await _firmaController.toPngBytes();
      final repo = ref.read(tallerRepositoryProvider);
      await repo.darDeBaja(
        retiradoIds: widget.piezas.map((p) => p.id).toList(),
        supervisorId: perfil.id,
        motivoBaja: _motivoController.text.trim(),
        firmaSupervisor: firmaBytes!,
      );

      final pdf = await ActaBajaPdfService.generarPdfActa(
        codigoActa: 'BAJA-${DateTime.now().millisecondsSinceEpoch}',
        nombreSupervisor: perfil.nombre,
        motivo: _motivoController.text.trim(),
        piezasBaja: widget.piezas
            .map((p) => {
                  'nombre_repuesto': p.repuestoNombre ?? 'Repuesto',
                  'cantidad': p.cantidad,
                  'estado_pieza': p.estadoPieza,
                  'codigo_ot': p.codigoOt ?? 'N/A',
                })
            .toList(),
        bytesFirmaSupervisor: firmaBytes,
      );
      await ActaBajaPdfService.imprimirOCompartirPdf(pdf, 'acta_baja');

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'No se pudo completar la baja: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Dar de baja ${widget.piezas.length} pieza(s)'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...widget.piezas.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• ${p.repuestoNombre ?? 'Repuesto'} (OT ${p.codigoOt ?? '-'})',
                        style: AppText.bodySecondary),
                  )),
              const SizedBox(height: 12),
              TextField(
                controller: _motivoController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Motivo de la baja'),
              ),
              const SizedBox(height: 14),
              const Text('Firma del supervisor:', style: AppText.bodySecondary),
              const SizedBox(height: 6),
              FirmaWidget(controller: _firmaController),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _confirmar,
          child: _guardando
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirmar baja'),
        ),
      ],
    );
  }
}
