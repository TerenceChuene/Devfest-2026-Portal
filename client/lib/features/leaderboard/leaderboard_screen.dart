import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/shell/app_shell.dart';
import '../../components/ui/components.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../theme/tokens.dart';

class LeaderboardEntryView {
  LeaderboardEntryView({
    required this.userId,
    required this.displayName,
    required this.score,
    required this.rank,
  });

  final String userId;
  final String displayName;
  final int score;
  final int rank;

  factory LeaderboardEntryView.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryView(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String? ?? 'Player',
      score: (json['score'] as num).round(),
      rank: json['rank'] as int? ?? 0,
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.authService,
    this.sessionId,
    this.eventId,
    this.title = 'Leaderboard',
    this.adminMode = false,
    this.socketService,
  });

  final AuthService authService;
  final String? sessionId;
  final String? eventId;
  final String title;
  final bool adminMode;
  final SocketService? socketService;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardEntryView> _top = [];
  LeaderboardEntryView? _me;
  int _participantCount = 0;
  bool _loading = true;
  String? _error;
  SocketService? _ownedSocket;
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
    _listen();
  }

  Future<void> _listen() async {
    final socket = widget.socketService ??
        SocketService(sessionStore: widget.authService.sessionStore);
    if (widget.socketService == null) {
      _ownedSocket = socket;
      socket.connect();
    }
    socket.subscribeLeaderboard(
      sessionId: widget.sessionId,
      eventId: widget.eventId,
    );
    _subs.add(socket.leaderboardUpdates.listen((payload) {
      if (widget.sessionId != null &&
          payload['sessionId'] != null &&
          payload['sessionId'] != widget.sessionId) {
        return;
      }
      final top = (payload['top'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(LeaderboardEntryView.fromJson)
          .toList();
      setState(() {
        _top = top;
        _participantCount =
            payload['participantCount'] as int? ?? _participantCount;
      });
      _load(silent: true);
    }));
    _subs.add(socket.eventLeaderboardUpdates.listen((payload) {
      if (widget.eventId != null &&
          payload['eventId'] != null &&
          payload['eventId'] != widget.eventId) {
        return;
      }
      if (widget.sessionId != null) return;
      final top = (payload['top'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(LeaderboardEntryView.fromJson)
          .toList();
      setState(() => _top = top);
      _load(silent: true);
    }));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final limit = widget.adminMode ? 50 : 10;
      final path = widget.sessionId != null
          ? '/api/sessions/${widget.sessionId}/leaderboard?limit=$limit'
          : '/api/events/${widget.eventId}/leaderboard?limit=$limit';
      final payload = await widget.authService.api.getJson(path, auth: true);
      setState(() {
        _top = (payload['top'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(LeaderboardEntryView.fromJson)
            .toList();
        _me = payload['me'] is Map<String, dynamic>
            ? LeaderboardEntryView.fromJson(payload['me'] as Map<String, dynamic>)
            : null;
        _participantCount = payload['participantCount'] as int? ?? 0;
      });
    } on ApiException catch (error) {
      if (!silent) setState(() => _error = error.message);
    } catch (error) {
      if (!silent) setState(() => _error = error.toString());
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _ownedSocket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppShell(
      authService: widget.authService,
      destination: null,
      title: widget.title,
      showSearch: false,
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppEmptyState(message: _error!, icon: Icons.error_outline)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_me != null)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpace.s4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              foregroundColor: theme.colorScheme.primary,
                              child: Text('#${_me!.rank}'),
                            ),
                            const SizedBox(width: AppSpace.s3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You — ${_me!.displayName}',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  Text(
                                    'Rank #${_me!.rank}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${_me!.score}',
                              style: theme.textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    if (widget.sessionId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s3),
                        child: Text(
                          '$_participantCount PLAYERS',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    Expanded(
                      child: _top.isEmpty
                          ? const AppEmptyState(message: 'No scores yet.')
                          : AppCard(
                              flat: true,
                              padding: EdgeInsets.zero,
                              child: ListView.builder(
                                itemCount: _top.length,
                                itemBuilder: (context, index) {
                                  final entry = _top[index];
                                  final isMe = _me?.userId == entry.userId;
                                  return AppDataRow(
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 48,
                                          child: Text(
                                            '#${entry.rank}',
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            entry.displayName,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                              fontWeight: isMe
                                                  ? FontWeight.w500
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${entry.score}',
                                          style: theme.textTheme.titleMedium,
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
