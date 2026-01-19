import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Instância do Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Função para Login
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Erro no login: $e");
      return null;
    }
  }

  // Função para Registar (Criar conta)
  Future<User?> register(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Erro no registo: $e");
      return null;
    }
  }

  // Sair (Logout)
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
