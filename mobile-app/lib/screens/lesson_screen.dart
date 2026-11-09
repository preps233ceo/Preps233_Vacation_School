import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../config.dart';
import '../models.dart';
import '../services/db_service.dart';

const double _kUnlockThreshold = 0.70;
const int _kPassMark = 80;

class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  final String localPath;

  const LessonScreen({
    super.key,
    required this.lesson,
    required this.localPath,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoCtrl;
  Timer? _watchTimer;
  int _watchSeconds = 0;
  bool _isForeground = true;

  List<Question> _questions = [];
  final Map<int, int> _answers = {};
  bool _quizSubmitted = false;
  _QuizResult? _quizResult;

  LessonProgress? _progress;
  final String _deviceId = AppConfig.deviceId;
  final String _studentName = AppConfig.studentName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = Player();
    _videoCtrl = VideoController(_player);
    _initLoad();
  }

  Future<void> _initLoad() async {
    _progress = await DbService.getProgress(_deviceId, widget.lesson.id);
    _watchSeconds = _progress?.watchSeconds ?? 0;
    _questions = await DbService.getQuestionsForLesson(widget.lesson.id);
    if (mounted) setState(() {});

    await _player.open(Media('file://${widget.localPath}'));

    _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isForeground || !_player.state.playing) return;
      setState(() {
        _watchSeconds =
            (_watchSeconds + 1).clamp(0, widget.lesson.durationSeconds);
      });
    });

    Timer.periodic(const Duration(seconds: 15), (_) => _saveProgress());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _player.pause();
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveProgress() async {
    final completed = _watchSeconds >= widget.lesson.durationSeconds;
    await DbService.updateWatchProgress(
        _deviceId, widget.lesson.id, _watchSeconds, completed);
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _saveProgress();
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }

  bool get _quizUnlocked {
    if (widget.lesson.durationSeconds <= 0) return true;
    final threshold =
        (widget.lesson.durationSeconds * _kUnlockThreshold).floor();
    return _watchSeconds >= threshold ||
        (_progress?.videoCompleted ?? false) ||
        (_progress?.quizPassed ?? false);
  }

  Future<void> _submitQuiz() async {
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions.')),
      );
      return;
    }

    int correct = 0;
    final results = <_QuizItemResult>[];
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final given = _answers[i] ?? -1;
      final isCorrect = given == q.correctAnswer;
      if (isCorrect) correct++;
      results.add(_QuizItemResult(
        correct: isCorrect,
        correctOptionIndex: q.correctAnswer,
        explanation: q.explanation,
      ));
    }
    final score =
        (_questions.isNotEmpty ? (correct / _questions.length) * 100 : 0)
            .round();
    final passed = score >= _kPassMark;
    final attempts = (_progress?.quizAttempts ?? 0) + 1;

    await DbService.saveQuizResult(_deviceId, widget.lesson.id, score, passed, attempts);
    _progress = await DbService.getProgress(_deviceId, widget.lesson.id);

    setState(() {
      _quizResult = _QuizResult(
          score: score, passed: passed, results: results);
      _quizSubmitted = true;
    });
  }

  void _retakeQuiz() {
    setState(() {
      _answers.clear();
      _quizResult = null;
      _quizSubmitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(widget.lesson.title,
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVideoSection(),
            const SizedBox(height: 12),
            _buildWatchProgress(),
            const SizedBox(height: 16),
            _buildQuizSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(controller: _videoCtrl),
          ),
          if (!_isForeground)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 40),
                      SizedBox(height: 8),
                      Text('Video paused',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Come back to continue',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
          // Name watermark at 5 positions
          ..._buildWatermarks(_studentName),
        ],
      ),
    );
  }

  List<Widget> _buildWatermarks(String name) {
    const positions = [
      Alignment(-0.9, -0.85),
      Alignment(0.9, -0.85),
      Alignment(-0.9, 0.85),
      Alignment(0.9, 0.85),
      Alignment.center,
    ];
    return positions
        .map((a) => Positioned.fill(
              child: Align(
                alignment: a,
                child: Transform.rotate(
                  angle: -0.4,
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ))
        .toList();
  }

  Widget _buildWatchProgress() {
    final dur = widget.lesson.durationSeconds;
    final pct = dur > 0 ? (_watchSeconds / dur).clamp(0.0, 1.0) : 0.0;
    final unlockAt = (dur * _kUnlockThreshold).floor();
    final remaining = (unlockAt - _watchSeconds).clamp(0, unlockAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Watch progress',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              Text(
                '${_fmt(_watchSeconds)} / ${_fmt(dur)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation(
              _quizUnlocked ? const Color(0xFF10B981) : const Color(0xFF6366F1),
            ),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 6),
          Text(
            _quizUnlocked
                ? '✓ Quiz unlocked'
                : 'Watch ${_fmt(remaining)} more to unlock quiz',
            style: TextStyle(
              fontSize: 12,
              color: _quizUnlocked ? const Color(0xFF10B981) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizSection() {
    return Container(
      decoration: BoxDecoration(
        color: _quizUnlocked ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quiz — ${_questions.length} question${_questions.length != 1 ? "s" : ""}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (!_quizUnlocked)
                  _chip('🔒 Watch 70%', Colors.grey)
                else if (_progress?.quizPassed ?? false)
                  _chip('✓ Passed', const Color(0xFF059669)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (!_quizUnlocked)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Complete 70% of the video to unlock.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else if (_questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No questions for this lesson yet.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else if (_quizSubmitted && _quizResult != null)
            _buildResultsView()
          else
            _buildQuestionsView(),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );

  Widget _buildQuestionsView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((_progress?.quizAttempts ?? 0) > 0 && !(_progress?.quizPassed ?? false))
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Last score: ${_progress!.quizScore}% — you need 80%.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
              ),
            ),
          ..._questions.asMap().entries.map((e) => _buildQuestion(e.key, e.value)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed:
                _answers.length == _questions.length ? _submitQuiz : null,
            child: Text(
                'Submit Quiz (${_answers.length}/${_questions.length} answered)'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(int qi, Question q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${qi + 1}. ',
                  style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                TextSpan(
                  text: q.question,
                  style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ],
            ),
          ),
          if (q.source != null) ...[
            const SizedBox(height: 2),
            Text('📖 ${q.source}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
          const SizedBox(height: 8),
          ...q.options.asMap().entries
              .map((o) => _buildOption(qi, o.key, o.value)),
        ],
      ),
    );
  }

  Widget _buildOption(int qi, int oi, String text) {
    final selected = _answers[qi] == oi;
    return GestureDetector(
      onTap: () => setState(() => _answers[qi] = oi),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF6366F1)
                : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFCBD5E1),
                  width: 2,
                ),
                color:
                    selected ? const Color(0xFF6366F1) : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.circle, size: 10, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF334155),
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    final r = _quizResult!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: r.passed
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: r.passed
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFECACA)),
            ),
            child: Column(
              children: [
                Text(r.passed ? '🎉' : '😔',
                    style: const TextStyle(fontSize: 44)),
                const SizedBox(height: 8),
                Text('${r.score}%',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: r.passed
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                    )),
                Text(
                  r.passed
                      ? 'Congratulations! You passed.'
                      : 'Not quite — keep going!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: r.passed
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.passed
                      ? 'You may proceed to the next lesson.'
                      : 'You need 80% to pass. Try again.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._questions.asMap().entries.map((e) {
            final qi = e.key;
            final q = e.value;
            final qr = r.results[qi];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: qr.correct
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: qr.correct
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(qr.correct ? '✅' : '❌'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(q.question,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your answer: ${q.options[_answers[qi] ?? 0]}',
                    style: TextStyle(
                        fontSize: 12,
                        color: qr.correct
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626)),
                  ),
                  if (!qr.correct)
                    Text(
                      'Correct: ${q.options[qr.correctOptionIndex]}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF059669)),
                    ),
                  if (qr.explanation != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('💡 ${qr.explanation}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          if (!r.passed)
            ElevatedButton(onPressed: _retakeQuiz, child: const Text('Retake Quiz'))
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981)),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done ✓'),
            ),
        ],
      ),
    );
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return s == 0 ? '${m}m' : '${m}m ${s.toString().padLeft(2, "0")}s';
  }
}

class _QuizResult {
  final int score;
  final bool passed;
  final List<_QuizItemResult> results;
  const _QuizResult(
      {required this.score, required this.passed, required this.results});
}

class _QuizItemResult {
  final bool correct;
  final int correctOptionIndex;
  final String? explanation;
  const _QuizItemResult(
      {required this.correct,
      required this.correctOptionIndex,
      this.explanation});
}
