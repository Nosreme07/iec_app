import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/admin_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controles de Login
  final _cpfLoginController = TextEditingController();
  final _passwordLoginController = TextEditingController();

  // Controles de Cadastro (Modal)
  final _nameRegController = TextEditingController();
  final _cpfRegController = TextEditingController();
  final _phoneRegController = TextEditingController();
  final _passwordRegController = TextEditingController();

  bool _isLoading = false;
  bool _isObscureLogin = true;
  bool _isObscureReg = true;
  
  // Variável específica para o modal de cadastro
  bool _isRegistering = false; 

  // --- 1. SUPORTE WHATSAPP ---
  Future<void> _falarComDesenvolvedor({String? mensagemPersonalizada}) async {
    const telefone = "5581995065696";
    final texto = mensagemPersonalizada ??
        "Olá Emerson, preciso de suporte no App IEC Moreno.";
    final Uri whatsappUri =
        Uri.parse("https://wa.me/$telefone?text=${Uri.encodeComponent(texto)}");

    if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      _showMsg("Não foi possível abrir o WhatsApp.");
    }
  }

  // --- 2. LÓGICA DE LOGIN ---
  Future<void> _login() async {
    if (_cpfLoginController.text.isEmpty ||
        _passwordLoginController.text.isEmpty) {
      _showMsg("Preencha CPF e Senha");
      return;
    }
    setState(() => _isLoading = true);
    try {
      String emailInterno =
          AdminConfig.getEmailFromCpf(_cpfLoginController.text.trim());
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailInterno,
        password: _passwordLoginController.text.trim(),
      );
    } catch (e) {
      _showMsg("Acesso negado. Verifique seus dados.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 3. ESQUECI MINHA SENHA ---
  void _esqueciSenhaSimplificado() {
    if (_cpfLoginController.text.isEmpty) {
      _showMsg("Por favor, digite seu CPF no campo acima primeiro.");
      return;
    }

    final cpf = _cpfLoginController.text.trim();
    final mensagem =
        "Olá Emerson! Esqueci minha senha do App IEC Moreno.\n\n👤 Meu CPF é: $cpf\n🔑 Poderia zerar meu acesso?";

    _falarComDesenvolvedor(mensagemPersonalizada: mensagem);
  }

  // --- 4. CADASTRO DE VISITANTE ---
  Future<void> _cadastrarVisitante(StateSetter setModalState) async {
    if (_isRegistering) return;

    if (_nameRegController.text.isEmpty ||
        _cpfRegController.text.isEmpty ||
        _phoneRegController.text.isEmpty ||
        _passwordRegController.text.length < 6) {
      _showMsg("Preencha tudo corretamente. Senha mín. 6 caracteres.");
      return;
    }
    
    setModalState(() => _isRegistering = true);
    
    try {
      String emailInterno =
          AdminConfig.getEmailFromCpf(_cpfRegController.text.trim());
      UserCredential userCred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailInterno,
        password: _passwordRegController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .set({
        'nome_completo': _nameRegController.text.trim(),
        'cpf': _cpfRegController.text.trim(),
        'whatsapp': _phoneRegController.text.trim(),
        'role': 'visitante',
        'cargo_atual': 'Visitante',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); 
        _showMsg("Cadastro realizado! Seja bem-vindo.", color: Colors.green);
      }
    } catch (e) {
      _showMsg("Erro: CPF já cadastrado ou dados inválidos.");
    } finally {
      if (mounted) setModalState(() => _isRegistering = false);
    }
  }

  // --- 5. MODAL DE CADASTRO ---
  void _mostrarModalCadastro() {
    _isRegistering = false; 
    _nameRegController.clear();
    _cpfRegController.clear();
    _phoneRegController.clear();
    _passwordRegController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Novo Visitante",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                    controller: _nameRegController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: "Nome Completo",
                        border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(
                  controller: _cpfRegController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: "CPF (Apenas números)",
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                // --- CAMPO DO WHATSAPP COM A MÁSCARA ---
                TextField(
                    controller: _phoneRegController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _TelefoneFormatter(), // Chama a máscara customizada
                    ],
                    decoration: const InputDecoration(
                        labelText: "WhatsApp para contato",
                        hintText: "(81) 99999-9999",
                        border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordRegController,
                  obscureText: _isObscureReg,
                  decoration: InputDecoration(
                    labelText: "Crie uma Senha",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isObscureReg
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setModalState(() => _isObscureReg = !_isObscureReg),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isRegistering ? null : () => _cadastrarVisitante(setModalState),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E4C9D),
                        disabledBackgroundColor: Colors.grey[400]),
                    child: _isRegistering
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text("CADASTRAR",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMsg(String msg, {Color color = Colors.red}) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4169E1), Color(0xFF2E4C9D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset('assets/images/logo.png',
                    height: 100,
                    errorBuilder: (c, e, s) => const Icon(Icons.church,
                        size: 80, color: Colors.white)),
                const SizedBox(height: 10),
                const Text("IEC Moreno",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),

                // CARD DE LOGIN
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      const Text("Acesso de Membros",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _cpfLoginController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                            labelText: "CPF (apenas números)",
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passwordLoginController,
                        obscureText: _isObscureLogin,
                        decoration: InputDecoration(
                          labelText: "Senha",
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_isObscureLogin
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setState(
                                () => _isObscureLogin = !_isObscureLogin),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _esqueciSenhaSimplificado,
                          child: const Text("Esqueci minha senha",
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E4C9D),
                              disabledBackgroundColor: Colors.grey[400]),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("ENTRAR",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),
                OutlinedButton(
                  onPressed: _mostrarModalCadastro,
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15)),
                  child: const Text("NÃO TENHO CADASTRO / CRIAR CONTA",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 50),

                // RODAPÉ COM SUPORTE
                Column(
                  children: [
                    const Text("Desenvolvido por Emerson Fernandes",
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: () => _falarComDesenvolvedor(),
                      child: const Text(
                        "Suporte: (81) 99506-5696",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// MÁSCARA CUSTOMIZADA PARA WHATSAPP
// ==========================================
class _TelefoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Pegamos apenas os números limpos do que o usuário digitou
    String numLimpo = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limita a 11 dígitos no total (DDD + 9 + 8 dígitos)
    if (numLimpo.length > 11) {
      numLimpo = numLimpo.substring(0, 11);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < numLimpo.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == 7) buffer.write('-');
      buffer.write(numLimpo[i]);
    }

    final textoFormatado = buffer.toString();

    // Retorna o texto formatado mantendo o cursor sempre no final
    return TextEditingValue(
      text: textoFormatado,
      selection: TextSelection.collapsed(offset: textoFormatado.length),
    );
  }
}