import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/app_theme.dart';
import 'productos_providers.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codController = TextEditingController();
  final _nombreController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _stockMinimoController = TextEditingController(text: '5');
  bool _guardando = false;
  String? _resultadoError;
  String? _resultadoExito;

  @override
  void dispose() {
    _codController.dispose();
    _nombreController.dispose();
    _categoriaController.dispose();
    _ubicacionController.dispose();
    _stockMinimoController.dispose();
    super.dispose();
  }

  void _limpiar() {
    _formKey.currentState?.reset();
    _codController.clear();
    _nombreController.clear();
    _categoriaController.clear();
    _ubicacionController.clear();
    _stockMinimoController.text = '5';
    setState(() {
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
    final nombre = _nombreController.text.trim();

    try {
      await ref.read(productosRepositoryProvider).agregarProducto(
            cod: cod,
            producto: nombre,
            categoria: _categoriaController.text,
            ubicacion: _ubicacionController.text,
            stockMinimo: num.tryParse(_stockMinimoController.text) ?? 5,
          );
      await ref.read(productosProvider.notifier).refrescar();
      if (mounted) {
        _limpiar();
        setState(() => _resultadoExito = 'Producto $cod - $nombre agregado exitosamente.');
      }
    } on PostgrestException catch (e) {
      setState(() {
        _resultadoError = e.code == '23505'
            ? 'El producto con código $cod ya existe.'
            : 'Error al guardar: ${e.message}';
      });
    } catch (e) {
      setState(() => _resultadoError = 'Error al agregar el producto.');
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
              '➕ Agregar Nuevo Producto',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            _campo(
              label: 'Código:',
              requerido: true,
              controller: _codController,
              hint: 'Ej: 8M0098635',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            _campo(
              label: 'Nombre del Producto:',
              requerido: true,
              controller: _nombreController,
              hint: 'Ej: HEAD GASKET',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            _campo(label: 'Categoría:', controller: _categoriaController, hint: 'Ej: Repuestos'),
            _campo(label: 'Ubicación:', controller: _ubicacionController, hint: 'Ej: Almacén'),
            _campo(
              label: 'Stock Mínimo:',
              controller: _stockMinimoController,
              keyboardType: TextInputType.number,
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
                      : const Text('💾 Agregar Producto'),
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
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
              children: [
                if (requerido)
                  const TextSpan(text: '* ', style: TextStyle(color: AppColors.error)),
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
