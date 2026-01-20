import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/admin_config.dart'; // Para verificar se é admin
import 'admin_register_screen.dart'; // Para navegar para a tela de cadastro

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // --- FUNÇÃO PARA DESLOGAR ---
  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao sair: $e")));
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
                const Text("Por segurança, confirme sua senha atual antes de mudar.", style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Senha Atual", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Nova Senha (Mín 6)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Confirmar Nova Senha", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A nova senha e a confirmação não batem.")));
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A nova senha deve ter no mínimo 6 dígitos.")));
                  return;
                }

                try {
                  showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

                  final user = FirebaseAuth.instance.currentUser;
                  final email = user?.email;

                  if (user != null && email != null) {
                    AuthCredential credential = EmailAuthProvider.credential(email: email, password: currentPasswordController.text);
                    await user.reauthenticateWithCredential(credential);
                    await user.updatePassword(newPasswordController.text);

                    if (context.mounted) {
                      Navigator.pop(context); // Fecha loading
                      Navigator.pop(context); // Fecha dialog
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senha alterada com sucesso!"), backgroundColor: Colors.green));
                    }
                  }
                } on FirebaseAuthException catch (e) {
                  Navigator.pop(context); // Fecha loading
                  String msg = "Erro ao mudar senha.";
                  if (e.code == 'wrong-password') msg = "A senha atual está incorreta.";
                  else if (e.code == 'weak-password') msg = "A nova senha é muito fraca.";
                  
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Scaffold(body: Center(child: Text("Usuário não logado")));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Meu Perfil", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _signOut(context))
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Erro ao carregar perfil."));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          // Se não tiver dados no banco, usa dados básicos do Auth
          final data = snapshot.hasData && snapshot.data!.exists ? snapshot.data!.data() as Map<String, dynamic> : <String, dynamic>{};
          
          String get(String key) => (data[key] ?? "").toString();

          // DADOS PRINCIPAIS
          String nome = get('nome_completo').isNotEmpty ? get('nome_completo') : (user.email ?? "Usuário");
          String fotoUrl = get('foto_url');
          String cargo = get('cargo_atual');
          String oficial = get('oficial_igreja');
          bool isAdmin = get('role') == 'admin';

          // Subtítulo (Cargo / Oficial)
          String subtitulo = cargo.isNotEmpty ? cargo : "Membro";
          if (oficial != "Nenhum" && oficial.isNotEmpty && oficial != "null") subtitulo += " / $oficial";

          return SingleChildScrollView(
            child: Column(
              children: [
                // --- CABEÇALHO (FOTO E NOME) ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  decoration: const BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 51,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: (fotoUrl.isNotEmpty && fotoUrl != "null") ? NetworkImage(fotoUrl) : null,
                          child: (fotoUrl.isEmpty || fotoUrl == "null") ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(nome, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text(subtitulo.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      ),
                      if (isAdmin)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Chip(
                            label: const Text("ADMINISTRADOR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                            backgroundColor: Colors.orange[50],
                            padding: const EdgeInsets.all(0),
                          ),
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // --- ÁREA DE AÇÕES (ADMIN E SENHA) ---
                      if (isAdmin) ...[
                        _buildSectionHeader("Administração"),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person_add, color: Colors.green)),
                            title: const Text("Cadastrar Novo Membro", style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text("Criar login para irmãos"),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRegisterScreen())),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      _buildSectionHeader("Minha Conta"),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.lock, color: Colors.indigo),
                              title: const Text("Alterar Senha"),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showChangePasswordDialog(context),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.logout, color: Colors.red),
                              title: const Text("Sair do Aplicativo", style: TextStyle(color: Colors.red)),
                              onTap: () => _signOut(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- DADOS COMPLETOS (FICHA) ---
                      _buildSectionHeader("Meus Dados"),
                      _buildInfoTile(Icons.badge, "CPF", get('cpf')),
                      _buildInfoTile(Icons.cake, "Nascimento", get('nascimento')),
                      _buildInfoTile(Icons.phone_android, "WhatsApp", get('whatsapp')),
                      _buildInfoTile(Icons.location_on, "Endereço", "${get('endereco')}, ${get('numero')} - ${get('bairro')}"),
                      _buildInfoTile(Icons.location_city, "Cidade", "${get('cidade')} - ${get('uf')}"),
                      
                      const SizedBox(height: 10),
                      _buildSectionHeader("Eclesiástico"),
                      _buildInfoTile(Icons.church, "Membro Desde", get('membro_desde')),
                      _buildInfoTile(Icons.groups, "Departamento", get('departamento')),
                      _buildInfoTile(Icons.water_drop, "Batismo", get('batismo_aguas')),
                      
                      const SizedBox(height: 10),
                      _buildSectionHeader("Família"),
                      _buildInfoTile(Icons.favorite, "Estado Civil", get('estado_civil')),
                      _buildInfoTile(Icons.person_add, "Cônjuge", get('conjuge')),
                      if (get('filhos').isNotEmpty)
                         Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("👶 Filhos", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)), const SizedBox(height: 5), Text(get('filhos'))]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    if (value.trim().isEmpty || value == "null") return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo[300], size: 22),
        title: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}