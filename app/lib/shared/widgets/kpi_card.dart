import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Tarjeta de indicador numérico usada en los dashboards de cada módulo
/// (Barcos/Motos y General). Antes existían dos copias idénticas de este
/// widget, una por dashboard — se unificó aquí.
class KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final bool alerta;

  const KpiCard({super.key, required this.value, required this.label, this.alerta = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alerta ? AppColors.warning.withValues(alpha: 0.4) : AppColors.border),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.kpiValue.copyWith(color: alerta ? AppColors.warning : AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.label,
          ),
        ],
      ),
    );
  }
}
