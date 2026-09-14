import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      firebaseReady = true;
    } catch (error, stack) {
      debugPrint('Firebase init failed: $error\n$stack');
    }
  } else {
    debugPrint(
      'Firebase options not configured — using API_BASE_URL + AUTH_DEV_BYPASS for local auth.',
    );
  }

  final sessionStore = SessionStore();
  final authService = AuthService(
    sessionStore: sessionStore,
    firebaseReady: firebaseReady,
  );

  runApp(DevFestApp(authService: authService));
}
