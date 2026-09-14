import 'package:flutter/material.dart';

import 'features/admin/events_screen.dart';
import 'features/admin/sessions_screen.dart';
import 'features/admin/users_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/home/home_screen.dart';
import 'features/join/join_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

class DevFestApp extends StatelessWidget {
  const DevFestApp({super.key, required this.authService});

  final AuthService authService;

  String? get _deepLinkCode {
    final uri = Uri.base;
    final code = uri.queryParameters['code'];
    if (code != null && code.trim().isNotEmpty) return code.trim().toUpperCase();
    return null;
  }

  bool get _isJoinPath {
    final path = Uri.base.path;
    return path == '/join' || path.endsWith('/join');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authService,
      builder: (context, _) {
        Widget home;
        if (!authService.isSignedIn) {
          home = SignInScreen(authService: authService);
        } else if (_isJoinPath || _deepLinkCode != null) {
          home = JoinScreen(
            authService: authService,
            initialCode: _deepLinkCode,
          );
        } else {
          home = HomeScreen(authService: authService);
        }

        return MaterialApp(
          title: AppBrand.name,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          home: home,
          onGenerateRoute: (settings) {
            final name = settings.name ?? '';
            final uri = Uri.parse(name);
            if (uri.path == '/join' || name.startsWith('/join')) {
              return _fadeRoute(
                JoinScreen(
                  authService: authService,
                  initialCode: uri.queryParameters['code'],
                ),
                settings,
              );
            }
            if (uri.path == '/admin/events') {
              return _fadeRoute(
                EventsScreen(authService: authService),
                settings,
              );
            }
            if (uri.path == '/admin/sessions') {
              return _fadeRoute(
                SessionsScreen(authService: authService),
                settings,
              );
            }
            if (uri.path == '/admin/users') {
              return _fadeRoute(
                UsersScreen(authService: authService),
                settings,
              );
            }
            return null;
          },
        );
      },
    );
  }
}

PageRoute<T> _fadeRoute<T>(Widget page, RouteSettings settings) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: AppMotion.normal,
    reverseTransitionDuration: AppMotion.fast,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: AppMotion.curve),
        child: child,
      );
    },
  );
}
