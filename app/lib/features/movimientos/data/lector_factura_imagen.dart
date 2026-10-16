import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/factura_extraida.dart';
import 'analizador_texto_factura.dart';

/// Lee una FOTO de factura (no el PDF) con reconocimiento de texto en el
/// dispositivo (Google ML Kit) y, con [AnalizadorTextoFactura], detecta los
/// mismos campos que [LectorFacturaPdf] a partir del texto reconocido.
///
/// Solo funciona en Android — ML Kit on-device no tiene build para Web ni
/// escritorio Linux. La pantalla que llama a esto debe ocultar la opción de
/// "leer foto" fuera de Android (ver `kOcrFacturaDisponible`).
class LectorFacturaImagen {
  /// Ruta de un archivo de imagen (la que entrega `image_picker` en disco).
  static Future<FacturaExtraida> extraer(String rutaImagen) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(rutaImagen);
      final resultado = await recognizer.processImage(input);
      return AnalizadorTextoFactura.analizar(resultado.text);
    } finally {
      await recognizer.close();
    }
  }
}
