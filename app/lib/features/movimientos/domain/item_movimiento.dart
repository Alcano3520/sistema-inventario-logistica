class ItemMovimiento {
  String cod;
  String producto;
  String cantidad;

  /// Precio de compra por unidad — solo aplica a líneas de Entrada, opcional.
  String precioUnitario;

  ItemMovimiento({this.cod = '', this.producto = '', this.cantidad = '', this.precioUnitario = ''});
}
