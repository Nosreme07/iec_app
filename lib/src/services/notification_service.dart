import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initNotification() async {
    // 1. Pede permissão ao usuário (essencial para iOS e Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Usuário permitiu notificações');
      
      // 2. Inscreve o usuário no tópico "todos" para receber push coletivo
      await _fcm.subscribeToTopic("todos");
    }

    // 3. Configura o que acontece quando a mensagem chega com o app em primeiro plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Recebi uma mensagem com o app aberto: ${message.notification?.title}');
    });
  }

  // Útil para pegar o token individual se precisar testar em um aparelho específico
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }
}