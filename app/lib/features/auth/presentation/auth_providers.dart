import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../domain/perfil.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Emite cada cambio de sesión (login/logout/token refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Usuario de Supabase Auth actualmente logueado (o null).
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).valueOrNull;
  return authState?.session?.user ?? ref.watch(authRepositoryProvider).currentUser;
});

/// Perfil de negocio (nombre/rol/activo) del usuario logueado.
final perfilActualProvider = FutureProvider<Perfil?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(authRepositoryProvider).obtenerPerfilActual();
});
