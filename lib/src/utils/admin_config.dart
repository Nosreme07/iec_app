import 'package:firebase_auth/firebase_auth.dart';

class AdminConfig {
  // --- LISTA DE ADMINISTRADORES ---
  // Adicione aqui os CPFs de quem pode editar (apenas números)
  static const List<String> adminCpfs = [
    "09438323490", // Seu CPF (Admin Principal)
    "11122233344", // Ex: CPF da Secretária
    "55566677788", // Ex: CPF do Líder de Louvor
  ];

  static const String emailSuffix = "@iec.com";

  // Função INTELIGENTE: Verifica se quem está logado está na lista acima
  static bool isUserAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;

    // Verifica se o email do usuário bate com algum CPF da lista
    for (String cpf in adminCpfs) {
      if (user.email == "$cpf$emailSuffix") {
        return true; // Encontrou! É admin.
      }
    }

    return false; // Não está na lista.
  }

  // Gera o email para login
  static String getEmailFromCpf(String cpf) {
    String cleanCpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    return "$cleanCpf$emailSuffix";
  }
}
