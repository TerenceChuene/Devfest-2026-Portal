import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/tokens.dart';

enum _LoginRole { attendee, admin }

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  _LoginRole _role = _LoginRole.attendee;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueWithGoogle() {
    return _run(
      () => widget.authService.signInWithGoogle(
        requireAdmin: _role == _LoginRole.admin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = _role == _LoginRole.admin;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
              child: Column(
                children: [
                  const SizedBox(height: AppSpace.s6),
                  Text(
                    AppBrand.eventName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s3),
                  Text(
                    isAdmin ? 'Organizer sign-in' : 'Attendee sign-in',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/images/devfest_login_illustration.png',
                        fit: BoxFit.contain,
                        height: 260,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s3),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpace.s4),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: AppSpace.s4),
                  if (widget.authService.canUseGoogle)
                    _GoogleSignInButton(
                      onPressed: _busy ? null : _continueWithGoogle,
                      label: isAdmin
                          ? 'Continue as organizer'
                          : 'Continue with Google',
                    )
                  else
                    Text(
                      'Google Sign-In needs Firebase config '
                      '(see lib/firebase_options.dart).',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: AppSpace.s3),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _role = isAdmin
                                  ? _LoginRole.attendee
                                  : _LoginRole.admin;
                              _error = null;
                            }),
                    child: Text(
                      isAdmin
                          ? 'Attendee? Sign in here'
                          : 'Organizer? Sign in here',
                    ),
                  ),
                  if (widget.authService.canUseDevAuth) ...[
                    const SizedBox(height: AppSpace.s2),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() {
                                if (isAdmin) {
                                  return widget.authService.signInWithDevEmail(
                                    'admin@example.com',
                                    displayName: 'Dev Admin',
                                  );
                                }
                                return widget.authService.signInWithDevEmail(
                                  'attendee@example.com',
                                  displayName: 'Dev Attendee',
                                );
                              }),
                      child: Text(
                        isAdmin
                            ? 'Dev: continue as admin'
                            : 'Dev: continue as attendee',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.onPressed,
    required this.label,
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.smBorder),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleGMark(size: 18),
            const SizedBox(width: AppSpace.s3),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGMark extends StatelessWidget {
  const _GoogleGMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2 - stroke / 2;

    void arc(Color color, double start, double sweep) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }

    // Approximate Google "G" ring segments.
    arc(const Color(0xFF4285F4), -0.4, 1.6); // blue
    arc(const Color(0xFF34A853), 1.2, 1.0); // green
    arc(const Color(0xFFFBBC05), 2.2, 0.9); // yellow
    arc(const Color(0xFFEA4335), 3.1, 1.2); // red

    final bar = Paint()..color = const Color(0xFF4285F4);
    final barTop = center.dy - stroke / 2;
    canvas.drawRRect(
      RRect.fromLTRBR(
        center.dx - stroke * 0.2,
        barTop,
        size.width - stroke * 0.35,
        barTop + stroke,
        const Radius.circular(1),
      ),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
