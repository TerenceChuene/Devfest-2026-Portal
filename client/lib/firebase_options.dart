// Generated from Firebase project devfest2026-2708b web app config.
// Re-run: cd server && npx tsx src/scripts/fetchFirebaseWebConfig.ts
// Or: dart pub global activate flutterfire_cli && flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// True when a non-placeholder apiKey is present.
  static bool get isConfigured =>
      currentPlatform.apiKey.isNotEmpty &&
      currentPlatform.apiKey != 'YOUR_API_KEY' &&
      currentPlatform.appId.isNotEmpty &&
      currentPlatform.appId != 'YOUR_APP_ID';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: 'AIzaSyCMlN2PjYuDhff3GCy6N4qNKkAdchsXM1Y',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_APP_ID',
      defaultValue: '1:65336214832:web:208523306a06bdc500b4f5',
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '65336214832',
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'devfest2026-2708b',
    ),
    authDomain: String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: 'devfest2026-2708b.firebaseapp.com',
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'devfest2026-2708b.firebasestorage.app',
    ),
  );

  static const FirebaseOptions android = web;
  static const FirebaseOptions ios = web;
}
