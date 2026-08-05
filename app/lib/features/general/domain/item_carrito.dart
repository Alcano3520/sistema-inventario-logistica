import 'articulo_general.dart';

/// Ítem del carrito de una entrega o devolución en construcción. No se
/// persiste directamente: cada uno se convierte en una fila de
/// `inv_general_movimientos` al guardar.
class ItemCarrito {
  final ArticuloGeneral articulo;
  num cantidad;
  bool aplicaDescuento;
  num valorDescuentoPersonalizado;
  String talla;
  String observacion;
  String condicion; // solo se usa en devoluciones

  ItemCarrito({
    required this.articulo,
    this.cantidad = 1,
    bool? aplicaDescuento,
    num? valorDescuentoPersonalizado,
    this.talla = '',
    this.observacion = '',
    this.condicion = 'BUEN_ESTADO',
  })  : aplicaDescuento = aplicaDescuento ?? articulo.esDescontable,
        valorDescuentoPersonalizado = valorDescuentoPersonalizado ?? articulo.valorDescuento;

  num get subtotalDescuento => aplicaDescuento ? valorDescuentoPersonalizado * cantidad : 0;
}
