import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/modulos.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/carga_masiva/presentation/carga_masiva_screen.dart';
import '../../features/carga_masiva/presentation/migracion_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/general/presentation/ajuste_stock_general_screen.dart';
import '../../features/general/presentation/articulos_general_screen.dart';
import '../../features/general/presentation/carga_masiva_general_screen.dart';
import '../../features/general/presentation/correcciones_general_screen.dart';
import '../../features/general/presentation/dashboard_general_screen.dart';
import '../../features/general/presentation/descuentos_general_screen.dart';
import '../../features/general/presentation/devolucion_general_screen.dart';
import '../../features/general/presentation/entrega_general_screen.dart';
import '../../features/general/presentation/historial_general_screen.dart';
import '../../features/general/presentation/inventario_general_screen.dart';
import '../../features/general/presentation/reportes_general_screen.dart';
import '../../features/historial/presentation/historial_screen.dart';
import '../../features/movimientos/presentation/entrada_screen.dart';
import '../../features/movimientos/presentation/salida_screen.dart';
import '../../features/perfil/presentation/mi_perfil_screen.dart';
import '../../features/productos/presentation/inventario_screen.dart';
import '../../features/productos/presentation/productos_screen.dart';
import '../../features/taller_motos/presentation/ordenes_trabajo_screen.dart';
import '../../features/usuarios/presentation/usuarios_screen.dart';

class _TabDef {
  final IconData icono;
  final String titulo;
  final Widget screen;

  const _TabDef(this.icono, this.titulo, this.screen);
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// El Mecánico solo puede crear pedidos (OT) y ver su propio historial:
  /// nada de Entrada/Salida/Inventario/Dashboard/Usuarios.
  List<_TabDef> _construirTabsMecanico(String claveModulo) {
    return [
      if (_tieneTaller(claveModulo)) const _TabDef(Icons.build_outlined, 'Mis Pedidos', OrdenesTrabajoScreen()),
      const _TabDef(Icons.person_outline, 'Mi Perfil', MiPerfilScreen()),
    ];
  }

  /// Taller/repuestos/mantenimiento anti-robo: disponible en Barcos y Motos
  /// (comparten pantallas, cada uno contra sus propias tablas).
  bool _tieneTaller(String claveModulo) => claveModulo == 'motos' || claveModulo == 'barcos';

  List<_TabDef> _construirTabsSimple(bool esAdmin, bool mostrarUsuarios, String claveModulo) {
    return [
      const _TabDef(Icons.dashboard_outlined, 'Dashboard', DashboardScreen()),
      const _TabDef(Icons.call_received, 'Entrada', EntradaScreen()),
      const _TabDef(Icons.call_made, 'Salida', SalidaScreen()),
      const _TabDef(Icons.inventory_2_outlined, 'Inventario', InventarioScreen()),
      // Cualquiera puede ingresar/buscar productos (bodeguero incluido) —
      // el único que no ve esta pestaña es el Mecánico, que ya tiene su
      // propio menú restringido (_construirTabsMecanico) y nunca llega aquí.
      const _TabDef(Icons.add_box_outlined, 'Productos', ProductosScreen()),
      const _TabDef(Icons.history, 'Historial', HistorialScreen()),
      if (_tieneTaller(claveModulo)) const _TabDef(Icons.build_outlined, 'Taller', OrdenesTrabajoScreen()),
      if (esAdmin) const _TabDef(Icons.upload_file_outlined, 'Carga Masiva', CargaMasivaScreen()),
      if (esAdmin) const _TabDef(Icons.sync_alt, 'Migración', MigracionScreen()),
      if (mostrarUsuarios) const _TabDef(Icons.people_outline, 'Usuarios', UsuariosScreen()),
      const _TabDef(Icons.person_outline, 'Mi Perfil', MiPerfilScreen()),
    ];
  }

  List<_TabDef> _construirTabsDotacion(bool esAdmin, bool mostrarUsuarios) {
    return [
      const _TabDef(Icons.dashboard_outlined, 'Dashboard', DashboardGeneralScreen()),
      const _TabDef(Icons.receipt_long_outlined, 'Entregas', EntregaGeneralScreen()),
      const _TabDef(Icons.assignment_return_outlined, 'Devoluciones', DevolucionGeneralScreen()),
      const _TabDef(Icons.inventory_2_outlined, 'Inventario', InventarioGeneralScreen()),
      if (esAdmin) const _TabDef(Icons.add_box_outlined, 'Artículos', ArticulosGeneralScreen()),
      const _TabDef(Icons.history, 'Historial', HistorialGeneralScreen()),
      if (esAdmin) const _TabDef(Icons.tune, 'Ajuste Stock', AjusteStockGeneralScreen()),
      if (esAdmin) const _TabDef(Icons.upload_file_outlined, 'Carga Masiva', CargaMasivaGeneralScreen()),
      if (esAdmin) const _TabDef(Icons.build_circle_outlined, 'Correcciones', CorreccionesGeneralScreen()),
      if (esAdmin) const _TabDef(Icons.payments_outlined, 'Descuentos', DescuentosGeneralScreen()),
      const _TabDef(Icons.description_outlined, 'Reportes', ReportesGeneralScreen()),
      if (mostrarUsuarios) const _TabDef(Icons.people_outline, 'Usuarios', UsuariosScreen()),
      const _TabDef(Icons.person_outline, 'Mi Perfil', MiPerfilScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(perfilActualProvider);
    final perfil = perfilAsync.valueOrNull;

    if (perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final claveModulo = ref.watch(moduloActivoProvider);
    final moduloInfo = modulosDisponibles.firstWhere(
      (m) => m.clave == claveModulo,
      orElse: () => modulosDisponibles.first,
    );
    final tabs = perfil.esMecanico && moduloInfo.tipo != TipoModulo.dotacion
        ? _construirTabsMecanico(claveModulo)
        : moduloInfo.tipo == TipoModulo.dotacion
            ? _construirTabsDotacion(perfil.esAdmin, perfil.puedeGestionarUsuarios)
            : _construirTabsSimple(perfil.esAdmin, perfil.puedeGestionarUsuarios, claveModulo);
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
              rol: perfil.rol,
              icono: tabs[_index].icono,
              tituloSeccion: tabs[_index].titulo,
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
    final claveModulo = ref.watch(moduloActivoProvider);
    final modulo = modulosDisponibles.firstWhere(
      (m) => m.clave == claveModulo,
      orElse: () => modulosDisponibles.first,
    );

    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 22,
              left: 20,
              right: 20,
              bottom: 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(modulo.icono, color: AppColors.textOnPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(modulo.titulo,
                          style: const TextStyle(
                              color: AppColors.textOnPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(nombre,
                    style: const TextStyle(color: AppColors.textOnPrimary, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(rol,
                      style: const TextStyle(
                          color: AppColors.textOnPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
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
                  leading: Icon(t.icono,
                      size: 20, color: seleccionado ? AppColors.primary : AppColors.textSecondary),
                  title: Text(t.titulo,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
                          color: seleccionado ? AppColors.primary : AppColors.textPrimary)),
                  selected: seleccionado,
                  selectedTileColor: AppColors.primarySoft,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: () => onSeleccionar(i),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error, size: 20),
              title: const Text('Salir', style: TextStyle(color: AppColors.error, fontSize: 14)),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String rol;
  final IconData icono;
  final String tituloSeccion;
  final VoidCallback onMenuTap;

  const _Header({
    required this.rol,
    required this.icono,
    required this.tituloSeccion,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textOnPrimary),
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).pop(),
            ),
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textOnPrimary),
            onPressed: onMenuTap,
          ),
          Icon(icono, color: AppColors.textOnPrimary, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tituloSeccion,
              style: const TextStyle(
                  color: AppColors.textOnPrimary, fontSize: 17, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(rol,
                style: const TextStyle(
                    color: AppColors.textOnPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
