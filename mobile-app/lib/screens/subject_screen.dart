import 'package:flutter/material.dart';
import '../config.dart';
import '../models.dart';
import '../services/db_service.dart';
import '../theme.dart';
import 'topic_screen.dart';

class SubjectScreen extends StatefulWidget {
  final Subject subject;
  const SubjectScreen({super.key, required this.subject});

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  late Future<_SubjectData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SubjectData> _load() async {
    final topics = await DbService.getTopicsForSubject(widget.subject.id);
    final uid = AppConfig.deviceId;
    final Map<String, int> lessonCounts = {};
    final Map<String, int> passedCounts = {};
    for (final t in topics) {
      final lessons = await DbService.getLessonsForTopic(t.id);
      lessonCounts[t.id] = lessons.length;
      final prog = await DbService.getProgressForTopic(uid, t.id);
      passedCounts[t.id] = prog.values.where((p) => p.quizPassed).length;
    }
    return _SubjectData(
        topics: topics,
        lessonCounts: lessonCounts,
        passedCounts: passedCounts);
  }

  Color get _accent {
    try {
      return Color(
          int.parse(widget.subject.color.replaceAll('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_SubjectData>(
        future: _future,
        builder: (context, snap) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 150,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(widget.subject.name),
                  background: Container(
                    decoration:
                        const BoxDecoration(gradient: kHeaderGradient),
                    child: Center(
                      child: Text(widget.subject.icon,
                          style: const TextStyle(fontSize: 60)),
                    ),
                  ),
                ),
              ),
              if (snap.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
              else if (snap.hasError)
                SliverFillRemaining(
                    child: Center(child: Text('Error: ${snap.error}')))
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final topics = snap.data!.topics;
                        if (i >= topics.length) return null;
                        final topic = topics[i];
                        final count =
                            snap.data!.lessonCounts[topic.id] ?? 0;
                        final passed =
                            snap.data!.passedCounts[topic.id] ?? 0;
                        return _TopicCard(
                          topic: topic,
                          index: i,
                          lessonCount: count,
                          passedCount: passed,
                          progress: count > 0 ? passed / count : 0.0,
                          accent: _accent,
                        );
                      },
                      childCount: snap.data?.topics.length ?? 0,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SubjectData {
  final List<Topic> topics;
  final Map<String, int> lessonCounts;
  final Map<String, int> passedCounts;
  _SubjectData(
      {required this.topics,
      required this.lessonCounts,
      required this.passedCounts});
}

class _TopicCard extends StatelessWidget {
  final Topic topic;
  final int index;
  final int lessonCount;
  final int passedCount;
  final double progress;
  final Color accent;

  const _TopicCard({
    required this.topic,
    required this.index,
    required this.lessonCount,
    required this.passedCount,
    required this.progress,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TopicScreen(topic: topic)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${index + 1}',
                          style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: accent),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation(accent),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              const SizedBox(height: 6),
              Text(
                '$lessonCount lesson${lessonCount != 1 ? "s" : ""}  ·  $passedCount passed',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
