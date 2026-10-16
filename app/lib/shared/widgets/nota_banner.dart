import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

enum TipoNota { info, exito, advertencia, error }

class _EstiloNota {
  final Color color;
  final Color fondo;
  final IconData icono;
  const _EstiloNota(this.color, this.fondo, this.icono);
}

const _estilos = {
  TipoNota.info: _EstiloNota(AppColors.info, AppColors.infoBg, Icons.info_outline),
  TipoNota.exito: _EstiloNota(AppColors.success, AppColors.successBg, Icons.check_circle_outline),
  TipoNota.advertencia: _EstiloNota(AppColors.warning, AppColors.warningBg, Icons.warning_amber_outlined),
  TipoNota.error: _EstiloNota(AppColors.error, AppColors.errorBg, Icons.error_outline),
};

/// Aviso con fondo tintado + ícono, usado para mensajes de resultado
/// (éxito/error), alertas (stock bajo, offline) e información contextual.
/// Reemplaza el patrón repetido de `Container` + `BoxDecoration` con borde
/// de color que aparecía copiado en casi cada pantalla de la app.
class NotaBanner extends StatelessWidget {
  final TipoNota tipo;
  final Widget child;
  final IconData? icono;
  final Widget? accion;

  const NotaBanner({super.key, required this.tipo, required this.child, this.icono, this.accion});

  factory NotaBanner.texto(
    String texto, {
    Key? key,
    TipoNota tipo = TipoNota.info,
    IconData? icono,
    Widget? accion,
  }) {
    return NotaBanner(
      key: key,
      tipo: tipo,
      icono: icono,
      accion: accion,
      child: Text(texto, style: AppText.body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estilo = _estilos[tipo]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: estilo.fondo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: estilo.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono ?? estilo.icono, color: estilo.color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: child),
          ?accion,
        ],
      ),
    );
  }
}
