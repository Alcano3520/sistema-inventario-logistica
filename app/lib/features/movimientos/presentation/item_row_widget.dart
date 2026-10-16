import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../shared/widgets/lector_scanner_dialog.dart';
import '../../../shared/widgets/visor_foto.dart';
import '../../productos/domain/producto.dart';
import '../domain/item_movimiento.dart';

class ItemRowWidget extends StatelessWidget {
  final ItemMovimiento item;
  final List<Producto> productos;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  /// El precio de compra por unidad solo tiene sentido en Entrada, no en
  /// Salida — por eso es opcional y lo activa cada pantalla que use esta
  /// misma fila.
  final bool mostrarPrecio;

  const ItemRowWidget({
    super.key,
    required this.item,
    required this.productos,
    required this.onRemove,
    required this.onChanged,
    this.mostrarPrecio = false,
  });

  Future<void> _escanearProducto(BuildContext context) async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LectorScannerDialog(titulo: 'Escanear código de barras o QR')),
    );
    if (codigo == null) return;

    final buscado = codigo.trim().toLowerCase();
    final encontrado = productos
        .where((p) =>
            p.cod.toLowerCase() == buscado || (p.codigoBarras?.toLowerCase() == buscado))
        .firstOrNull;

    if (encontrado == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No existe ningún producto con el código "$codigo".')),
        );
      }
      return;
    }

    item.cod = encontrado.cod;
    item.producto = encontrado.producto;
    onChanged();
  }

  Widget _campoProducto(BuildContext context) {
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
          decoration: InputDecoration(
            labelText: 'Producto',
            hintText: 'Buscar, o escanear código de barras / QR',
            isDense: true,
            suffixIcon: IconButton.filled(
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              tooltip: 'Escanear código de barras o QR',
              onPressed: () => _escanearProducto(context),
            ),
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

  /// Una vez que el producto quedó identificado (por búsqueda o escaneo),
  /// muestra su foto y código para confirmar visualmente que es el correcto
  /// — especialmente útil justo después de escanear. La foto es más grande
  /// que un simple ícono y se puede tocar para verla a pantalla completa,
  /// porque a este tamaño no se distingue bien el producto.
  Widget? _confirmacionProducto(BuildContext context) {
    if (item.cod.isEmpty) return null;
    final encontrado = productos.where((p) => p.cod == item.cod).firstOrNull;
    final fotoUrl = encontrado?.fotoUrl;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: fotoUrl != null
                ? () => VisorFotoScreen.abrir(context, url: fotoUrl, titulo: encontrado?.producto ?? item.producto)
                : null,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: fotoUrl != null
                      ? Image.network(fotoUrl, width: 52, height: 52, fit: BoxFit.cover)
                      : Container(
                          width: 52,
                          height: 52,
                          color: AppColors.surfaceAlt,
                          child: const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textSecondary),
                        ),
                ),
                if (fotoUrl != null)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration:
                          BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${encontrado?.producto ?? item.producto}\nCódigo: ${item.cod}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
          ),
          const Icon(Icons.check_circle, color: AppColors.success, size: 16),
        ],
      ),
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

  Widget _campoPrecio() {
    return TextFormField(
      initialValue: item.precioUnitario,
      decoration: const InputDecoration(labelText: 'Precio unit. (opcional)', isDense: true, prefixText: '\$'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) => item.precioUnitario = v,
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
    final confirmacion = _confirmacionProducto(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final angosto = constraints.maxWidth < 420;

          if (angosto) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _campoProducto(context),
                ?confirmacion,
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _campoCantidad()),
                    if (mostrarPrecio) ...[
                      const SizedBox(width: 10),
                      Expanded(child: _campoPrecio()),
                    ],
                    _botonQuitar(),
                  ],
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: _campoProducto(context)),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: _campoCantidad()),
                  if (mostrarPrecio) ...[
                    const SizedBox(width: 10),
                    Expanded(flex: 1, child: _campoPrecio()),
                  ],
                  const SizedBox(width: 6),
                  _botonQuitar(),
                ],
              ),
              ?confirmacion,
            ],
          );
        },
      ),
    );
  }
}
