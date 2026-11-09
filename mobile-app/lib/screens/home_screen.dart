import 'package:flutter/material.dart';
import '../config.dart';
import '../models.dart';
import '../services/db_service.dart';
import '../services/drive_service.dart';
import '../theme.dart';
import 'subject_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Subject>> _subjectsFuture;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = DbService.getSubjects();
  }

  Future<void> _refresh() async {
    setState(() => _syncing = true);
    try {
      await DriveService.syncContent();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sync — using cached content'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _subjectsFuture = DbService.getSubjects();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace:
            Container(decoration: const BoxDecoration(gradient: kHeaderGradient)),
        title: const Text('Preps233 Learn'),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white54),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.white70),
              tooltip: 'Sync content',
              onPressed: _refresh,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student greeting
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Hello, ${AppConfig.studentName} 👋',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Choose a subject to begin',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Subject>>(
              future: _subjectsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final subjects = snap.data ?? [];
                if (subjects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined,
                            size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No content yet',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Connect to the internet and tap sync.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync now'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: subjects.length,
                  itemBuilder: (context, i) =>
                      _SubjectCard(subject: subjects[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    Color accent;
    try {
      accent = Color(int.parse(subject.color.replaceAll('#', '0xFF')));
    } catch (_) {
      accent = const Color(0xFF6366F1);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SubjectScreen(subject: subject)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(subject.icon,
                      style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (subject.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subject.description!,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
