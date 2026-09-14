import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/shell/app_shell.dart';
import '../../components/ui/components.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../theme/tokens.dart';
import 'quiz_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({
    super.key,
    required this.authService,
    this.initialCode,
  });

  final AuthService authService;
  final String? initialCode;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final TextEditingController _codeController;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    if (widget.initialCode != null && widget.initialCode!.trim().length == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _join());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 4) {
      setState(() => _error = 'Enter the 4-character pin');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final api = widget.authService.api;
    final socket = SocketService(sessionStore: widget.authService.sessionStore);

    try {
      final lookup = await api.getJson('/api/sessions/by-code/$code', auth: true);
      final session = lookup['session'] as Map<String, dynamic>;
      final sessionId = session['id'] as String;

      try {
        await socket.joinSession(sessionId);
      } on ApiException catch (error) {
        if (error.message.toLowerCase().contains('already played')) {
          if (!mounted) return;
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => QuizStatusScreen(
                title: 'Already played',
                message: 'You already used your one attempt for this session.',
                authService: widget.authService,
              ),
            ),
          );
          return;
        }
        if (error.message.toLowerCase().contains('quiz closed') ||
            error.message.toLowerCase().contains('closed')) {
          if (!mounted) return;
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => QuizStatusScreen(
                title: 'Quiz Closed',
                message: 'This session is no longer accepting new players.',
                authService: widget.authService,
              ),
            ),
          );
          return;
        }
        rethrow;
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            authService: widget.authService,
            socketService: socket,
            sessionId: sessionId,
            sessionTitle: session['title'] as String? ?? 'Quiz',
            sessionCode: session['sessionCode'] as String? ?? code,
          ),
        ),
      );
    } on ApiException catch (error) {
      setState(() => _error = error.message);
      socket.dispose();
    } catch (error) {
      setState(() => _error = error.toString());
      socket.dispose();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppShell(
      authService: widget.authService,
      destination: AppNavDestination.join,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpace.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Enter session pin', style: theme.textTheme.displayMedium),
                const SizedBox(height: AppSpace.s2),
                Text(
                  'Scan the QR or type the 4-character code from the host.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.s5),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium?.copyWith(
                    letterSpacing: 8,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    UpperCaseTextFormatter(),
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'A4X9',
                  ),
                  onSubmitted: (_) => _join(),
                ),
                const SizedBox(height: AppSpace.s4),
                FilledButton(
                  onPressed: _busy ? null : _join,
                  child: _busy
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Join'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class QuizStatusScreen extends StatelessWidget {
  const QuizStatusScreen({
    super.key,
    required this.title,
    required this.message,
    required this.authService,
  });

  final String title;
  final String message;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppFocusShell(
      authService: authService,
      title: title,
      body: AppCard(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpace.s4),
            Text(title, style: theme.textTheme.displayMedium),
            const SizedBox(height: AppSpace.s3),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.s5),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back home'),
            ),
          ],
        ),
      ),
    );
  }
}
