import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../features/productos/data/similitud_texto.dart';

/// Campo de texto con autocompletado contra valores ya usados (categorías,
/// ubicaciones) — se puede elegir uno existente o escribir uno nuevo. Si lo
/// escrito se parece a un valor que ya existe mostrando otro nombre (p.ej.
/// "Bodega Durán" vs "Casa Durán"), avisa para no terminar con dos entradas
/// distintas para lo mismo.
class CampoSugerido extends StatefulWidget {
  final String label;
  final String initialValue;
  final List<String> opciones;
  final ValueChanged<String> onChanged;

  const CampoSugerido({
    super.key,
    required this.label,
    required this.initialValue,
    required this.opciones,
    required this.onChanged,
  });

  @override
  State<CampoSugerido> createState() => _CampoSugeridoState();
}

class _CampoSugeridoState extends State<CampoSugerido> {
  String? _parecido;

  void _verificar(String valor) {
    widget.onChanged(valor);
    final v = valor.trim();
    if (v.isEmpty || widget.opciones.any((o) => o.toLowerCase() == v.toLowerCase())) {
      if (_parecido != null) setState(() => _parecido = null);
      return;
    }
    String? encontrado;
    for (final o in widget.opciones) {
      if (SimilitudTexto.sonParecidos(o, v)) {
        encontrado = o;
        break;
      }
    }
    if (encontrado != _parecido) setState(() => _parecido = encontrado);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<String>(
          initialValue: TextEditingValue(text: widget.initialValue),
          optionsBuilder: (v) {
            if (v.text.isEmpty) return widget.opciones;
            final termino = v.text.toLowerCase();
            return widget.opciones.where((o) => o.toLowerCase().contains(termino));
          },
          onSelected: _verificar,
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(labelText: widget.label, isDense: true),
              onChanged: _verificar,
            );
          },
        ),
        if (_parecido != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              '¿Es lo mismo que "$_parecido"? Ya existe en el catálogo — usa ese mismo nombre para no duplicarlo.',
              style: const TextStyle(fontSize: 11, color: AppColors.warning),
            ),
          ),
      ],
    );
  }
}
