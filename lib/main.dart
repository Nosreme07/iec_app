import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'src/screens/home_screen.dart';
import 'src/screens/login_screen.dart';
// import 'src/utils/theme.dart'; // Se você tiver esse arquivo, pode descomentar

void main() async {
  // 1. Garante que o motor do Flutter carregou antes de chamar códigos nativos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa o Firebase (Conecta ao google-services.json)
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IEC App',

      // Definição do Tema (Visual do App)
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        // Cor da AppBar padrão
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D47A1), // Azul 900 (igual da Home)
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // --- GERENCIADOR DE ESTADO DE LOGIN ---
      // O StreamBuilder fica ouvindo o Firebase Auth o tempo todo.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Enquanto verifica se está logado, mostra um carregamento
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Se deu erro (ex: sem internet), mostra mensagem
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao conectar no sistema"));
          }

          // 3. Se tem dados (usuário logado), vai para a HOME
          if (snapshot.hasData) {
            return const HomeScreen();
          }

          // 4. Se não tem dados (usuário deslogado), vai para o LOGIN
          return const LoginScreen();
        },
      ),
    );
  }
}
