import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/shell/app_shell.dart';
import '../../components/ui/components.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/tokens.dart';
import '../admin/sessions_screen.dart';
import '../admin/users_screen.dart';
import '../join/join_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _seeding = false;
  String? _seedMessage;

  Future<void> _seedDemo() async {
    setState(() {
      _seeding = true;
      _seedMessage = null;
    });
    try {
      final payload = await widget.authService.api.postJson(
        '/api/admin/sessions/seed-demo',
        {},
        auth: true,
      );
      final session = payload['session'] as Map<String, dynamic>;
      final code = session['sessionCode'] as String;
      setState(() => _seedMessage = 'Demo session pin: $code');
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seeded demo session $code (copied)')),
      );
    } on ApiException catch (error) {
      setState(() => _seedMessage = error.message);
    } catch (error) {
      setState(() => _seedMessage = error.toString());
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.user!;
    final theme = Theme.of(context);

    return AppShell(
      authService: widget.authService,
      destination: AppNavDestination.home,
      body: ListView(
        children: [
          AppPageHeader(
            title: 'Welcome${user.displayName != null ? ', ${user.displayName}' : ''}',
            subtitle: 'Signed in as ${user.email} · ${user.role}',
          ),
          Wrap(
            spacing: AppSpace.s4,
            runSpacing: AppSpace.s4,
            children: [
              SizedBox(
                width: 320,
                child: AppCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            JoinScreen(authService: widget.authService),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.qr_code_2, color: theme.colorScheme.primary),
                      const SizedBox(height: AppSpace.s3),
                      Text('Join a quiz', style: theme.textTheme.titleLarge),
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        'Enter a 4-character pin or scan a QR code to play.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (user.isAdmin) ...[
                SizedBox(
                  width: 320,
                  child: AppCard(
                    onTap: () =>
                        Navigator.of(context).pushNamed('/admin/events'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.event, color: theme.colorScheme.primary),
                        const SizedBox(height: AppSpace.s3),
                        Text('Events', style: theme.textTheme.titleLarge),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          'Create and manage conference events.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: AppCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SessionsScreen(authService: widget.authService),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.quiz, color: theme.colorScheme.primary),
                        const SizedBox(height: AppSpace.s3),
                        Text('Sessions', style: theme.textTheme.titleLarge),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          'Open joins, manage questions, and view rankings.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: AppCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              UsersScreen(authService: widget.authService),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.group, color: theme.colorScheme.primary),
                        const SizedBox(height: AppSpace.s3),
                        Text('Users', style: theme.textTheme.titleLarge),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          'Review attendees and grant admin access.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (user.isAdmin) ...[
            const SizedBox(height: AppSpace.s6),
            Text('Developer tools', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpace.s3),
            AppCard(
              flat: true,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Seed demo quiz', style: theme.textTheme.titleLarge),
                        const SizedBox(height: AppSpace.s1),
                        Text(
                          'Creates a ready-to-join practice session and copies the pin.',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (_seedMessage != null) ...[
                          const SizedBox(height: AppSpace.s2),
                          SelectableText(
                            _seedMessage!,
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _seeding ? null : _seedDemo,
                    icon: const Icon(Icons.science_outlined),
                    label: Text(_seeding ? 'Seeding…' : 'Seed demo'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
