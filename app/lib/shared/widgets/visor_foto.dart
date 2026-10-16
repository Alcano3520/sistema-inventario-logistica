import 'package:flutter/material.dart';

/// Visor de foto a pantalla completa, con zoom (pellizcar/arrastrar) —
/// compartido por cualquier pantalla que muestre una foto de producto en
/// miniatura y necesite poder ampliarla.
class VisorFotoScreen extends StatelessWidget {
  final String url;
  final String titulo;

  const VisorFotoScreen({super.key, required this.url, required this.titulo});

  static void abrir(BuildContext context, {required String url, required String titulo}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisorFotoScreen(url: url, titulo: titulo),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(titulo, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(url),
        ),
      ),
    );
  }
}
