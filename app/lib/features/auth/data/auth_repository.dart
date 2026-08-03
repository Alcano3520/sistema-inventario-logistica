import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_config.dart';
import '../domain/perfil.dart';

class AuthRepository {
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  User? get currentUser => supabase.auth.currentUser;

  /// Acepta correo electrónico o el nombre de usuario corto (ej. "admin").
  Future<void> signIn({required String emailOUsuario, required String password}) async {
    final input = emailOUsuario.trim();
    String email = input;

    if (!input.contains('@')) {
      final resuelto = await supabase.rpc('inv_resolver_email', params: {'p_usuario': input});
      if (resuelto == null) {
        throw const AuthException('Usuario no encontrado.');
      }
      email = resuelto as String;
    }

    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => supabase.auth.signOut();

  Future<void> changePassword(String newPassword) async {
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<Perfil?> obtenerPerfilActual() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await supabase
        .from('inv_perfiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return Perfil.fromMap(data, email: user.email ?? '');
  }
}
