import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../core/app_theme.dart';

class FirmaWidget extends StatelessWidget {
  final SignatureController controller;

  const FirmaWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 2),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          height: 180,
          width: double.infinity,
          child: Signature(controller: controller, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.clear,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Limpiar Firma'),
        ),
      ],
    );
  }
}
