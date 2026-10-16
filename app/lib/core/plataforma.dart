import 'package:flutter/foundation.dart';

/// El OCR de facturas (lectura de FOTOS, vía Google ML Kit on-device) solo
/// está disponible en Android — no hay build de ML Kit para Web ni para
/// escritorio Linux. Usar esto para ocultar esa opción fuera de Android en
/// vez de dejar que falle al tocarla.
bool get kOcrFacturaDisponible => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
