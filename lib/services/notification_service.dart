import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final _messaging = FirebaseMessaging.instance;

  Future<String?> initialize() async {
    // 알림 권한 요청
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 포그라운드 알림 표시 설정
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 백그라운드 메시지 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    // 포그라운드 메시지 핸들러
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('포그라운드 알림: ${message.notification?.title}');
    });

    return await _messaging.getToken();
  }

  Future<String?> getToken() => _messaging.getToken();
}

// 백그라운드 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('백그라운드 알림: ${message.notification?.title}');
}
