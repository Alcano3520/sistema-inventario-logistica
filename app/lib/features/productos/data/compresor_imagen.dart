import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Comprime una foto de producto a JPEG lo más liviano posible, apuntando a
/// quedar entre [minBytes] y [maxBytes]. Usa el paquete `image` (Dart puro,
/// sin plugins nativos) porque esta app compila para más plataformas de las
/// que soportan compresores nativos como `flutter_image_compress`.
///
/// Estrategia: reduce dimensiones y calidad JPEG en pasos hasta entrar en el
/// rango, o hasta agotar los pasos (nunca sube de calidad/tamaño de nuevo).
class CompresorImagen {
  CompresorImagen._();

  static const _anchosMax = [640, 480, 360, 260, 180, 140];
  static const _calidades = [80, 65, 50, 35, 20, 12];

  static Uint8List comprimir(
    Uint8List bytesOriginales, {
    int maxBytes = 30 * 1024,
  }) {
    final decodificada = img.decodeImage(bytesOriginales);
    if (decodificada == null) {
      throw const FormatException('No se pudo leer la imagen.');
    }

    Uint8List? mejorResultado;

    for (final anchoMax in _anchosMax) {
      final redimensionada = decodificada.width > anchoMax
          ? img.copyResize(decodificada, width: anchoMax)
          : decodificada;

      for (final calidad in _calidades) {
        final bytes = Uint8List.fromList(img.encodeJpg(redimensionada, quality: calidad));
        if (mejorResultado == null || bytes.length < mejorResultado.length) {
          mejorResultado = bytes;
        }
        if (bytes.length <= maxBytes) {
          return bytes;
        }
      }
    }

    // No se logró bajar del límite ni con la calidad/tamaño más agresivos:
    // se entrega el resultado más liviano que se pudo generar.
    return mejorResultado!;
  }

  /// Fotos de evidencia/sustento (p.ej. la foto obligatoria de cada
  /// salida): solo tienen que confirmar visualmente que algo pasó, así que
  /// se apunta a ~10KB en vez de los 30KB de las fotos de producto. Como
  /// `compute()` solo pasa un argumento al isolate, esto va aparte en vez
  /// de ser un parámetro de [comprimir].
  static Uint8List comprimirSustento(Uint8List bytesOriginales) =>
      comprimir(bytesOriginales, maxBytes: 10 * 1024);
}
