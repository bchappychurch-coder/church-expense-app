import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  Future<String?> initialize() async {
    if (kIsWeb) return null; // 웹에서는 FCM 사용 안 함
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
      return await messaging.getToken();
    } catch (e) {
      debugPrint('FCM 초기화 실패: $e');
      return null;
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('백그라운드 알림: ${message.notification?.title}');
}
