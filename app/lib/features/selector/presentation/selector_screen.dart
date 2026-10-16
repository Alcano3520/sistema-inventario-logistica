import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/modulos.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../shared/widgets/app_shell.dart';

class SelectorScreen extends ConsumerWidget {
  const SelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilActualProvider);
    final perfil = perfilAsync.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: AppColors.textOnPrimary, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Inventario Logística Insevig',
                      style: TextStyle(
                          color: AppColors.textOnPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.textOnPrimary),
                    tooltip: 'Salir',
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: perfilAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            perfil != null ? 'Hola, ${perfil.nombre}' : 'Selecciona un inventario',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Elige con qué inventario quieres trabajar.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          if (perfil != null &&
                              !perfil.esAdmin &&
                              !perfil.modulos.any((m) => modulosDisponibles
                                  .any((mod) => mod.clave == m && mod.disponible)))
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: AppColors.errorBg,
                                borderRadius: BorderRadius.circular(6),
                                border: const Border(
                                    left: BorderSide(color: AppColors.error, width: 4)),
                              ),
                              child: const Text(
                                'Tu usuario no tiene acceso a ningún inventario todavía. '
                                'Pide a un administrador que te lo habilite.',
                                style: TextStyle(color: AppColors.error),
                              ),
                            )
                          else
                            Expanded(
                              child: GridView(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  mainAxisExtent: 150,
                                ),
                                children: modulosDisponibles
                                    // Los módulos ya activos se filtran por permiso (el Admin
                                    // siempre ve todos); los que aún no existen se muestran
                                    // como vista previa para todos.
                                    .where((m) =>
                                        !m.disponible ||
                                        perfil == null ||
                                        perfil.esAdmin ||
                                        perfil.modulos.contains(m.clave))
                                    .map((m) => _TarjetaModulo(
                                          modulo: m,
                                          onTap: m.disponible
                                              ? () {
                                                  ref.read(moduloActivoProvider.notifier).state =
                                                      m.clave;
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                        builder: (_) => const AppShell()),
                                                  );
                                                }
                                              : null,
                                        ))
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaModulo extends StatelessWidget {
  final ModuloInfo modulo;
  final VoidCallback? onTap;

  const _TarjetaModulo({required this.modulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final deshabilitado = onTap == null;
    return Opacity(
      opacity: deshabilitado ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: Icon(modulo.icono, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                modulo.titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                deshabilitado ? 'Próximamente' : 'Disponible',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
