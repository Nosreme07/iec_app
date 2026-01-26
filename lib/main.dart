import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Para identificar se é Web
import 'package:flutter_localizations/flutter_localizations.dart'; 

import 'src/screens/home_screen.dart';
import 'src/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // --- CONFIGURAÇÃO WEB (COM SEUS DADOS REAIS) ---
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBWd0S5qU0XtqjaoQPHfDNkjKTjW9BXCqY",
        appId: "1:1093422329001:web:47e10f268a6e1a4a57cdb8",
        messagingSenderId: "1093422329001",
        projectId: "iec-app-1c3ac",
        storageBucket: "iec-app-1c3ac.firebasestorage.app",
      ),
    );
  } else {
    // --- CONFIGURAÇÃO ANDROID (AUTOMÁTICA) ---
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IECM',

      // Configuração de Idioma (PT-BR)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'), 
      ],

      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D47A1), 
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao conectar no sistema"));
          }

          if (snapshot.hasData) {
            return const HomeScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}