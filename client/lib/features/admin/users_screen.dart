import 'package:flutter/material.dart';

import '../../components/shell/app_shell.dart';
import '../../components/ui/components.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/tokens.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final ApiClient _api = widget.authService.api;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await _api.getJson('/api/admin/users', auth: true);
      setState(() {
        _users =
            (payload['users'] as List<dynamic>).cast<Map<String, dynamic>>();
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _grantAdmin(String id, String email) async {
    try {
      final payload = await _api.postJson(
        '/api/admin/users/$id/grant-admin',
        {},
        auth: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            payload['message']?.toString() ?? 'Granted admin to $email',
          ),
        ),
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppShell(
      authService: widget.authService,
      destination: AppNavDestination.users,
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppPageHeader(
            title: 'Users',
            subtitle: 'Review attendees and grant admin access.',
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? AppEmptyState(message: _error!, icon: Icons.error_outline)
                    : AppCard(
                        flat: true,
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            Container(
                              height: AppLayoutTokens.tableRowHeight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s4,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'EMAIL',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'ROLE',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ),
                                  const SizedBox(width: 120),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _users.length,
                                itemBuilder: (context, index) {
                                  final user = _users[index];
                                  final role =
                                      user['role'] as String? ?? 'attendee';
                                  final email = user['email'] as String? ?? '';
                                  return AppDataRow(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                email,
                                                style: theme.textTheme.bodyLarge,
                                              ),
                                              if (user['displayName'] != null)
                                                Text(
                                                  '${user['displayName']}',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: role == 'admin'
                                              ? const AppChip(
                                                  label: 'admin',
                                                  selected: true,
                                                )
                                              : Text(
                                                  role,
                                                  style:
                                                      theme.textTheme.bodyMedium,
                                                ),
                                        ),
                                        SizedBox(
                                          width: 120,
                                          child: role == 'admin'
                                              ? const SizedBox.shrink()
                                              : TextButton(
                                                  onPressed: () => _grantAdmin(
                                                    user['id'] as String,
                                                    email,
                                                  ),
                                                  child: const Text('Grant admin'),
                                                ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
