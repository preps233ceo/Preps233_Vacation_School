import 'dart:convert';
import 'package:dio/dio.dart';
import '../config.dart';
import '../models.dart';
import 'db_service.dart';

/// Downloads content.json from Google Drive and caches it in local SQLite.
/// Videos are downloaded separately via DownloadService.
class DriveService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    followRedirects: true,
    validateStatus: (s) => s != null && s < 400,
  ));

  /// URL that serves a public Google Drive file as raw bytes.
  /// Works for small files like content.json.
  static String _fileUrl(String fileId) =>
      'https://drive.google.com/uc?export=download&id=$fileId';

  /// Download URL for large video files — appending confirm=t bypasses the
  /// "too large to scan for viruses" warning page on Drive.
  static String videoDownloadUrl(String driveFileId) =>
      'https://drive.google.com/uc?export=download&confirm=t&id=$driveFileId';

  // ── Content sync ─────────────────────────────────────────────────────────────

  /// Fetches content.json from Drive and upserts everything into SQLite.
  /// Call this on launch (and on manual refresh).
  static Future<void> syncContent() async {
    final url = _fileUrl(kContentFileId);
    final response = await _dio.get<String>(url,
        options: Options(responseType: ResponseType.plain));

    final Map<String, dynamic> root = jsonDecode(response.data!);
    final subjects = root['subjects'] as List;

    for (final sRaw in subjects) {
      final s = sRaw as Map<String, dynamic>;
      final subject = Subject(
        id: s['id'] as String,
        name: s['name'] as String,
        slug: (s['id'] as String).replaceAll(' ', '-').toLowerCase(),
        description: s['description'] as String?,
        icon: s['icon'] as String? ?? '📚',
        color: s['color'] as String? ?? '#6366f1',
        isActive: true,
        sortOrder: s['sort_order'] as int? ?? 0,
      );
      await DbService.upsertSubjects([subject]);

      final topics = (s['topics'] as List?) ?? [];
      for (final tRaw in topics) {
        final t = tRaw as Map<String, dynamic>;
        final topic = Topic(
          id: t['id'] as String,
          subjectId: subject.id,
          title: t['title'] as String,
          slug: (t['id'] as String).replaceAll(' ', '-').toLowerCase(),
          description: t['description'] as String?,
          isActive: true,
          sortOrder: t['sort_order'] as int? ?? 0,
        );
        await DbService.upsertTopics([topic]);

        final lessons = (t['lessons'] as List?) ?? [];
        for (final lRaw in lessons) {
          final l = lRaw as Map<String, dynamic>;
          final durationSeconds =
              ((l['duration_minutes'] as num? ?? 0) * 60).round();
          final lesson = Lesson(
            id: l['id'] as String,
            topicId: topic.id,
            title: l['title'] as String,
            description: l['description'] as String?,
            videoProvider: 'google_drive',
            videoId: l['video_drive_id'] as String? ?? '',
            durationSeconds: durationSeconds,
            sortOrder: l['sort_order'] as int? ?? 0,
            isActive: true,
          );
          await DbService.upsertLessons([lesson]);

          final questions = (l['questions'] as List?) ?? [];
          final questionModels = questions.asMap().entries.map((e) {
            final i = e.key;
            final q = e.value as Map<String, dynamic>;
            return Question(
              id: q['id'] as String? ?? '${lesson.id}_q$i',
              lessonId: lesson.id,
              question: q['question'] as String,
              options: (q['options'] as List).map((o) => o.toString()).toList(),
              correctAnswer: q['correct_answer'] as int,
              explanation: q['explanation'] as String?,
              source: q['source'] as String?,
              sortOrder: i,
            );
          }).toList();
          await DbService.upsertQuestions(questionModels);
        }
      }
    }

    await AppConfig.setLastSynced();
  }
}
