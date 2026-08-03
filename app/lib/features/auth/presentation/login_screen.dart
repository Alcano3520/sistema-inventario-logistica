import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_theme.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _cargando = false;
  bool _passwordVisible = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).signIn(
            emailOUsuario: _emailController.text,
            password: _passwordController.text,
          );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error al iniciar sesión. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '📦 Sistema de Inventario',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Inicie sesión para continuar',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 28),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Usuario o Email:',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'usuario@ejemplo.com',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Ingresa tu usuario o correo' : null,
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Contraseña:',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              icon: Icon(_passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () =>
                                  setState(() => _passwordVisible = !_passwordVisible),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                          onFieldSubmitted: (_) => _iniciarSesion(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDEAEA),
                              borderRadius: BorderRadius.circular(6),
                              border: const Border(
                                  left: BorderSide(color: AppColors.error, width: 4)),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _cargando ? null : _iniciarSesion,
                            child: _cargando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('🔐 Iniciar Sesión'),
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 16),
                        const Text(
                          '🔒 Sistema seguro con encriptación SHA-256',
                          style: TextStyle(color: Color(0xFF95A5A6), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
