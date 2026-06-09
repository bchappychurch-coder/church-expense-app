import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

const _vapidKey =
    'BMIxLqH9QRndaQC-n8CnqtmWZQWPPZeL0RK9RMREpzTKwvVUtoB8DidVsJHdmBSN0j4x2Ox_sdqRfLXnBckNEms';

class NotificationService {
  /// 앱 시작 시 호출 — 안드로이드 백그라운드 핸들러만 등록
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
    } catch (_) {}
  }

  /// 사용자가 이름을 탭할 때 호출 — 권한 요청 후 토큰 반환
  Future<String?> requestPermissionAndGetToken() async {
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
      return await messaging.getToken(vapidKey: kIsWeb ? _vapidKey : null);
    } catch (e) {
      debugPrint('FCM 토큰 발급 실패: $e');
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
