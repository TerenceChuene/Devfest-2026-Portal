import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/shell/app_shell.dart';
import '../../components/ui/components.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../theme/tokens.dart';
import '../leaderboard/leaderboard_screen.dart';
import 'join_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.authService,
    required this.socketService,
    required this.sessionId,
    required this.sessionTitle,
    required this.sessionCode,
  });

  final AuthService authService;
  final SocketService socketService;
  final String sessionId;
  final String sessionTitle;
  final String sessionCode;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  QuestionReady? _question;
  AnswerResult? _lastResult;
  String? _selectedOptionId;
  bool _locked = false;
  bool _completed = false;
  int _totalScore = 0;
  int? _finalRank;
  String? _error;
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _subs.addAll([
      widget.socketService.questions.listen(_onQuestion),
      widget.socketService.answers.listen(_onAnswer),
      widget.socketService.quizClosed.listen((reason) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => QuizStatusScreen(
              title: 'Quiz Closed',
              message: reason,
              authService: widget.authService,
            ),
          ),
        );
      }),
      widget.socketService.alreadyPlayed.listen((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => QuizStatusScreen(
              title: 'Already played',
              message: 'You already used your one attempt for this session.',
              authService: widget.authService,
            ),
          ),
        );
      }),
      widget.socketService.errors.listen((message) {
        setState(() => _error = message);
      }),
    ]);
    _restoreIfNeeded();
  }

  Future<void> _restoreIfNeeded() async {
    try {
      final me = await widget.authService.api.getJson(
        '/api/sessions/${widget.sessionId}/me',
        auth: true,
      );
      if (me['completed'] == true) {
        setState(() {
          _completed = true;
          _totalScore = me['totalScore'] as int? ?? 0;
        });
        return;
      }
      if (me['question'] is Map<String, dynamic>) {
        _onQuestion(QuestionReady.fromJson(me['question'] as Map<String, dynamic>));
        setState(() => _totalScore = me['totalScore'] as int? ?? 0);
      }
    } catch (_) {
      // Socket join already provided the first question.
    }
  }

  void _onQuestion(QuestionReady question) {
    _ticker?.cancel();
    setState(() {
      _question = question;
      _lastResult = null;
      _selectedOptionId = null;
      _locked = false;
      _error = null;
      _remaining = question.remaining(DateTime.now().toUtc());
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _question == null) return;
      setState(() {
        _remaining = _question!.remaining(DateTime.now().toUtc());
      });
    });
  }

  void _onAnswer(AnswerResult result) {
    setState(() {
      _lastResult = result;
      _locked = true;
      _totalScore = result.totalScore;
      _completed = result.completed;
    });
    if (result.nextQuestion != null) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || _completed) return;
        _onQuestion(result.nextQuestion!);
      });
    } else if (result.completed) {
      _ticker?.cancel();
      _loadFinalRank();
    }
  }

  Future<void> _loadFinalRank() async {
    try {
      final payload = await widget.authService.api.getJson(
        '/api/sessions/${widget.sessionId}/leaderboard?limit=10',
        auth: true,
      );
      final me = payload['me'];
      if (me is Map<String, dynamic> && mounted) {
        setState(() => _finalRank = me['rank'] as int?);
      }
    } catch (_) {
      // Rank is best-effort polish.
    }
  }

  void _openLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeaderboardScreen(
          authService: widget.authService,
          sessionId: widget.sessionId,
          title: 'Session leaderboard',
          socketService: widget.socketService,
        ),
      ),
    );
  }

  Future<void> _submit(String optionId) async {
    final question = _question;
    if (question == null || _locked) return;

    setState(() {
      _selectedOptionId = optionId;
      _locked = true;
      _error = null;
    });

    try {
      final result = await widget.socketService.submitAnswer(
        sessionId: widget.sessionId,
        questionId: question.questionId,
        optionId: optionId,
      );
      _onAnswer(result);
    } on ApiException catch (error) {
      setState(() {
        _locked = false;
        _error = error.message;
      });
    } catch (error) {
      setState(() {
        _locked = false;
        _error = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    widget.socketService.dispose();
    super.dispose();
  }

  List<Widget> get _scoreActions => [
        IconButton(
          onPressed: _openLeaderboard,
          icon: const Icon(Icons.leaderboard_outlined),
          tooltip: 'Leaderboard',
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpace.s2),
          child: Center(
            child: Text(
              'Score $_totalScore · ${widget.sessionCode}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_completed) {
      return AppFocusShell(
        authService: widget.authService,
        title: widget.sessionTitle,
        actions: _scoreActions,
        body: AppCard(
          padding: const EdgeInsets.all(AppSpace.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpace.s4),
              Text('Quiz complete', style: theme.textTheme.displayMedium),
              const SizedBox(height: AppSpace.s3),
              Text(
                'Your score: $_totalScore',
                style: theme.textTheme.titleLarge,
              ),
              if (_finalRank != null) ...[
                const SizedBox(height: AppSpace.s2),
                AppBadge(
                  label: 'Finished #$_finalRank',
                  icon: Icons.military_tech_outlined,
                ),
              ],
              const SizedBox(height: AppSpace.s5),
              FilledButton.icon(
                onPressed: _openLeaderboard,
                icon: const Icon(Icons.leaderboard_outlined),
                label: const Text('View leaderboard'),
              ),
              const SizedBox(height: AppSpace.s2),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Back home'),
              ),
            ],
          ),
        ),
      );
    }

    final question = _question;
    final progress = question == null
        ? ''
        : 'Question ${question.orderIndex + 1} / ${question.totalQuestions}';
    final seconds = _remaining.inMilliseconds / 1000.0;
    final limit = question?.timeLimitSeconds ?? 1;
    final progressValue = (seconds / limit).clamp(0.0, 1.0);

    return AppFocusShell(
      authService: widget.authService,
      title: widget.sessionTitle,
      actions: _scoreActions,
      centerBody: false,
      maxContentWidth: 720,
      body: question == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  progress.toUpperCase(),
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpace.s2),
                AppProgressBar(value: progressValue, height: 6),
                const SizedBox(height: AppSpace.s2),
                Text(
                  seconds.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium,
                ),
                const SizedBox(height: AppSpace.s5),
                Text(question.prompt, style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpace.s4),
                Expanded(
                  child: ListView(
                    children: [
                      ...question.options.map((option) {
                        final selected = _selectedOptionId == option.id;
                        final result = _lastResult;
                        Color? bg;
                        Color? border;
                        if (result != null) {
                          if (option.id == result.correctOptionId) {
                            bg = AppColors.successContainer;
                            border = AppColors.success;
                          } else if (selected && !result.isCorrect) {
                            bg = AppColors.errorContainer;
                            border = AppColors.error;
                          }
                        } else if (selected) {
                          bg = theme.colorScheme.primaryContainer;
                          border = theme.colorScheme.primary;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s2),
                          child: Material(
                            color: bg ?? theme.colorScheme.surface,
                            borderRadius: AppRadii.mdBorder,
                            child: InkWell(
                              borderRadius: AppRadii.mdBorder,
                              onTap: _locked ? null : () => _submit(option.id),
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                curve: AppMotion.curve,
                                padding: const EdgeInsets.all(AppSpace.s4),
                                decoration: BoxDecoration(
                                  borderRadius: AppRadii.mdBorder,
                                  border: Border.all(
                                    color: border ?? theme.colorScheme.outline,
                                  ),
                                ),
                                child: Text(
                                  option.label,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (_lastResult != null) ...[
                        const SizedBox(height: AppSpace.s3),
                        Text(
                          _lastResult!.isCorrect
                              ? '+${_lastResult!.pointsAwarded} points'
                              : 'No points',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _lastResult!.isCorrect
                                ? AppColors.success
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: AppSpace.s3),
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
              ],
            ),
    );
  }
}
