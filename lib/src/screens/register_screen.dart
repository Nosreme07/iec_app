import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // --- 1. SALVAR DADOS NO FIRESTORE (ATUALIZADO) ---
  Future<void> _saveUserToFirestore(User user, String nome) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'nome_completo': nome,
      'email': user.email,
      'telefone': user.phoneNumber,
      // --- MUDANÇA AQUI: Agora começa como visitante ---
      'role': 'visitante',
      'cargo_atual': 'Visitante',
      'oficial_igreja': 'NENHUM',
      // ------------------------------------------------
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- 2. CADASTRO POR E-MAIL ---
  Future<void> _registerWithEmail() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.length < 6) {
      _showSnackBar(
          "Preencha todos os campos (Senha mín. 6 caracteres).", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _saveUserToFirestore(credential.user!, _nameController.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Erro no cadastro: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 3. CADASTRO/LOGIN GOOGLE ---
  Future<void> _registerWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Salva no Firestore como Visitante
      await _saveUserToFirestore(
          userCred.user!, userCred.user!.displayName ?? "Novo Visitante");

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Erro Google: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Criar Conta"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.person_add_outlined,
                size: 80, color: Color(0xFF2E4C9D)),
            const SizedBox(height: 10),
            const Text(
              "Seja bem-vindo à IEC Moreno!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              "Cadastre-se para acessar nossa comunidade.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // FORMULÁRIO DE E-MAIL
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: "Nome Completo",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 15),
            TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: "E-mail",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email))),
            const SizedBox(height: 15),
            TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: "Crie uma Senha",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerWithEmail,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E4C9D)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("CADASTRAR POR E-MAIL",
                        style: TextStyle(color: Colors.white)),
              ),
            ),

            const SizedBox(height: 30),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("OU")),
              Expanded(child: Divider())
            ]),
            const SizedBox(height: 30),

            // BOTÃO GOOGLE
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _registerWithGoogle,
              icon: const Icon(Icons.g_mobiledata, color: Colors.red, size: 30),
              label: const Text("Cadastrar com Google"),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}
