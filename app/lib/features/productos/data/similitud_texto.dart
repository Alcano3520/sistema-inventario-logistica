/// Compara nombres de productos para avisar si uno parecido ya existe en el
/// catálogo — evita duplicar el mismo producto con un nombre escrito
/// distinto (mayúsculas, tildes, orden de palabras, abreviado, etc.).
class SimilitudTexto {
  SimilitudTexto._();

  static const _tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n', 'ü': 'u'};

  static String _normalizar(String s) {
    var r = s.toLowerCase().trim();
    _tildes.forEach((tilde, plano) => r = r.replaceAll(tilde, plano));
    return r.replaceAll(RegExp(r'\s+'), ' ');
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previa = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final actual = List<int>.filled(b.length + 1, 0);
      actual[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final costo = a[i] == b[j] ? 0 : 1;
        final borrar = actual[j] + 1;
        final insertar = previa[j + 1] + 1;
        final sustituir = previa[j] + costo;
        actual[j + 1] = [borrar, insertar, sustituir].reduce((v, e) => v < e ? v : e);
      }
      previa = actual;
    }
    return previa[b.length];
  }

  /// `true` si [a] y [b] probablemente nombran el mismo producto.
  static bool sonParecidos(String a, String b) {
    final na = _normalizar(a);
    final nb = _normalizar(b);
    if (na.isEmpty || nb.isEmpty || na == nb) return na == nb;

    if (na.length > 3 && nb.length > 3 && (na.contains(nb) || nb.contains(na))) return true;

    final distancia = _levenshtein(na, nb);
    final maxLen = na.length > nb.length ? na.length : nb.length;
    return (1 - (distancia / maxLen)) >= 0.82;
  }
}
