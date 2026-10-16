import '../domain/factura_extraida.dart';

/// Heurísticas de texto para detectar los campos de una factura (RIDE de
/// factura electrónica del SRI), sin importar si el texto vino de un PDF
/// (extracción directa) o de una foto (OCR). El formato del RIDE varía
/// muchísimo según el software de facturación de cada proveedor, así que
/// esto es "mejor esfuerzo": la persona siempre debe revisar y corregir lo
/// detectado antes de guardar — nunca se auto-completa el código de
/// producto (eso exige elegirlo del catálogo) para no arriesgar que una
/// entrada quede con un código que no existe y el stock no se actualice.
class AnalizadorTextoFactura {
  static final _reClaveAcceso = RegExp(r'\b(\d{49})\b');
  static final _reNumFactura = RegExp(r'\b(\d{3})\s*-\s*(\d{3})\s*-\s*(\d{9})\b');
  static final _reFecha = RegExp(r'\b(\d{2})/(\d{2})/(\d{4})\b');
  static final _reMatriz = RegExp(r'Dir(?:ecci[oó]n)?\.?\s*Matriz', caseSensitive: false);

  static FacturaExtraida analizar(String texto) {
    final plano = texto.replaceAll(RegExp(r'[ \t]+'), ' ');

    String? claveAcceso;
    try {
      claveAcceso = _reClaveAcceso.firstMatch(plano)?.group(1);
    } catch (_) {}

    String? numFactura;
    try {
      final m = _reNumFactura.firstMatch(plano);
      if (m != null) numFactura = '${m.group(1)}-${m.group(2)}-${m.group(3)}';
    } catch (_) {}

    DateTime? fecha;
    try {
      fecha = _detectarFecha(plano);
    } catch (_) {}

    String? proveedor;
    try {
      proveedor = _detectarProveedor(texto);
    } catch (_) {}

    final items = <ItemFacturaExtraido>[];
    try {
      for (final linea in texto.split('\n')) {
        final item = _parsearLineaItem(linea);
        if (item != null) items.add(item);
      }
    } catch (_) {}

    return FacturaExtraida(
      proveedor: proveedor,
      numFactura: numFactura,
      claveAcceso: claveAcceso,
      fecha: fecha,
      items: items,
    );
  }

  /// Prefiere una fecha que aparezca cerca de la palabra "FECHA" (p.ej.
  /// "Fecha Emisión:", "Fecha y Hora de Autorización:") sobre cualquier
  /// otra fecha suelta del documento (como una fecha de vencimiento).
  static DateTime? _detectarFecha(String plano) {
    String? elegida;
    for (final m in _reFecha.allMatches(plano)) {
      final desde = (m.start - 35).clamp(0, plano.length);
      final antes = plano.substring(desde, m.start).toUpperCase();
      if (antes.contains('FECHA')) {
        elegida = m.group(0);
        break;
      }
    }
    elegida ??= _reFecha.firstMatch(plano)?.group(0);
    if (elegida == null) return null;
    final partes = elegida.split('/');
    if (partes.length != 3) return null;
    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final anio = int.tryParse(partes[2]);
    if (dia == null || mes == null || anio == null) return null;
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
    return DateTime(anio, mes, dia);
  }

  /// Etiquetas/valores fijos del RIDE que nunca son el nombre del
  /// proveedor, aunque por la posición en el texto parezcan estar "justo
  /// antes" de la dirección — se descartan al buscar hacia atrás.
  static final _reLineaDescartable = RegExp(
    r'^(no\.?|nro\.?|n°|r\.?u\.?c\.?|clave|contribuyente|ambiente|tipoemision|'
    r'fecha|autorizaci[oó]n|factura|identificaci[oó]n|razon social)\b',
    caseSensitive: false,
  );

  /// El nombre del proveedor casi nunca viene con una etiqueta propia en el
  /// RIDE, pero el SRI sí exige que la dirección matriz del emisor aparezca
  /// justo debajo de su razón social/nombre comercial — así que se busca,
  /// desde esa línea hacia atrás, la primera línea que luzca como un nombre
  /// real (no un número de factura, una etiqueta fija, ni la clave de
  /// acceso) para usarla como proveedor.
  static String? _detectarProveedor(String texto) {
    final m = _reMatriz.firstMatch(texto);
    if (m == null) return null;
    final previo = texto.substring(0, m.start);
    final lineas = previo
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.toUpperCase().contains('CONTRIBUYENTE'))
        .toList();
    if (lineas.isEmpty) return null;

    bool esDescartable(String l) {
      if (l.length < 4) return true;
      if (_reLineaDescartable.hasMatch(l)) return true;
      if (_reNumFactura.hasMatch(l) && l.length < 20) return true;
      if (RegExp(r'^\d{10,}$').hasMatch(l.replaceAll(RegExp(r'[\s-]'), ''))) return true;
      // Mayormente dígitos/puntuación, con poca letra real: no es un nombre.
      final letras = RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]').allMatches(l).length;
      if (letras < l.length * 0.4) return true;
      return false;
    }

    var idx = lineas.length - 1;
    while (idx >= 0 && esDescartable(lineas[idx])) {
      idx--;
    }
    if (idx < 0) return null;

    var nombre = lineas[idx];
    // Si la línea elegida quedó muy corta (el nombre se partió en dos
    // líneas por ser largo), se agrega la línea anterior también.
    if (nombre.length < 8 && idx > 0 && !esDescartable(lineas[idx - 1])) {
      nombre = '${lineas[idx - 1]} $nombre';
    }
    nombre = nombre.trim();
    if (nombre.length < 3 || nombre.length > 90) return null;
    return nombre;
  }

  /// Intenta reconocer una línea de detalle de la tabla de ítems: empieza
  /// con algo que luce como código de producto, trae una descripción, y
  /// termina en montos. No importa en qué orden vengan las columnas de
  /// precio/descuento/IVA de por medio (varía mucho entre proveedores): el
  /// primer número tras la descripción se toma como cantidad y el último
  /// monto de la línea como total — de ahí se calcula el precio unitario
  /// (total ÷ cantidad), que es más confiable que adivinar cuál columna de
  /// en medio es el "precio".
  static ItemFacturaExtraido? _parsearLineaItem(String linea) {
    final t = linea.trim();
    if (t.isEmpty) return null;
    final tokens = t.split(RegExp(r'\s+'));
    if (tokens.length < 4) return null;

    final codigo = tokens.first;
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-./]{1,19}$').hasMatch(codigo)) return null;
    if (!RegExp(r'[A-Za-z]').hasMatch(codigo)) return null;

    num? parseMonto(String s) {
      final limpio = s.replaceAll(r'$', '').replaceAll(',', '');
      return num.tryParse(limpio);
    }

    final total = parseMonto(tokens.last);
    if (total == null || total <= 0) return null;

    // La cantidad es el PRIMER token de la última racha de tokens numéricos
    // consecutivos (cantidad, precio, descuento, %IVA, total — en cualquier
    // orden según el proveedor). Se busca desde el final hacia atrás en vez
    // de tomar el primer número tras la descripción, porque la descripción
    // a veces trae números propios (p.ej. "CABLE 14 TW", calibres o
    // fracciones de pulgada) que no son la cantidad.
    var idxCantidad = tokens.length - 1;
    for (var i = tokens.length - 2; i >= 1; i--) {
      final n = parseMonto(tokens[i]);
      if (n == null) break;
      idxCantidad = i;
    }
    if (idxCantidad >= tokens.length - 1) return null;
    final cantidad = parseMonto(tokens[idxCantidad]);
    if (idxCantidad < 2 || cantidad == null || cantidad <= 0) return null;

    final descripcion = tokens.sublist(1, idxCantidad).join(' ').trim();
    if (descripcion.length < 3 || !RegExp(r'[A-Za-z]{3,}').hasMatch(descripcion)) return null;

    final precioUnitario = cantidad > 0 ? (total / cantidad) : null;

    return ItemFacturaExtraido(
      descripcion: descripcion,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      codigoProveedor: codigo,
    );
  }
}
