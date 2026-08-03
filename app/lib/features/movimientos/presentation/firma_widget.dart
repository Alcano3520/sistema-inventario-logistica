import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class FirmaWidget extends StatelessWidget {
  final SignatureController controller;

  const FirmaWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE1E8ED), width: 2),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          height: 180,
          width: double.infinity,
          child: Signature(controller: controller, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: controller.clear,
          child: const Text('🗑️ Limpiar Firma'),
        ),
      ],
    );
  }
}
