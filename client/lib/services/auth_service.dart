import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_client.dart';
import 'session_store.dart';

class AuthService extends ChangeNotifier {
  AuthService({
    required this.sessionStore,
    required this.firebaseReady,
  }) : api = ApiClient(sessionStore: sessionStore);

  final SessionStore sessionStore;
  final bool firebaseReady;
  final ApiClient api;

  /// Used for native Google Sign-In only. Web uses Firebase [signInWithPopup].
  static const googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '65336214832-2uj5kda9moo2u0o2odkjckrm1321v7hv.apps.googleusercontent.com',
  );

  static const authDevBypass = String.fromEnvironment(
    'AUTH_DEV_BYPASS',
    defaultValue: 'dev-bypass-secret',
  );

  bool get canUseGoogle => firebaseReady;
  bool get canUseDevAuth => authDevBypass.isNotEmpty;
  SessionUser? get user => sessionStore.user;
  bool get isSignedIn => sessionStore.isSignedIn;

  Future<void> signInWithGoogle({bool requireAdmin = false}) async {
    if (!firebaseReady) {
      throw StateError('Firebase is not configured');
    }

    final UserCredential userCred;
    if (kIsWeb) {
      // google_sign_in.authenticate() is unsupported on web; use Firebase popup.
      userCred = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } else {
      if (googleClientId.isNotEmpty) {
        await GoogleSignIn.instance.initialize(clientId: googleClientId);
      } else {
        await GoogleSignIn.instance.initialize();
      }
      final account = await GoogleSignIn.instance.authenticate();
      final googleAuth = account.authentication;
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      userCred = await FirebaseAuth.instance.signInWithCredential(credential);
    }

    final idToken = await userCred.user?.getIdToken();
    if (idToken == null) {
      throw StateError('Missing Firebase ID token');
    }

    await _exchangeSession(idToken: idToken);

    if (requireAdmin && !(user?.isAdmin ?? false)) {
      await signOut();
      throw ApiException(
        403,
        'This account is not an organizer. Ask an admin to grant access, then try again.',
      );
    }
  }

  Future<void> signInWithDevEmail(String email, {String? displayName}) async {
    if (!canUseDevAuth) {
      throw StateError('Dev auth bypass is not configured');
    }
    final payload = await api.postJson(
      '/api/auth/session',
      {
        'devEmail': email,
        ?displayName: displayName,
      },
      extraHeaders: {'X-Dev-Bypass': authDevBypass},
    );
    _applySessionPayload(payload);
  }

  Future<void> _exchangeSession({required String idToken}) async {
    final payload = await api.postJson('/api/auth/session', {'idToken': idToken});
    _applySessionPayload(payload);
  }

  void _applySessionPayload(Map<String, dynamic> payload) {
    final token = payload['accessToken'] as String;
    final userJson = payload['user'] as Map<String, dynamic>;
    sessionStore.setSession(
      token: token,
      sessionUser: SessionUser.fromJson(userJson),
    );
    notifyListeners();
  }

  Future<void> refreshMe() async {
    final me = await api.getJson('/api/auth/me', auth: true);
    sessionStore.user = SessionUser.fromJson(me);
    notifyListeners();
  }

  Future<void> signOut() async {
    sessionStore.clear();
    if (firebaseReady) {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
    }
    notifyListeners();
  }
}
