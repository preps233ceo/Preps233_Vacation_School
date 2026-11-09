import 'package:flutter/material.dart';
import '../models.dart';
import '../services/db_service.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'subject_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Subject>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = DbService.getSubjects();
  }

  Future<void> _refresh() async {
    try {
      await ApiService.syncSubjects();
    } catch (_) {}
    setState(() {
      _subjectsFuture = DbService.getSubjects();
    });
  }

  Future<void> _signOut() async {
    await ApiService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: kHeaderGradient)),
        title: const Text('Preps233 Learn'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, size: 16, color: Colors.white54),
              label: Text(
                ApiService.userEmail ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Subject>>(
          future: _subjectsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final subjects = snap.data ?? [];
            if (subjects.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No subjects yet', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    TextButton(onPressed: _refresh, child: const Text('Refresh')),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: subjects.length,
              itemBuilder: (context, i) => _SubjectCard(subject: subjects[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    // Parse hex color like "#6366f1"
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(subject.icon, style: const TextStyle(fontSize: 28)),
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
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey),
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
