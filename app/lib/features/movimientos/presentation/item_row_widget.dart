import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../productos/domain/producto.dart';
import '../domain/item_movimiento.dart';

class ItemRowWidget extends StatelessWidget {
  final ItemMovimiento item;
  final List<Producto> productos;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const ItemRowWidget({
    super.key,
    required this.item,
    required this.productos,
    required this.onRemove,
    required this.onChanged,
  });

  Widget _campoProducto() {
    return Autocomplete<Producto>(
      displayStringForOption: (p) => '${p.cod} - ${p.producto}',
      optionsBuilder: (value) {
        if (value.text.isEmpty) return const Iterable<Producto>.empty();
        final termino = value.text.toLowerCase();
        return productos.where((p) =>
            p.cod.toLowerCase().contains(termino) || p.producto.toLowerCase().contains(termino));
      },
      onSelected: (p) {
        item.cod = p.cod;
        item.producto = p.producto;
        onChanged();
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final p = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(p.producto, overflow: TextOverflow.ellipsis),
                    subtitle: Text(p.cod, style: const TextStyle(fontSize: 11)),
                    onTap: () => onSelected(p),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        if (item.producto.isNotEmpty && controller.text.isEmpty) {
          controller.text = item.producto;
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Producto',
            hintText: 'Buscar producto...',
            isDense: true,
          ),
          onChanged: (v) {
            if (v != item.producto) {
              item.cod = '';
            }
          },
        );
      },
    );
  }

  Widget _campoCantidad() {
    return TextFormField(
      initialValue: item.cantidad,
      decoration: const InputDecoration(labelText: 'Cantidad', isDense: true),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) => item.cantidad = v,
    );
  }

  Widget _botonQuitar() {
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: AppColors.error),
      tooltip: 'Quitar',
      onPressed: onRemove,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final angosto = constraints.maxWidth < 420;

          if (angosto) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _campoProducto(),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _campoCantidad()),
                    _botonQuitar(),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: _campoProducto()),
              const SizedBox(width: 10),
              Expanded(flex: 1, child: _campoCantidad()),
              const SizedBox(width: 6),
              _botonQuitar(),
            ],
          );
        },
      ),
    );
  }
}
