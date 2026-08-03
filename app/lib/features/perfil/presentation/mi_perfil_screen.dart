import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_theme.dart';
import '../../auth/presentation/auth_providers.dart';

class MiPerfilScreen extends ConsumerStatefulWidget {
  const MiPerfilScreen({super.key});

  @override
  ConsumerState<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends ConsumerState<MiPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actualController = TextEditingController();
  final _nuevaController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _guardando = false;
  String? _error;
  String? _exito;

  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _cambiarPassword() async {
    setState(() {
      _error = null;
      _exito = null;
    });

    if (_nuevaController.text.length < 6) {
      setState(() => _error = 'La nueva contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (_nuevaController.text != _confirmarController.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    final perfil = ref.read(perfilActualProvider).valueOrNull;
    if (perfil == null) return;

    setState(() => _guardando = true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            emailOUsuario: perfil.email,
            password: _actualController.text,
          );
      await ref.read(authRepositoryProvider).changePassword(_nuevaController.text);
      setState(() => _exito = 'Contraseña actualizada exitosamente.');
      _actualController.clear();
      _nuevaController.clear();
      _confirmarController.clear();
    } on AuthException {
      setState(() => _error = 'Contraseña actual incorrecta.');
    } catch (e) {
      setState(() => _error = 'Error al cambiar la contraseña.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilActualProvider).valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚙️ Mi Perfil',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          _FormSection(
            titulo: 'Información Personal',
            children: [
              _InfoField(label: 'Email:', valor: perfil?.email ?? ''),
              _InfoField(label: 'Nombre:', valor: perfil?.nombre ?? ''),
              _InfoField(label: 'Rol:', valor: perfil?.rol ?? ''),
            ],
          ),
          const SizedBox(height: 20),
          _FormSection(
            titulo: 'Cambiar Contraseña',
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _campo('Contraseña Actual:', _actualController),
                    const SizedBox(height: 16),
                    _campo('Nueva Contraseña:', _nuevaController),
                    const SizedBox(height: 16),
                    _campo('Confirmar Nueva Contraseña:', _confirmarController),
                    const SizedBox(height: 16),
                    if (_error != null) _mensaje(_error!, exito: false),
                    if (_exito != null) _mensaje(_exito!, exito: true),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _cambiarPassword,
                        child: _guardando
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('🔐 Cambiar Contraseña'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _campo(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(controller: controller, obscureText: true),
      ],
    );
  }

  Widget _mensaje(String texto, {required bool exito}) {
    final color = exito ? AppColors.success : AppColors.error;
    final bg = exito ? const Color(0xFFE8F8F5) : const Color(0xFFFDEAEA);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Text(texto, style: TextStyle(color: color, fontSize: 13)),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String titulo;
  final List<Widget> children;

  const _FormSection({required this.titulo, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String valor;

  const _InfoField({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          TextSpan(text: valor, style: const TextStyle(color: Color(0xFF5A6C7D))),
        ]),
      ),
    );
  }
}
