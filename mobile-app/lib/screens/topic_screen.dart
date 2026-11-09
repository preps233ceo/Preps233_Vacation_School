import 'package:flutter/material.dart';
import '../config.dart';
import '../models.dart';
import '../services/db_service.dart';
import '../services/download_service.dart';
import '../theme.dart';
import 'lesson_screen.dart';

class TopicScreen extends StatefulWidget {
  final Topic topic;
  const TopicScreen({super.key, required this.topic});

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  late Future<_TopicData> _future;

  @override
  void initState() {
    super.initState();
    DownloadService.addListener(_onDownloadChange);
    _future = _load();
  }

  @override
  void dispose() {
    DownloadService.removeListener(_onDownloadChange);
    super.dispose();
  }

  void _onDownloadChange() {
    if (mounted) setState(() {});
  }

  Future<_TopicData> _load() async {
    final lessons = await DbService.getLessonsForTopic(widget.topic.id);
    final uid = AppConfig.deviceId;
    final progress = await DbService.getProgressForTopic(uid, widget.topic.id);
    await DownloadService.initStates(lessons.map((l) => l.id).toList());
    return _TopicData(lessons: lessons, progress: progress);
  }

  bool _isUnlocked(
      int index, List<Lesson> lessons, Map<String, LessonProgress> progress) {
    if (index == 0) return true;
    return progress[lessons[index - 1].id]?.quizPassed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace:
            Container(decoration: const BoxDecoration(gradient: kHeaderGradient)),
        title: Text(widget.topic.title),
      ),
      body: FutureBuilder<_TopicData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final lessons = snap.data!.lessons;
          final progress = snap.data!.progress;
          if (lessons.isEmpty) {
            return const Center(
              child: Text('No lessons yet.',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lessons.length,
            itemBuilder: (context, i) {
              final lesson = lessons[i];
              final prog = progress[lesson.id];
              final unlocked = _isUnlocked(i, lessons, progress);
              final dlState = DownloadService.stateFor(lesson.id);

              return _LessonCard(
                lesson: lesson,
                index: i,
                progress: prog,
                unlocked: unlocked,
                downloadState: dlState,
                onDownload: () => DownloadService.download(lesson),
                onDelete: () async {
                  await DownloadService.delete(lesson.id);
                  setState(() {});
                },
                onTap: unlocked &&
                        dlState.status == DownloadStatus.downloaded
                    ? () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => LessonScreen(
                              lesson: lesson,
                              localPath: dlState.localPath!,
                            ),
                          ),
                        );
                        if (result == true) {
                          setState(() { _future = _load(); });
                        }
                      }
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _TopicData {
  final List<Lesson> lessons;
  final Map<String, LessonProgress> progress;
  _TopicData({required this.lessons, required this.progress});
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final int index;
  final LessonProgress? progress;
  final bool unlocked;
  final DownloadState downloadState;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const _LessonCard({
    required this.lesson,
    required this.index,
    required this.progress,
    required this.unlocked,
    required this.downloadState,
    required this.onDownload,
    required this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final quizPassed = progress?.quizPassed ?? false;
    final watchPct = lesson.durationSeconds > 0
        ? ((progress?.watchSeconds ?? 0) / lesson.durationSeconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: quizPassed
                          ? const Color(0xFFD1FAE5)
                          : unlocked
                              ? const Color(0xFFEEF2FF)
                              : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        quizPassed
                            ? Icons.check_circle
                            : unlocked
                                ? Icons.play_circle_outline
                                : Icons.lock_outline,
                        color: quizPassed
                            ? const Color(0xFF10B981)
                            : unlocked
                                ? const Color(0xFF6366F1)
                                : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: unlocked
                                ? const Color(0xFF1E293B)
                                : Colors.grey,
                          ),
                        ),
                        Text(lesson.formattedDuration,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  _DownloadButton(
                    state: downloadState,
                    onDownload: onDownload,
                    onDelete: onDelete,
                  ),
                ],
              ),
              if (unlocked && watchPct > 0) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: watchPct,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation(
                    quizPassed
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6366F1),
                  ),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 4,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final DownloadState state;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _DownloadButton({
    required this.state,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case DownloadStatus.notDownloaded:
        return IconButton(
          icon: const Icon(Icons.download_outlined),
          color: const Color(0xFF6366F1),
          tooltip: 'Download video',
          onPressed: onDownload,
        );
      case DownloadStatus.downloading:
        return SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: state.progress,
                strokeWidth: 3,
                color: const Color(0xFF6366F1),
              ),
              Text(
                '${(state.progress * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      case DownloadStatus.downloaded:
        return IconButton(
          icon: const Icon(Icons.check_circle_outline),
          color: const Color(0xFF10B981),
          tooltip: 'Downloaded',
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete downloaded video?'),
              content: const Text(
                  'You can re-download it any time you have internet.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.error_outline),
          color: Colors.red,
          tooltip: 'Failed — tap to retry',
          onPressed: onDownload,
        );
    }
  }
}
