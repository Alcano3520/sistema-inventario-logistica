class ResultadoCarga {
  final int agregados;
  final int actualizados;
  final List<String> errores;

  const ResultadoCarga({required this.agregados, required this.actualizados, required this.errores});

  bool get tieneErrores => errores.isNotEmpty;
}
