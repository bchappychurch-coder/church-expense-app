import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

const _vapidKey =
    'BMIxLqH9QRndaQC-n8CnqtmWZQWPPZeL0RK9RMREpzTKwvVUtoB8DidVsJHdmBSN0j4x2Ox_sdqRfLXnBckNEms';

class NotificationService {
  Future<String?> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        return null;
      }
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
      }
      return await messaging.getToken(vapidKey: kIsWeb ? _vapidKey : null);
    } catch (e) {
      debugPrint('FCM 초기화 실패: $e');
      return null;
    }
  }

  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance
          .getToken(vapidKey: kIsWeb ? _vapidKey : null);
    } catch (_) {
      return null;
    }
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('백그라운드 알림: ${message.notification?.title}');
}
