import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not configured.');
      default:
        throw UnsupportedError('Unsupported platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBtbIxm4vqj0g8dH7uHHx6Co5_xLdok-jA',
    appId: '1:602448353479:web:72c0b4edf45c25540286e2',
    messagingSenderId: '602448353479',
    projectId: 'church-expense-app',
    authDomain: 'church-expense-app.firebaseapp.com',
    storageBucket: 'church-expense-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAr72ifsPEKNVQrQ78xPS4ugyFNgdCCQr0',
    appId: '1:602448353479:android:2f2b6078ef5630b80286e2',
    messagingSenderId: '602448353479',
    projectId: 'church-expense-app',
    storageBucket: 'church-expense-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBtbIxm4vqj0g8dH7uHHx6Co5_xLdok-jA',
    appId: '1:602448353479:web:72c0b4edf45c25540286e2',
    messagingSenderId: '602448353479',
    projectId: 'church-expense-app',
    storageBucket: 'church-expense-app.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBtbIxm4vqj0g8dH7uHHx6Co5_xLdok-jA',
    appId: '1:602448353479:web:72c0b4edf45c25540286e2',
    messagingSenderId: '602448353479',
    projectId: 'church-expense-app',
    storageBucket: 'church-expense-app.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBtbIxm4vqj0g8dH7uHHx6Co5_xLdok-jA',
    appId: '1:602448353479:web:72c0b4edf45c25540286e2',
    messagingSenderId: '602448353479',
    projectId: 'church-expense-app',
    authDomain: 'church-expense-app.firebaseapp.com',
    storageBucket: 'church-expense-app.firebasestorage.app',
  );
}
