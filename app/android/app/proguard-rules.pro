# google_mlkit_text_recognition solo usa el reconocedor Latin en esta app:
# las clases de los otros idiomas (chino/japonés/coreano/devanagari) ni
# siquiera están en el classpath porque no se agregó esa dependencia
# opcional de ML Kit. R8 las referencia igual (código del plugin que cubre
# todos los idiomas) y falla el build por "Missing class" en release si no
# se le dice que las ignore — nunca se ejecutan porque solo se usa Latin.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
