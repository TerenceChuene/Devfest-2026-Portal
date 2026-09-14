import 'package:flutter/material.dart';

import '../../components/shell/app_shell.dart';
import '../../components/ui/components.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/tokens.dart';
import '../leaderboard/leaderboard_screen.dart';
import 'sessions_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final ApiClient _api = widget.authService.api;
  final _nameController = TextEditingController();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await _api.getJson('/api/admin/events', auth: true);
      final list =
          (payload['events'] as List<dynamic>).cast<Map<String, dynamic>>();
      setState(() => _events = list);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    try {
      await _api.postJson('/api/admin/events', {'name': name}, auth: true);
      _nameController.clear();
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppShell(
      authService: widget.authService,
      destination: AppNavDestination.events,
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
          AppPageHeader(
            title: 'Events',
            subtitle: 'Create conference events and open their session boards.',
          ),
          AppCard(
            flat: true,
            margin: const EdgeInsets.only(bottom: AppSpace.s4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'New event name',
                      hintText: 'DevFest 2026',
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                FilledButton(onPressed: _create, child: const Text('Create')),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s3),
              child: Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _events.isEmpty && !_loading
                ? const AppEmptyState(message: 'No events yet.')
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
                              bottom: BorderSide(color: theme.colorScheme.outline),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('NAME', style: theme.textTheme.labelSmall),
                              ),
                              SizedBox(
                                width: 160,
                                child: Text('SLUG', style: theme.textTheme.labelSmall),
                              ),
                              const SizedBox(width: 96),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _events.length,
                            itemBuilder: (context, index) {
                              final event = _events[index];
                              return AppDataRow(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SessionsScreen(
                                        authService: widget.authService,
                                        eventId: event['id'] as String,
                                        eventName: event['name'] as String,
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        event['name'] as String,
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 160,
                                      child: Text(
                                        event['slug'] as String,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Event leaderboard',
                                      icon: const Icon(
                                        Icons.emoji_events_outlined,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => LeaderboardScreen(
                                              authService: widget.authService,
                                              eventId: event['id'] as String,
                                              title:
                                                  '${event['name']} · Grand prize',
                                              adminMode: true,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const Icon(Icons.chevron_right),
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
