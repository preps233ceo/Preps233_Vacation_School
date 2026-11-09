import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models.dart';

class DbService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'preps233_v1.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE subjects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            slug TEXT NOT NULL,
            description TEXT,
            icon TEXT NOT NULL,
            color TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE topics (
            id TEXT PRIMARY KEY,
            subject_id TEXT NOT NULL,
            title TEXT NOT NULL,
            slug TEXT NOT NULL,
            description TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE lessons (
            id TEXT PRIMARY KEY,
            topic_id TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            video_provider TEXT NOT NULL,
            video_id TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE questions (
            id TEXT PRIMARY KEY,
            lesson_id TEXT NOT NULL,
            question TEXT NOT NULL,
            options TEXT NOT NULL,
            correct_answer INTEGER NOT NULL,
            explanation TEXT,
            source TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE lesson_progress (
            user_id TEXT NOT NULL,
            lesson_id TEXT NOT NULL,
            watch_seconds INTEGER NOT NULL DEFAULT 0,
            video_completed INTEGER NOT NULL DEFAULT 0,
            quiz_passed INTEGER NOT NULL DEFAULT 0,
            quiz_score INTEGER NOT NULL DEFAULT 0,
            quiz_attempts INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (user_id, lesson_id)
          )
        ''');
      },
    );
  }

  // ── Subjects ────────────────────────────────────────────────────────────────

  static Future<void> upsertSubjects(List<Subject> items) async {
    final d = await db;
    final batch = d.batch();
    for (final s in items) {
      batch.insert('subjects', s.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Subject>> getSubjects() async {
    final d = await db;
    final rows =
        await d.query('subjects', where: 'is_active = 1', orderBy: 'sort_order');
    return rows.map(Subject.fromMap).toList();
  }

  // ── Topics ──────────────────────────────────────────────────────────────────

  static Future<void> upsertTopics(List<Topic> items) async {
    final d = await db;
    final batch = d.batch();
    for (final t in items) {
      batch.insert('topics', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Topic>> getTopicsForSubject(String subjectId) async {
    final d = await db;
    final rows = await d.query('topics',
        where: 'subject_id = ? AND is_active = 1',
        whereArgs: [subjectId],
        orderBy: 'sort_order');
    return rows.map(Topic.fromMap).toList();
  }

  // ── Lessons ─────────────────────────────────────────────────────────────────

  static Future<void> upsertLessons(List<Lesson> items) async {
    final d = await db;
    final batch = d.batch();
    for (final l in items) {
      batch.insert('lessons', l.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Lesson>> getLessonsForTopic(String topicId) async {
    final d = await db;
    final rows = await d.query('lessons',
        where: 'topic_id = ? AND is_active = 1',
        whereArgs: [topicId],
        orderBy: 'sort_order');
    return rows.map(Lesson.fromMap).toList();
  }

  static Future<Lesson?> getLesson(String lessonId) async {
    final d = await db;
    final rows =
        await d.query('lessons', where: 'id = ?', whereArgs: [lessonId]);
    if (rows.isEmpty) return null;
    return Lesson.fromMap(rows.first);
  }

  // ── Questions ────────────────────────────────────────────────────────────────

  static Future<void> upsertQuestions(List<Question> items) async {
    final d = await db;
    final batch = d.batch();
    for (final q in items) {
      batch.insert('questions', q.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Question>> getQuestionsForLesson(String lessonId) async {
    final d = await db;
    final rows = await d.query('questions',
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
        orderBy: 'sort_order');
    return rows.map(Question.fromMap).toList();
  }

  // ── Progress ─────────────────────────────────────────────────────────────────

  static Future<LessonProgress?> getProgress(
      String userId, String lessonId) async {
    final d = await db;
    final rows = await d.query('lesson_progress',
        where: 'user_id = ? AND lesson_id = ?',
        whereArgs: [userId, lessonId]);
    if (rows.isEmpty) return null;
    return LessonProgress.fromMap(rows.first);
  }

  static Future<Map<String, LessonProgress>> getProgressForTopic(
      String userId, String topicId) async {
    final d = await db;
    // Join lessons with progress
    final lessons = await getLessonsForTopic(topicId);
    final lessonIds = lessons.map((l) => l.id).toList();
    if (lessonIds.isEmpty) return {};

    final placeholders = lessonIds.map((_) => '?').join(',');
    final rows = await d.rawQuery(
      'SELECT * FROM lesson_progress WHERE user_id = ? AND lesson_id IN ($placeholders)',
      [userId, ...lessonIds],
    );

    return {for (final r in rows) r['lesson_id'] as String: LessonProgress.fromMap(r)};
  }

  static Future<void> upsertProgress(LessonProgress p) async {
    final d = await db;
    await d.insert('lesson_progress', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateWatchProgress(
      String userId, String lessonId, int watchSeconds, bool completed) async {
    final existing = await getProgress(userId, lessonId);
    final updated = (existing ??
            LessonProgress(
              userId: userId,
              lessonId: lessonId,
              watchSeconds: 0,
              videoCompleted: false,
              quizPassed: false,
              quizScore: 0,
              quizAttempts: 0,
            ))
        .copyWith(
      watchSeconds: watchSeconds,
      videoCompleted: completed,
    );
    await upsertProgress(updated);
  }

  static Future<void> saveQuizResult(
      String userId, String lessonId, int score, bool passed, int attempts) async {
    final existing = await getProgress(userId, lessonId);
    final prev = existing ??
        LessonProgress(
          userId: userId,
          lessonId: lessonId,
          watchSeconds: 0,
          videoCompleted: false,
          quizPassed: false,
          quizScore: 0,
          quizAttempts: 0,
        );
    // Preserve best score and once-passed-stays-passed
    final updated = prev.copyWith(
      quizScore: score > prev.quizScore ? score : prev.quizScore,
      quizPassed: passed || prev.quizPassed,
      quizAttempts: attempts,
    );
    await upsertProgress(updated);
  }
}
