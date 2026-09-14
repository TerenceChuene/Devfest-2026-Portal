import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';
import 'session_store.dart';

class QuizOption {
  QuizOption({required this.id, required this.label, required this.orderIndex});

  final String id;
  final String label;
  final int orderIndex;

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: json['id'] as String,
      label: json['label'] as String,
      orderIndex: json['orderIndex'] as int,
    );
  }
}

class QuestionReady {
  QuestionReady({
    required this.questionId,
    required this.prompt,
    required this.options,
    required this.timeLimitSeconds,
    required this.serverStartTime,
    required this.orderIndex,
    required this.totalQuestions,
  });

  final String questionId;
  final String prompt;
  final List<QuizOption> options;
  final int timeLimitSeconds;
  final DateTime serverStartTime;
  final int orderIndex;
  final int totalQuestions;

  factory QuestionReady.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(QuizOption.fromJson)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return QuestionReady(
      questionId: json['questionId'] as String,
      prompt: json['prompt'] as String,
      options: options,
      timeLimitSeconds: json['timeLimitSeconds'] as int,
      serverStartTime: DateTime.parse(json['serverStartTime'] as String).toUtc(),
      orderIndex: json['orderIndex'] as int,
      totalQuestions: json['totalQuestions'] as int,
    );
  }

  Duration remaining(DateTime nowUtc) {
    final elapsed = nowUtc.difference(serverStartTime);
    final total = Duration(seconds: timeLimitSeconds);
    final left = total - elapsed;
    return left.isNegative ? Duration.zero : left;
  }
}

class AnswerResult {
  AnswerResult({
    required this.questionId,
    required this.isCorrect,
    required this.pointsAwarded,
    required this.correctOptionId,
    required this.completed,
    required this.totalScore,
    this.nextQuestion,
  });

  final String questionId;
  final bool isCorrect;
  final int pointsAwarded;
  final String? correctOptionId;
  final bool completed;
  final int totalScore;
  final QuestionReady? nextQuestion;

  factory AnswerResult.fromJson(Map<String, dynamic> json) {
    return AnswerResult(
      questionId: json['questionId'] as String,
      isCorrect: json['isCorrect'] as bool,
      pointsAwarded: json['pointsAwarded'] as int,
      correctOptionId: json['correctOptionId'] as String?,
      completed: json['completed'] as bool,
      totalScore: json['totalScore'] as int? ?? 0,
      nextQuestion: json['nextQuestion'] is Map<String, dynamic>
          ? QuestionReady.fromJson(json['nextQuestion'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SocketService {
  SocketService({required this.sessionStore});

  final SessionStore sessionStore;
  io.Socket? _socket;

  final _questionController = StreamController<QuestionReady>.broadcast();
  final _answerController = StreamController<AnswerResult>.broadcast();
  final _quizClosedController = StreamController<String>.broadcast();
  final _alreadyPlayedController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _leaderboardController = StreamController<Map<String, dynamic>>.broadcast();
  final _eventLeaderboardController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<QuestionReady> get questions => _questionController.stream;
  Stream<AnswerResult> get answers => _answerController.stream;
  Stream<String> get quizClosed => _quizClosedController.stream;
  Stream<void> get alreadyPlayed => _alreadyPlayedController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<Map<String, dynamic>> get leaderboardUpdates => _leaderboardController.stream;
  Stream<Map<String, dynamic>> get eventLeaderboardUpdates => _eventLeaderboardController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket != null) return;
    final token = sessionStore.accessToken;
    if (token == null) {
      throw StateError('Not signed in');
    }

    _socket = io.io(
      ApiClient.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..onConnect((_) {})
      ..onDisconnect((_) {})
      ..on('question_ready', (data) {
        if (data is Map) {
          _questionController.add(
            QuestionReady.fromJson(Map<String, dynamic>.from(data)),
          );
        }
      })
      ..on('answer_result', (data) {
        if (data is Map) {
          _answerController.add(
            AnswerResult.fromJson(Map<String, dynamic>.from(data)),
          );
        }
      })
      ..on('quiz_closed', (data) {
        final reason = data is Map && data['reason'] != null
            ? data['reason'].toString()
            : 'Quiz Closed';
        _quizClosedController.add(reason);
      })
      ..on('already_played', (_) => _alreadyPlayedController.add(null))
      ..on('leaderboard_update', (data) {
        if (data is Map) {
          _leaderboardController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('event_leaderboard_update', (data) {
        if (data is Map) {
          _eventLeaderboardController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('error_message', (data) {
        final message = data is Map && data['error'] != null
            ? data['error'].toString()
            : 'Socket error';
        _errorController.add(message);
      })
      ..connect();
  }

  void subscribeLeaderboard({String? sessionId, String? eventId}) {
    connect();
    _socket?.emit('subscribe_leaderboard', {
      ?sessionId: sessionId,
      ?eventId: eventId,
    });
  }

  Future<Map<String, dynamic>> joinSession(String sessionId) async {
    connect();
    final socket = _socket!;
    if (!socket.connected) {
      await _waitForConnect(socket);
    }

    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck('join_session', {'sessionId': sessionId}, ack: (dynamic response) {
      if (response is Map) {
        final map = Map<String, dynamic>.from(response);
        if (map['ok'] == true) {
          if (map['question'] is Map) {
            _questionController.add(
              QuestionReady.fromJson(Map<String, dynamic>.from(map['question'] as Map)),
            );
          }
          completer.complete(map);
        } else {
          final code = map['code']?.toString();
          if (code == 'quiz_closed') {
            _quizClosedController.add(map['error']?.toString() ?? 'Quiz Closed');
          } else if (code == 'already_played') {
            _alreadyPlayedController.add(null);
          }
          completer.completeError(
            ApiException(400, map['error']?.toString() ?? 'Join failed'),
          );
        }
      } else {
        completer.completeError(ApiException(500, 'Invalid join ack'));
      }
    });
    return completer.future;
  }

  Future<AnswerResult> submitAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
  }) async {
    connect();
    final socket = _socket!;
    if (!socket.connected) {
      await _waitForConnect(socket);
    }

    final completer = Completer<AnswerResult>();
    socket.emitWithAck(
      'submit_answer',
      {
        'sessionId': sessionId,
        'questionId': questionId,
        'optionId': optionId,
      },
      ack: (dynamic response) {
        if (response is Map) {
          final map = Map<String, dynamic>.from(response);
          if (map['ok'] == true) {
            final result = AnswerResult.fromJson(map);
            completer.complete(result);
          } else {
            completer.completeError(
              ApiException(400, map['error']?.toString() ?? 'Submit failed'),
            );
          }
        } else {
          completer.completeError(ApiException(500, 'Invalid submit ack'));
        }
      },
    );
    return completer.future;
  }

  Future<void> _waitForConnect(io.Socket socket) async {
    if (socket.connected) return;
    final completer = Completer<void>();
    void onConnect(_) {
      if (!completer.isCompleted) completer.complete();
    }

    socket.onConnect(onConnect);
    socket.connect();
    await completer.future.timeout(const Duration(seconds: 8));
    socket.off('connect');
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _questionController.close();
    _answerController.close();
    _quizClosedController.close();
    _alreadyPlayedController.close();
    _errorController.close();
    _leaderboardController.close();
    _eventLeaderboardController.close();
  }
}
