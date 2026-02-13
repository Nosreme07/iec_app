import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/admin_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cpfController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _login() async {
    if (_cpfController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Preencha CPF e Senha")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = AdminConfig.getEmailFromCpf(_cpfController.text);
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      // O main.dart redireciona automaticamente
    } on FirebaseAuthException catch (e) {
      String message = "Erro ao fazer login.";
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        message = "CPF ou senha incorretos.";
      } else if (e.code == 'invalid-email') {
        message = "CPF inválido.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Esqueceu a senha?"),
          content: const Text(
            "Como o sistema utiliza logins baseados em CPF, não é possível enviar e-mail de recuperação.\n\n"
            "Por favor, procure a secretaria da igreja ou o administrador (Pastor/Líder) para que eles criem uma nova senha para você.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Entendi"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- BACKGROUND COM DEGRADÊ (CORES DO ÍCONE) ---
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6495ED), // Azul Cornflower (Topo - Mais claro)
              Color(0xFF4169E1), // Azul Royal (Meio)
              Color(0xFF2E4C9D), // Azul Escuro Profundo (Fundo)
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- LOGO DA IGREJA ---
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.church,
                          size: 100, color: Colors.white);
                    },
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "IEC Moreno",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                            color: Colors.black45,
                            offset: Offset(2, 2),
                            blurRadius: 4)
                      ]),
                ),
                const SizedBox(height: 40),

                // --- CARD DE LOGIN ---
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Bem-vindo",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900], // Cor do texto ajustada
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _cpfController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "CPF (apenas números)",
                          prefixIcon: Icon(Icons.person_outline,
                              color: Colors.blue[800]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.blue[800]!, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        obscureText: _isObscure,
                        decoration: InputDecoration(
                          labelText: "Senha",
                          prefixIcon:
                              Icon(Icons.lock_outline, color: Colors.blue[800]),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _isObscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.grey),
                            onPressed: () =>
                                setState(() => _isObscure = !_isObscure),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.blue[800]!, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text("Esqueci a senha",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900])),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            // Botão combinando com o fundo
                            backgroundColor: const Color(0xFF2E4C9D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  "ENTRAR",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                Text(
                  "Versão 1.0.0\nDesenvolvido por Emerson Fernandes",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
