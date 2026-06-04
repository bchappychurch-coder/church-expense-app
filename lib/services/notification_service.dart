import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final _messaging = FirebaseMessaging.instance;

  Future<String?> initialize() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('포그라운드 알림: ${message.notification?.title}');
      });
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM 초기화 실패: $e');
      return null;
    }
  }

  Future<String?> getToken() => _messaging.getToken();
}

// 백그라운드 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('백그라운드 알림: ${message.notification?.title}');
}
