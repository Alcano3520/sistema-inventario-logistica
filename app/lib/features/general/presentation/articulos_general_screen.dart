import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/app_theme.dart';
import 'general_providers.dart';

class ArticulosGeneralScreen extends ConsumerStatefulWidget {
  const ArticulosGeneralScreen({super.key});

  @override
  ConsumerState<ArticulosGeneralScreen> createState() => _ArticulosGeneralScreenState();
}

class _ArticulosGeneralScreenState extends ConsumerState<ArticulosGeneralScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codController = TextEditingController();
  final _codigoBarrasController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _subcategoriaController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _proveedorController = TextEditingController();
  final _stockMinimoController = TextEditingController(text: '1');
  final _valorUnitarioController = TextEditingController(text: '0');
  final _valorDescuentoController = TextEditingController(text: '0');
  bool _esDescontable = false;
  bool _requiereDevolucion = true;
  bool _guardando = false;
  String? _resultadoError;
  String? _resultadoExito;

  @override
  void dispose() {
    _codController.dispose();
    _codigoBarrasController.dispose();
    _descripcionController.dispose();
    _categoriaController.dispose();
    _subcategoriaController.dispose();
    _ubicacionController.dispose();
    _proveedorController.dispose();
    _stockMinimoController.dispose();
    _valorUnitarioController.dispose();
    _valorDescuentoController.dispose();
    super.dispose();
  }

  void _limpiar() {
    _formKey.currentState?.reset();
    _codController.clear();
    _codigoBarrasController.clear();
    _descripcionController.clear();
    _categoriaController.clear();
    _subcategoriaController.clear();
    _ubicacionController.clear();
    _proveedorController.clear();
    _stockMinimoController.text = '1';
    _valorUnitarioController.text = '0';
    _valorDescuentoController.text = '0';
    setState(() {
      _esDescontable = false;
      _requiereDevolucion = true;
      _resultadoError = null;
      _resultadoExito = null;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _resultadoError = null;
      _resultadoExito = null;
    });

    final cod = _codController.text.trim();
    final descripcion = _descripcionController.text.trim();

    try {
      await ref.read(articulosGeneralRepositoryProvider).agregarArticulo(
            codigoInterno: cod,
            codigoBarras: _codigoBarrasController.text,
            descripcion: descripcion,
            categoria: _categoriaController.text,
            subcategoria: _subcategoriaController.text,
            stockMinimo: num.tryParse(_stockMinimoController.text) ?? 1,
            valorUnitario: num.tryParse(_valorUnitarioController.text) ?? 0,
            valorDescuento: num.tryParse(_valorDescuentoController.text) ?? 0,
            esDescontable: _esDescontable,
            requiereDevolucion: _requiereDevolucion,
            ubicacionBodega: _ubicacionController.text,
            proveedor: _proveedorController.text,
          );
      await ref.read(articulosGeneralProvider.notifier).refrescar();
      if (mounted) {
        _limpiar();
        setState(() => _resultadoExito = 'Artículo $cod - $descripcion agregado exitosamente.');
      }
    } on PostgrestException catch (e) {
      setState(() {
        _resultadoError = e.code == '23505'
            ? 'El artículo con ese código ya existe.'
            : 'Error al guardar: ${e.message}';
      });
    } catch (e) {
      setState(() => _resultadoError = 'Error al agregar el artículo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '➕ Agregar Nuevo Artículo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            _campo(
              label: 'Código interno:',
              requerido: true,
              controller: _codController,
              hint: 'Ej: UNI-001',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            _campo(label: 'Código de barras:', controller: _codigoBarrasController, hint: 'Opcional'),
            _campo(
              label: 'Descripción:',
              requerido: true,
              controller: _descripcionController,
              hint: 'Ej: Camisa uniforme talla M',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            _campo(label: 'Categoría:', controller: _categoriaController, hint: 'Ej: Uniformes'),
            _campo(label: 'Subcategoría:', controller: _subcategoriaController, hint: 'Opcional'),
            _campo(label: 'Ubicación en bodega:', controller: _ubicacionController, hint: 'Ej: Estante A1'),
            _campo(label: 'Proveedor:', controller: _proveedorController, hint: 'Opcional'),
            _campo(
              label: 'Stock Mínimo:',
              controller: _stockMinimoController,
              keyboardType: TextInputType.number,
            ),
            _campo(
              label: 'Valor unitario (\$):',
              controller: _valorUnitarioController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('¿Genera descuento de nómina al entregarse?'),
              value: _esDescontable,
              onChanged: (v) => setState(() => _esDescontable = v),
            ),
            if (_esDescontable)
              _campo(
                label: 'Valor de descuento por unidad (\$):',
                controller: _valorDescuentoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('¿Requiere devolución?'),
              value: _requiereDevolucion,
              onChanged: (v) => setState(() => _requiereDevolucion = v),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('💾 Agregar Artículo'),
                ),
                OutlinedButton(
                  onPressed: _guardando ? null : _limpiar,
                  child: const Text('🔄 Limpiar'),
                ),
              ],
            ),
            if (_resultadoExito != null) ...[
              const SizedBox(height: 20),
              _mensaje(_resultadoExito!, exito: true),
            ],
            if (_resultadoError != null) ...[
              const SizedBox(height: 20),
              _mensaje(_resultadoError!, exito: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mensaje(String texto, {required bool exito}) {
    final color = exito ? AppColors.success : AppColors.error;
    final bg = exito ? const Color(0xFFE8F8F5) : const Color(0xFFFDEAEA);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Text(texto, style: TextStyle(color: color)),
    );
  }

  Widget _campo({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool requerido = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style:
                  const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
              children: [
                if (requerido) const TextSpan(text: '* ', style: TextStyle(color: AppColors.error)),
                TextSpan(text: label),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(hintText: hint),
            validator: validator,
          ),
        ],
      ),
    );
  }
}
