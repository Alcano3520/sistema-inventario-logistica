import '../../../core/supabase_config.dart';
import '../domain/descuento_nomina.dart';

class DescuentosGeneralRepository {
  Future<List<DescuentoNomina>> obtenerPendientes() async {
    final data = await supabase
        .from('inv_general_descuentos_nomina')
        .select()
        .eq('exportado', false)
        .order('fecha_entrega', ascending: false);
    return (data as List).map((e) => DescuentoNomina.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<DescuentoNomina>> obtenerExportados({int limite = 200}) async {
    final data = await supabase
        .from('inv_general_descuentos_nomina')
        .select()
        .eq('exportado', true)
        .order('fecha_exportacion', ascending: false)
        .limit(limite);
    return (data as List).map((e) => DescuentoNomina.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> marcarComoExportados(List<String> ids, String loteNumero) async {
    await supabase.from('inv_general_descuentos_nomina').update({
      'exportado': true,
      'fecha_exportacion': DateTime.now().toIso8601String(),
      'lote_numero': loteNumero,
    }).inFilter('id', ids);
  }
}
