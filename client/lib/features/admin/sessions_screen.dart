import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/shell/app_shell.dart';
import '../../components/ui/components.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/tokens.dart';
import 'session_detail_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({
    super.key,
    required this.authService,
    this.eventId,
    this.eventName,
  });

  final AuthService authService;
  final String? eventId;
  final String? eventName;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late final ApiClient _api = widget.authService.api;
  final _titleController = TextEditingController();
  final _speakerController = TextEditingController();
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _events = [];
  String? _selectedEventId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedEventId = widget.eventId;
    _bootstrap();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _speakerController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eventsPayload = await _api.getJson('/api/admin/events', auth: true);
      _events =
          (eventsPayload['events'] as List<dynamic>).cast<Map<String, dynamic>>();
      _selectedEventId ??=
          _events.isNotEmpty ? _events.first['id'] as String : null;
      await _loadSessions();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSessions() async {
    final query =
        _selectedEventId != null ? '?eventId=$_selectedEventId' : '';
    final payload = await _api.getJson('/api/admin/sessions$query', auth: true);
    setState(() {
      _sessions =
          (payload['sessions'] as List<dynamic>).cast<Map<String, dynamic>>();
    });
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedEventId == null) return;
    try {
      await _api.postJson(
        '/api/admin/sessions',
        {
          'eventId': _selectedEventId,
          'title': title,
          'speakerName': _speakerController.text.trim().isEmpty
              ? null
              : _speakerController.text.trim(),
        },
        auth: true,
      );
      _titleController.clear();
      _speakerController.clear();
      await _loadSessions();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageTitle =
        widget.eventName == null ? 'Sessions' : 'Sessions · ${widget.eventName}';

    return AppShell(
      authService: widget.authService,
      destination: AppNavDestination.sessions,
      title: widget.eventName,
      actions: [
        IconButton(
          onPressed: _bootstrap,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: pageTitle,
            subtitle: 'Create quiz sessions, copy pins, and open joins.',
          ),
          AppCard(
            flat: true,
            margin: const EdgeInsets.only(bottom: AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_events.isNotEmpty)
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _selectedEventId,
                    decoration: const InputDecoration(labelText: 'Event'),
                    items: _events
                        .map(
                          (event) => DropdownMenuItem(
                            value: event['id'] as String,
                            child: Text(event['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      setState(() => _selectedEventId = value);
                      await _loadSessions();
                    },
                  ),
                const SizedBox(height: AppSpace.s3),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Session title'),
                ),
                const SizedBox(height: AppSpace.s2),
                TextField(
                  controller: _speakerController,
                  decoration:
                      const InputDecoration(labelText: 'Speaker (optional)'),
                ),
                const SizedBox(height: AppSpace.s3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _create,
                    child: const Text('Create session'),
                  ),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          Expanded(
            child: _sessions.isEmpty && !_loading
                ? const AppEmptyState(message: 'No sessions yet.')
                : AppCard(
                    flat: true,
                    padding: EdgeInsets.zero,
                    child: ListView.builder(
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final code = session['sessionCode'] as String? ?? '';
                        final status = session['status'] as String? ?? '';
                        return AppDataRow(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SessionDetailScreen(
                                  authService: widget.authService,
                                  sessionId: session['id'] as String,
                                ),
                              ),
                            );
                            await _loadSessions();
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session['title'] as String,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$code · ${session['participantCount'] ?? 0} joined · '
                                      '${session['questionCount'] ?? 0} questions',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              AppStatusChip(status: status),
                              IconButton(
                                tooltip: 'Copy pin',
                                icon: const Icon(Icons.copy_outlined),
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: code),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Copied pin $code')),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
