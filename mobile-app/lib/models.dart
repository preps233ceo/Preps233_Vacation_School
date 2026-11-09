/// Data models — mirror the Supabase schema
library;

class Subject {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String icon;
  final String color;
  final bool isActive;
  final int sortOrder;

  const Subject({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.sortOrder,
  });

  factory Subject.fromMap(Map<String, dynamic> m) => Subject(
        id: m['id'] as String,
        name: m['name'] as String,
        slug: m['slug'] as String,
        description: m['description'] as String?,
        icon: m['icon'] as String? ?? '📚',
        color: m['color'] as String? ?? '#6366f1',
        isActive: (m['is_active'] as int? ?? 1) == 1,
        sortOrder: m['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'icon': icon,
        'color': color,
        'is_active': isActive ? 1 : 0,
        'sort_order': sortOrder,
      };
}

class Topic {
  final String id;
  final String subjectId;
  final String title;
  final String slug;
  final String? description;
  final bool isActive;
  final int sortOrder;

  const Topic({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.slug,
    this.description,
    required this.isActive,
    required this.sortOrder,
  });

  factory Topic.fromMap(Map<String, dynamic> m) => Topic(
        id: m['id'] as String,
        subjectId: m['subject_id'] as String,
        title: m['title'] as String,
        slug: m['slug'] as String,
        description: m['description'] as String?,
        isActive: (m['is_active'] as int? ?? 1) == 1,
        sortOrder: m['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'slug': slug,
        'description': description,
        'is_active': isActive ? 1 : 0,
        'sort_order': sortOrder,
      };
}

class Lesson {
  final String id;
  final String topicId;
  final String title;
  final String? description;
  final String videoProvider;
  final String videoId;
  final int durationSeconds;
  final int sortOrder;
  final bool isActive;

  const Lesson({
    required this.id,
    required this.topicId,
    required this.title,
    this.description,
    required this.videoProvider,
    required this.videoId,
    required this.durationSeconds,
    required this.sortOrder,
    required this.isActive,
  });

  factory Lesson.fromMap(Map<String, dynamic> m) => Lesson(
        id: m['id'] as String,
        topicId: m['topic_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        videoProvider: m['video_provider'] as String? ?? 'google_drive',
        videoId: m['video_id'] as String? ?? '',
        durationSeconds: m['duration_seconds'] as int? ?? 0,
        sortOrder: m['sort_order'] as int? ?? 0,
        isActive: (m['is_active'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'topic_id': topicId,
        'title': title,
        'description': description,
        'video_provider': videoProvider,
        'video_id': videoId,
        'duration_seconds': durationSeconds,
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
      };

  /// Direct download URL — varies by provider
  String get downloadUrl {
    switch (videoProvider) {
      case 'google_drive':
        // Public Google Drive file: share → "Anyone with the link"
        return 'https://drive.google.com/uc?export=download&id=$videoId';
      case 'bunny':
        // videoId is the full CDN URL for Bunny.net
        return videoId;
      default:
        // Treat videoId as a direct URL
        return videoId;
    }
  }

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }
}

class Question {
  final String id;
  final String lessonId;
  final String question;
  final List<String> options;
  final int correctAnswer; // 0–3 index into options
  final String? explanation;
  final String? source;
  final int sortOrder;

  const Question({
    required this.id,
    required this.lessonId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.source,
    required this.sortOrder,
  });

  factory Question.fromMap(Map<String, dynamic> m) {
    List<String> opts;
    final raw = m['options'];
    if (raw is List) {
      opts = raw.map((e) => e.toString()).toList();
    } else if (raw is String) {
      // Stored as JSON string in SQLite
      opts = (raw.split('|||')).toList();
    } else {
      opts = [];
    }
    return Question(
      id: m['id'] as String,
      lessonId: m['lesson_id'] as String,
      question: m['question'] as String,
      options: opts,
      correctAnswer: m['correct_answer'] as int? ?? 0,
      explanation: m['explanation'] as String?,
      source: m['source'] as String?,
      sortOrder: m['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'lesson_id': lessonId,
        'question': question,
        'options': options.join('|||'), // SQLite-safe serialisation
        'correct_answer': correctAnswer,
        'explanation': explanation,
        'source': source,
        'sort_order': sortOrder,
      };
}

class LessonProgress {
  final String userId;
  final String lessonId;
  final int watchSeconds;
  final bool videoCompleted;
  final bool quizPassed;
  final int quizScore;
  final int quizAttempts;

  const LessonProgress({
    required this.userId,
    required this.lessonId,
    required this.watchSeconds,
    required this.videoCompleted,
    required this.quizPassed,
    required this.quizScore,
    required this.quizAttempts,
  });

  LessonProgress copyWith({
    int? watchSeconds,
    bool? videoCompleted,
    bool? quizPassed,
    int? quizScore,
    int? quizAttempts,
  }) =>
      LessonProgress(
        userId: userId,
        lessonId: lessonId,
        watchSeconds: watchSeconds ?? this.watchSeconds,
        videoCompleted: videoCompleted ?? this.videoCompleted,
        quizPassed: quizPassed ?? this.quizPassed,
        quizScore: quizScore ?? this.quizScore,
        quizAttempts: quizAttempts ?? this.quizAttempts,
      );

  factory LessonProgress.fromMap(Map<String, dynamic> m) => LessonProgress(
        userId: m['user_id'] as String,
        lessonId: m['lesson_id'] as String,
        watchSeconds: m['watch_seconds'] as int? ?? 0,
        videoCompleted: (m['video_completed'] as int? ?? 0) == 1,
        quizPassed: (m['quiz_passed'] as int? ?? 0) == 1,
        quizScore: m['quiz_score'] as int? ?? 0,
        quizAttempts: m['quiz_attempts'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'lesson_id': lessonId,
        'watch_seconds': watchSeconds,
        'video_completed': videoCompleted ? 1 : 0,
        'quiz_passed': quizPassed ? 1 : 0,
        'quiz_score': quizScore,
        'quiz_attempts': quizAttempts,
      };
}

class DownloadState {
  final String lessonId;
  final DownloadStatus status;
  final double progress; // 0.0 – 1.0
  final String? localPath;

  const DownloadState({
    required this.lessonId,
    required this.status,
    this.progress = 0,
    this.localPath,
  });
}

enum DownloadStatus { notDownloaded, downloading, downloaded, failed }
