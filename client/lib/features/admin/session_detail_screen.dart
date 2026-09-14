import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../components/shell/app_shell.dart';
import '../../components/ui/components.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/tokens.dart';
import '../leaderboard/leaderboard_screen.dart';

class EditableOption {
  EditableOption({required this.label, required this.isCorrect});
  String label;
  bool isCorrect;
}

class EditableQuestion {
  EditableQuestion({required this.prompt, required this.options});
  String prompt;
  List<EditableOption> options;
}

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.authService,
    required this.sessionId,
  });

  final AuthService authService;
  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final ApiClient _api = widget.authService.api;
  Map<String, dynamic>? _session;
  List<EditableQuestion> _draft = [];
  final _notesController = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await _api.getJson(
        '/api/admin/sessions/${widget.sessionId}',
        auth: true,
      );
      final session = payload['session'] as Map<String, dynamic>;
      final questions = (session['questions'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _session = session;
        _draft = questions
            .map(
              (q) => EditableQuestion(
                prompt: q['prompt'] as String,
                options: (q['options'] as List<dynamic>)
                    .cast<Map<String, dynamic>>()
                    .map(
                      (o) => EditableOption(
                        label: o['label'] as String,
                        isCorrect: o['isCorrect'] as bool,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _draftPayload() {
    return _draft
        .map(
          (q) => {
            'prompt': q.prompt,
            'options': q.options
                .map((o) => {'label': o.label, 'isCorrect': o.isCorrect})
                .toList(),
          },
        )
        .toList();
  }

  void _applyGenerated(List<dynamic> questions) {
    setState(() {
      _draft = questions.cast<Map<String, dynamic>>().map((q) {
        return EditableQuestion(
          prompt: q['prompt'] as String,
          options: (q['options'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map((o) {
            return EditableOption(
              label: o['label'] as String,
              isCorrect: o['isCorrect'] as bool,
            );
          }).toList(),
        );
      }).toList();
    });
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final payload = await _api.postJson(
        '/api/admin/sessions/${widget.sessionId}/questions/generate',
        {'sourceText': _notesController.text},
        auth: true,
      );
      _applyGenerated(payload['questions'] as List<dynamic>);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generated questions — review then save')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final csvText = utf8.decode(bytes);
    setState(() => _busy = true);
    try {
      final payload = await _api.postJson(
        '/api/admin/sessions/${widget.sessionId}/questions/upload-csv',
        {'csvText': csvText},
        auth: true,
      );
      _applyGenerated(payload['questions'] as List<dynamic>);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV parsed — review then save')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveQuestions() async {
    setState(() => _busy = true);
    try {
      await _api.postJson(
        '/api/admin/sessions/${widget.sessionId}/questions',
        {'questions': _draftPayload(), 'replace': true},
        auth: true,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questions saved')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openJoin() async {
    setState(() => _busy = true);
    try {
      await _api.postJson(
        '/api/admin/sessions/${widget.sessionId}/open-join',
        {},
        auth: true,
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    setState(() => _busy = true);
    try {
      await _api.postJson(
        '/api/admin/sessions/${widget.sessionId}/close',
        {},
        auth: true,
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (context) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _api.deleteJson('/api/admin/sessions/${widget.sessionId}', auth: true);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return AppShell(
        authService: widget.authService,
        destination: AppNavDestination.sessions,
        showSearch: false,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return AppShell(
        authService: widget.authService,
        destination: AppNavDestination.sessions,
        showSearch: false,
        body: AppEmptyState(
          message: _error ?? 'Session not found',
          icon: Icons.error_outline,
        ),
      );
    }

    final session = _session!;
    final joinUrl = session['joinUrl'] as String? ?? '';
    final code = session['sessionCode'] as String? ?? '';
    final status = session['status'] as String? ?? '';
    final participants = session['participantCount'] ?? 0;
    final title = session['title'] as String? ?? 'Session';

    return AppShell(
      authService: widget.authService,
      destination: AppNavDestination.sessions,
      title: title,
      showSearch: false,
      actions: [
        IconButton(
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete session',
        ),
      ],
      body: ListView(
        children: [
          AppPageHeader(
            title: title,
            subtitle: 'Pin $code · $participants joined',
            actions: [AppStatusChip(status: status)],
          ),
          AppCard(
            flat: true,
            margin: const EdgeInsets.only(bottom: AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(joinUrl, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpace.s4),
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: [
                    FilledButton(
                      onPressed: _busy || status == 'join_open' ? null : _openJoin,
                      child: const Text('Open joins'),
                    ),
                    OutlinedButton(
                      onPressed: _busy || status == 'closed' ? null : _close,
                      child: const Text('Close'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied $code')),
                        );
                      },
                      child: const Text('Copy pin'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LeaderboardScreen(
                              authService: widget.authService,
                              sessionId: widget.sessionId,
                              title: 'Session rankings',
                              adminMode: true,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.leaderboard_outlined),
                      label: const Text('Rankings'),
                    ),
                  ],
                ),
                if (joinUrl.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s5),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpace.s3),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.mdBorder,
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: QrImageView(
                        data: joinUrl,
                        size: 200,
                        backgroundColor: AppColors.surface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text('Generate from notes', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpace.s3),
          AppCard(
            flat: true,
            margin: const EdgeInsets.only(bottom: AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _notesController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Paste speaker notes…',
                  ),
                ),
                const SizedBox(height: AppSpace.s3),
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _generate,
                      child: const Text('Generate with Gemini'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _pickCsv,
                      child: const Text('Upload CSV'),
                    ),
                    FilledButton(
                      onPressed: _busy || _draft.isEmpty ? null : _saveQuestions,
                      child: const Text('Save questions'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _draft.add(
                            EditableQuestion(
                              prompt: 'New question',
                              options: [
                                EditableOption(label: 'Option A', isCorrect: true),
                                EditableOption(label: 'Option B', isCorrect: false),
                                EditableOption(label: 'Option C', isCorrect: false),
                                EditableOption(label: 'Option D', isCorrect: false),
                              ],
                            ),
                          );
                        });
                      },
                      child: const Text('Add blank question'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  'CSV: prompt,option1,option2,option3,option4,correctIndex (1-based)',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ...List.generate(_draft.length, (qi) {
            final question = _draft[qi];
            return AppCard(
              flat: true,
              margin: const EdgeInsets.only(bottom: AppSpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: question.prompt,
                          decoration: InputDecoration(
                            labelText: 'Question ${qi + 1}',
                          ),
                          onChanged: (value) => question.prompt = value,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove question',
                        onPressed: () => setState(() => _draft.removeAt(qi)),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  ...List.generate(question.options.length, (oi) {
                    final option = question.options[oi];
                    return Row(
                      children: [
                        Radio<int>(
                          value: oi,
                          // ignore: deprecated_member_use
                          groupValue:
                              question.options.indexWhere((o) => o.isCorrect),
                          // ignore: deprecated_member_use
                          onChanged: (value) {
                            setState(() {
                              for (var i = 0;
                                  i < question.options.length;
                                  i++) {
                                question.options[i].isCorrect = i == value;
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: TextFormField(
                            initialValue: option.label,
                            decoration: InputDecoration(
                              labelText: 'Option ${oi + 1}',
                            ),
                            onChanged: (value) => option.label = value,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          }),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
