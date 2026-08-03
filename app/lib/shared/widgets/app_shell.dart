import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/carga_masiva/presentation/carga_masiva_screen.dart';
import '../../features/carga_masiva/presentation/migracion_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/historial/presentation/historial_screen.dart';
import '../../features/movimientos/presentation/entrada_screen.dart';
import '../../features/movimientos/presentation/salida_screen.dart';
import '../../features/perfil/presentation/mi_perfil_screen.dart';
import '../../features/productos/presentation/inventario_screen.dart';
import '../../features/productos/presentation/productos_screen.dart';
import '../../features/usuarios/presentation/usuarios_screen.dart';

class _TabDef {
  final String emoji;
  final String titulo;
  final Widget screen;

  const _TabDef(this.emoji, this.titulo, this.screen);
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<_TabDef> _construirTabs(bool esAdmin) {
    return [
      const _TabDef('📊', 'Dashboard', DashboardScreen()),
      const _TabDef('📥', 'Entrada', EntradaScreen()),
      const _TabDef('📤', 'Salida', SalidaScreen()),
      const _TabDef('📋', 'Inventario', InventarioScreen()),
      if (esAdmin) const _TabDef('➕', 'Productos', ProductosScreen()),
      const _TabDef('📜', 'Historial', HistorialScreen()),
      if (esAdmin) const _TabDef('📂', 'Carga Masiva', CargaMasivaScreen()),
      if (esAdmin) const _TabDef('🔄', 'Migración', MigracionScreen()),
      if (esAdmin) const _TabDef('👥', 'Usuarios', UsuariosScreen()),
      const _TabDef('⚙️', 'Mi Perfil', MiPerfilScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(perfilActualProvider);
    final perfil = perfilAsync.valueOrNull;

    if (perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = _construirTabs(perfil.esAdmin);
    if (_index >= tabs.length) _index = 0;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _MenuLateral(
        tabs: tabs,
        indiceActual: _index,
        nombre: perfil.nombre,
        rol: perfil.rol,
        onSeleccionar: (i) {
          setState(() => _index = i);
          Navigator.of(context).pop();
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              nombre: perfil.nombre,
              rol: perfil.rol,
              tituloSeccion: '${tabs[_index].emoji} ${tabs[_index].titulo}',
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: tabs.map((t) => t.screen).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuLateral extends ConsumerWidget {
  final List<_TabDef> tabs;
  final int indiceActual;
  final String nombre;
  final String rol;
  final ValueChanged<int> onSeleccionar;

  const _MenuLateral({
    required this.tabs,
    required this.indiceActual,
    required this.nombre,
    required this.rol,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📦 INVENTARIO_BARCOS',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(rol,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: tabs.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                final seleccionado = i == indiceActual;
                return ListTile(
                  leading: Text(t.emoji, style: const TextStyle(fontSize: 20)),
                  title: Text(t.titulo,
                      style: TextStyle(
                          fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
                          color: seleccionado ? AppColors.primary : AppColors.textPrimary)),
                  selected: seleccionado,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                  onTap: () => onSeleccionar(i),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Salir', style: TextStyle(color: AppColors.error)),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String nombre;
  final String rol;
  final String tituloSeccion;
  final VoidCallback onMenuTap;

  const _Header({
    required this.nombre,
    required this.rol,
    required this.tituloSeccion,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).pop(),
            ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: onMenuTap,
          ),
          Expanded(
            child: Text(
              tituloSeccion,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(rol,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
