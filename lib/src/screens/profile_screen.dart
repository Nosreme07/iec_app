import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/admin_config.dart'; // Para verificar se é admin
import 'admin_register_screen.dart'; // Para navegar para a tela de cadastro

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // --- FUNÇÃO PARA DESLOGAR ---
  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // O StreamBuilder no main.dart vai perceber que saiu e mudará para a tela de Login automaticamente
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro ao sair: $e")));
      }
    }
  }

  // --- FUNÇÃO PARA ALTERAR SENHA ---
  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Alterar Senha"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Por segurança, confirme sua senha atual antes de mudar.",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // SENHA ATUAL
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Senha Atual",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 10),

                // NOVA SENHA
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Nova Senha",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 10),

                // CONFIRMAR NOVA SENHA
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Confirmar Nova Senha",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                // 1. Validações básicas
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("A nova senha e a confirmação não batem."),
                    ),
                  );
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "A nova senha deve ter no mínimo 6 dígitos.",
                      ),
                    ),
                  );
                  return;
                }

                try {
                  // Mostra carregamento
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final user = FirebaseAuth.instance.currentUser;
                  final email = user?.email;

                  if (user != null && email != null) {
                    // 2. REAUTENTICAR (Obrigatório para mudar senha)
                    AuthCredential credential = EmailAuthProvider.credential(
                      email: email,
                      password: currentPasswordController.text,
                    );

                    await user.reauthenticateWithCredential(credential);

                    // 3. ATUALIZAR A SENHA
                    await user.updatePassword(newPasswordController.text);

                    // Fecha o loading e o dialog
                    if (context.mounted) {
                      Navigator.pop(context); // Fecha loading
                      Navigator.pop(context); // Fecha dialog de senha

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Senha alterada com sucesso!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } on FirebaseAuthException catch (e) {
                  Navigator.pop(context); // Fecha loading
                  String msg = "Erro ao mudar senha.";
                  if (e.code == 'wrong-password') {
                    msg = "A senha atual está incorreta.";
                  } else if (e.code == 'weak-password') {
                    msg = "A nova senha é muito fraca.";
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pega os dados do usuário atual
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = AdminConfig.isUserAdmin();
    final String email = user?.email ?? "Não identificado";

    // Tenta mostrar só o CPF (pegando a parte antes do @)
    final String cpfDisplay = email.split('@')[0];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // --- FOTO / ÍCONE DE PERFIL ---
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue[900],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- NOME / CPF ---
              const Text(
                "Usuário",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "CPF: $cpfDisplay",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),

              const SizedBox(height: 10),

              // --- ETIQUETA DE ADMIN (Só aparece se for admin) ---
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Administrador",
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              // --- ÁREA ADMINISTRATIVA ---
              if (isAdmin) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Área Administrativa",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Botão de Cadastrar Membro
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_add, color: Colors.green),
                    ),
                    title: const Text(
                      "Cadastrar Novo Membro",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("Criar login para irmãos da igreja"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminRegisterScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],

              // --- MENU DE OPÇÕES COMUM ---
              _buildProfileOption(Icons.settings, "Configurações", () {}),
              _buildProfileOption(Icons.notifications, "Notificações", () {}),

              // BOTÃO ALTERAR SENHA
              _buildProfileOption(
                Icons.lock,
                "Alterar Senha",
                () => _showChangePasswordDialog(
                  context,
                ), // Agora a função existe!
              ),

              const SizedBox(height: 30),

              // --- BOTÃO SAIR ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _signOut(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    "SAIR DO APLICATIVO",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para criar os itens do menu
  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[900]),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
