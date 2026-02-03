// ARQUIVO: lib/src/services/push_notification_api.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class PushNotificationApi {
  
  // -----------------------------------------------------------
  // 1. CONFIGURAÇÃO DE INICIALIZAÇÃO (QUEM RECEBE)
  // -----------------------------------------------------------
  static Future<void> init() async {
    final firebaseMessaging = FirebaseMessaging.instance;

    // Pede permissão para mandar notificação (obrigatório no iOS e Android 13+)
    NotificationSettings settings = await firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Permissão de notificação concedida!');
      
      // Inscreve o dispositivo no tópico "todos".
      // Assim, quando enviarmos para "/topics/todos", este celular receberá.
      await firebaseMessaging.subscribeToTopic('todos');
      print('Inscrito no tópico: todos');
    } else {
      print('Permissão negada.');
    }
  }

  // -----------------------------------------------------------
  // 2. LÓGICA DE ENVIO (QUEM MANDA)
  // -----------------------------------------------------------
  static Future<void> sendNotificationToAll({
    required String title,
    required String body,
  }) async {
    // ⚠️ IMPORTANTE: Pegue essa chave no Console do Firebase:
    // Configurações do Projeto > Cloud Messaging > "Chave do servidor" (Cloud Messaging API (Legacy))
    // Se não estiver ativado, clique nos 3 pontinhos e "Gerenciar API" para ativar.
    const String serverKey = 'COLE_SUA_SERVER_KEY_DO_FIREBASE_AQUI'; 
    
    const String endpoint = 'https://fcm.googleapis.com/fcm/send';

    final data = {
      "to": "/topics/todos", // Deve ser igual ao tópico do init()
      "notification": {
        "title": title,
        "body": body,
        "sound": "default"
      },
      "priority": "high",
      "data": {
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "type": "geral",
        "status": "done"
      }
    };

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        body: jsonEncode(data),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
      );

      if (response.statusCode == 200) {
        print("Push enviado com sucesso!");
      } else {
        print("Falha ao enviar: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Erro ao enviar push: $e");
    }
  }
}