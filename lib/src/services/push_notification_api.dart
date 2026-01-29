import 'dart:convert';
import 'package:http/http.dart' as http;

class PushNotificationApi {
  // Nota: Em 2026, o Firebase exige autenticação OAuth2. 
  // Para testes rápidos, você pode usar a Server Key (Legada), 
  // mas o recomendado é um backend simples.
  
  static Future<void> sendNotificationToAll({
    required String title,
    required String body,
  }) async {
    const String serverKey = 'SUA_SERVER_KEY_AQUI'; // Pegue no Console do Firebase > Configurações do Projeto > Cloud Messaging
    const String endpoint = 'https://fcm.googleapis.com/fcm/send';

    final data = {
      "to": "/topics/todos",
      "notification": {
        "title": title,
        "body": body,
        "sound": "default"
      },
      "data": {
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "type": "geral"
      }
    };

    try {
      await http.post(
        Uri.parse(endpoint),
        body: jsonEncode(data),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
      );
    } catch (e) {
      print("Erro ao enviar push: $e");
    }
  }
}