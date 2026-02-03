import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Para identificar se é Web
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // <--- IMPORTANTE: Adicionei isso

// Importações das suas telas
import 'src/screens/home_screen.dart';
import 'src/screens/login_screen.dart';

// NÃO PRECISA MAIS DO IMPORT DO SERVICE
// import 'src/services/notification_service.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializa o Firebase de acordo com a plataforma
  if (kIsWeb) {
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
    await Firebase.initializeApp();
  }

  // 2. CONFIGURAÇÃO DE NOTIFICAÇÃO (SIMPLIFICADA)
  // Isso garante que quem abrir o app vai receber os avisos do site
  try {
    final fcm = FirebaseMessaging.instance;
    
    // Pede permissão (obrigatório para Android 13+ e iOS)
    await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Inscreve no tópico "todos"
    await fcm.subscribeToTopic('todos');
    print("✅ Sucesso: App inscrito para receber avisos do tópico 'todos'");
  } catch (e) {
    print("❌ Erro ao configurar notificações: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IECM App',

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

      // Gerenciamento de Estado de Login
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text("Erro ao conectar no sistema")),
            );
          }

          // Se o usuário estiver logado, vai para Home, senão, Login
          if (snapshot.hasData) {
            return const HomeScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}