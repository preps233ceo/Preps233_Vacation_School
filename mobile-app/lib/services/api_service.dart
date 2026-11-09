import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import 'db_service.dart';

/// Fetches content from Supabase and caches it in local SQLite.
class ApiService {
  static SupabaseClient get _client => Supabase.instance.client;

  static String? get userId => _client.auth.currentUser?.id;
  static String? get userEmail => _client.auth.currentUser?.email;

  // ── Auth ─────────────────────────────────────────────────────────────────────

  static Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signUp(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static bool get isSignedIn => _client.auth.currentUser != null;

  // ── Content sync ─────────────────────────────────────────────────────────────

  /// Fetches all active subjects, topics, lessons, and questions from Supabase
  /// and caches them in local SQLite. Call once after sign-in.
  static Future<void> syncAll() async {
    await Future.wait([
      syncSubjects(),
      // topics/lessons/questions sync per subject when needed
    ]);
  }

  static Future<void> syncSubjects() async {
    final rows = await _client
        .from('subjects')
        .select('*')
        .eq('is_active', true)
        .order('sort_order');

    final subjects =
        (rows as List).map((r) => Subject.fromMap(_fixBool(r))).toList();
    await DbService.upsertSubjects(subjects);
  }

  static Future<void> syncTopicsForSubject(String subjectId) async {
    final rows = await _client
        .from('topics')
        .select('*')
        .eq('subject_id', subjectId)
        .eq('is_active', true)
        .order('sort_order');

    final topics =
        (rows as List).map((r) => Topic.fromMap(_fixBool(r))).toList();
    await DbService.upsertTopics(topics);
  }

  static Future<void> syncLessonsForTopic(String topicId) async {
    final rows = await _client
        .from('lessons')
        .select('*')
        .eq('topic_id', topicId)
        .eq('is_active', true)
        .order('sort_order');

    final lessons =
        (rows as List).map((r) => Lesson.fromMap(_fixBool(r))).toList();
    await DbService.upsertLessons(lessons);
  }

  static Future<void> syncQuestionsForLesson(String lessonId) async {
    final rows = await _client
        .from('questions')
        .select('id, lesson_id, question, options, correct_answer, explanation, source, sort_order')
        .eq('lesson_id', lessonId)
        .order('sort_order');

    final questions = (rows as List).map((r) {
      // options in Supabase is a jsonb array — convert to list
      final opts = (r['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
      return Question(
        id: r['id'] as String,
        lessonId: r['lesson_id'] as String,
        question: r['question'] as String,
        options: opts,
        correctAnswer: r['correct_answer'] as int? ?? 0,
        explanation: r['explanation'] as String?,
        source: r['source'] as String?,
        sortOrder: r['sort_order'] as int? ?? 0,
      );
    }).toList();
    await DbService.upsertQuestions(questions);
  }

  // ── Progress sync ─────────────────────────────────────────────────────────────

  /// Push local progress to Supabase (best-effort — works offline)
  static Future<void> pushProgress(LessonProgress p) async {
    if (!isSignedIn) return;
    try {
      await _client.from('lesson_progress').upsert({
        'user_id': p.userId,
        'lesson_id': p.lessonId,
        'watch_seconds': p.watchSeconds,
        'video_completed': p.videoCompleted,
        'quiz_passed': p.quizPassed,
        'quiz_score': p.quizScore,
        'quiz_attempts': p.quizAttempts,
      });
    } catch (_) {
      // Offline — will sync next session
    }
  }

  /// Pull progress from Supabase and merge into local SQLite
  static Future<void> pullProgress() async {
    if (!isSignedIn) return;
    try {
      final uid = userId!;
      final rows = await _client
          .from('lesson_progress')
          .select('*')
          .eq('user_id', uid);

      for (final r in (rows as List)) {
        final p = LessonProgress.fromMap(_fixBool(r));
        await DbService.upsertProgress(p);
      }
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  /// Supabase returns booleans as actual bools; SQLite stores them as 0/1.
  /// This converts a Supabase row to SQLite-compatible ints for our models.
  static Map<String, dynamic> _fixBool(Map<String, dynamic> r) {
    return r.map((k, v) {
      if (v is bool) return MapEntry(k, v ? 1 : 0);
      return MapEntry(k, v);
    });
  }
}
