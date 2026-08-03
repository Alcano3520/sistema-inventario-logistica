import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/modulos.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/usuarios_repository.dart';
import '../domain/usuario_admin.dart';

final usuariosRepositoryProvider = Provider((ref) => UsuariosRepository());

final usuariosListaProvider =
    AsyncNotifierProvider.autoDispose<UsuariosListaNotifier, List<UsuarioAdmin>>(
        UsuariosListaNotifier.new);

class UsuariosListaNotifier extends AutoDisposeAsyncNotifier<List<UsuarioAdmin>> {
  @override
  Future<List<UsuarioAdmin>> build() {
    return ref.read(usuariosRepositoryProvider).listar();
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(usuariosRepositoryProvider).listar());
  }
}

class UsuariosScreen extends ConsumerWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(usuariosListaProvider);
    final miId = ref.watch(currentUserProvider)?.id;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👥 Gestión de Usuarios',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _mostrarFormularioNuevoUsuario(context, ref),
            child: const Text('➕ Nuevo Usuario'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: usuariosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error al cargar usuarios: $e')),
              data: (usuarios) => RefreshIndicator(
                onRefresh: () => ref.read(usuariosListaProvider.notifier).refrescar(),
                child: SingleChildScrollView(
                  child: _TablaUsuarios(usuarios: usuarios, miId: miId),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarFormularioNuevoUsuario(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => const _NuevoUsuarioDialog());
  }
}

class _TablaUsuarios extends ConsumerWidget {
  final List<UsuarioAdmin> usuarios;
  final String? miId;

  const _TablaUsuarios({required this.usuarios, required this.miId});

  Future<void> _toggleActivo(BuildContext context, WidgetRef ref, UsuarioAdmin u, String? miId) async {
    if (u.id == miId && u.activo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes desactivar tu propia cuenta.')),
      );
      return;
    }
    try {
      await ref.read(usuariosRepositoryProvider).actualizar(id: u.id, activo: !u.activo);
      await ref.read(usuariosListaProvider.notifier).refrescar();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _restablecerPassword(BuildContext context, WidgetRef ref, UsuarioAdmin u) async {
    final controller = TextEditingController();
    String? error;
    final nueva = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Restablecer contraseña de ${u.nombre}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Mínimo 6 caracteres'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.length < 6) {
                    setState(() => error = 'La contraseña debe tener al menos 6 caracteres.');
                    return;
                  }
                  Navigator.of(context).pop(controller.text);
                },
                child: const Text('Restablecer'),
              ),
            ],
          );
        },
      ),
    );
    if (nueva == null) return;
    try {
      await ref.read(usuariosRepositoryProvider).restablecerPassword(id: u.id, nuevaPassword: nueva);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Contraseña restablecida.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _editarModulos(BuildContext context, WidgetRef ref, UsuarioAdmin u) async {
    final seleccion = Set<String>.of(u.modulos);
    final nuevos = await showDialog<Set<String>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Accesos de ${u.nombre}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: modulosDisponibles
                  .map((m) => CheckboxListTile(
                        value: seleccion.contains(m.clave),
                        title: Text('${m.emoji} ${m.titulo}'),
                        subtitle: m.disponible ? null : const Text('Próximamente'),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            seleccion.add(m.clave);
                          } else {
                            seleccion.remove(m.clave);
                          }
                        }),
                      ))
                  .toList(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(seleccion),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (nuevos == null) return;
    try {
      await ref
          .read(usuariosRepositoryProvider)
          .actualizar(id: u.id, modulos: nuevos.toList());
      await ref.read(usuariosListaProvider.notifier).refrescar();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, UsuarioAdmin u) async {
    final confirmado1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar usuario?'),
        content: Text('Esta acción eliminará a ${u.nombre} (${u.email}) permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmado1 != true || !context.mounted) return;

    final confirmado2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Confirmación final'),
        content: const Text('Esta acción NO se puede deshacer. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, eliminar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmado2 != true) return;

    try {
      await ref.read(usuariosRepositoryProvider).eliminar(u.id);
      await ref.read(usuariosListaProvider.notifier).refrescar();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: usuarios
                .map((u) => _TarjetaUsuario(
                      usuario: u,
                      esUno: u.id == miId,
                      onToggleActivo: () => _toggleActivo(context, ref, u, miId),
                      onRestablecerPassword: () => _restablecerPassword(context, ref, u),
                      onEditarModulos: () => _editarModulos(context, ref, u),
                      onEliminar: () => _eliminar(context, ref, u),
                    ))
                .toList(),
          );
        }
        return _tabla(context, ref);
      },
    );
  }

  Widget _tabla(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FA)),
          columns: const [
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Nombre')),
            DataColumn(label: Text('Usuario')),
            DataColumn(label: Text('Rol')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: usuarios.map((u) {
            return DataRow(cells: [
              DataCell(Text(u.email)),
              DataCell(Text(u.nombre)),
              DataCell(Text(u.usuario)),
              DataCell(Text(u.rol)),
              DataCell(Text(
                u.activo ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  color: u.activo ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              )),
              DataCell(Row(
                children: [
                  IconButton(
                    tooltip: u.activo ? 'Desactivar' : 'Activar',
                    icon: Icon(u.activo ? Icons.toggle_on : Icons.toggle_off,
                        color: AppColors.warning),
                    onPressed: () => _toggleActivo(context, ref, u, miId),
                  ),
                  IconButton(
                    tooltip: 'Restablecer contraseña',
                    icon: const Icon(Icons.lock_reset, color: AppColors.info),
                    onPressed: () => _restablecerPassword(context, ref, u),
                  ),
                  IconButton(
                    tooltip: 'Accesos a inventarios',
                    icon: const Icon(Icons.apps, color: AppColors.primary),
                    onPressed: () => _editarModulos(context, ref, u),
                  ),
                  if (u.id != miId)
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => _eliminar(context, ref, u),
                    ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  final UsuarioAdmin usuario;
  final bool esUno;
  final VoidCallback onToggleActivo;
  final VoidCallback onRestablecerPassword;
  final VoidCallback onEditarModulos;
  final VoidCallback onEliminar;

  const _TarjetaUsuario({
    required this.usuario,
    required this.esUno,
    required this.onToggleActivo,
    required this.onRestablecerPassword,
    required this.onEditarModulos,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usuario.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(usuario.email,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: usuario.activo
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  usuario.activo ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: usuario.activo ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text('Usuario: ${usuario.usuario}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('Rol: ${usuario.rol}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(
                'Acceso: ${usuario.modulos.isEmpty ? "ninguno" : usuario.modulos.join(", ")}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: onToggleActivo,
                icon: Icon(usuario.activo ? Icons.toggle_on : Icons.toggle_off,
                    color: AppColors.warning),
                label: Text(usuario.activo ? 'Desactivar' : 'Activar'),
              ),
              TextButton.icon(
                onPressed: onRestablecerPassword,
                icon: const Icon(Icons.lock_reset, color: AppColors.info),
                label: const Text('Contraseña'),
              ),
              TextButton.icon(
                onPressed: onEditarModulos,
                icon: const Icon(Icons.apps, color: AppColors.primary),
                label: const Text('Accesos'),
              ),
              if (!esUno)
                TextButton.icon(
                  onPressed: onEliminar,
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  label: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NuevoUsuarioDialog extends ConsumerStatefulWidget {
  const _NuevoUsuarioDialog();

  @override
  ConsumerState<_NuevoUsuarioDialog> createState() => _NuevoUsuarioDialogState();
}

class _NuevoUsuarioDialogState extends ConsumerState<_NuevoUsuarioDialog> {
  final _emailController = TextEditingController();
  final _nombreController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  String _rol = 'Operador';
  final Set<String> _modulos = {'barcos'};
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _nombreController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(usuariosRepositoryProvider).crear(
            email: _emailController.text.trim(),
            nombre: _nombreController.text.trim(),
            usuario: _usuarioController.text.trim(),
            password: _passwordController.text,
            rol: _rol,
            modulos: _modulos.toList(),
          );
      await ref.read(usuariosListaProvider.notifier).refrescar();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Nuevo Usuario'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email *', hintText: 'usuario@ejemplo.com'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre Completo *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usuarioController,
              decoration: const InputDecoration(labelText: 'Nombre de Usuario *', hintText: 'usuario123'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña *', hintText: 'Mínimo 6 caracteres'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _rol,
              decoration: const InputDecoration(labelText: 'Rol *'),
              items: const [
                DropdownMenuItem(value: 'Operador', child: Text('Operador')),
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() => _rol = v ?? 'Operador'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Acceso a inventarios:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
            ),
            ...modulosDisponibles.map((m) => CheckboxListTile(
                  value: _modulos.contains(m.clave),
                  title: Text('${m.emoji} ${m.titulo}'),
                  subtitle: m.disponible ? null : const Text('Próximamente'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _modulos.add(m.clave);
                    } else {
                      _modulos.remove(m.clave);
                    }
                  }),
                )),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('❌ Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _crear,
          child: _guardando
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('💾 Crear Usuario'),
        ),
      ],
    );
  }
}
