import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models.dart';

/// Manages downloading video files to device storage.
class DownloadService {
  static final Dio _dio = Dio();

  // In-memory download state — keyed by lessonId
  static final Map<String, DownloadState> _states = {};
  static final Map<String, CancelToken> _tokens = {};
  static final List<void Function()> _listeners = [];

  static void addListener(void Function() fn) => _listeners.add(fn);
  static void removeListener(void Function() fn) => _listeners.remove(fn);
  static void _notify() {
    for (final fn in _listeners) fn();
  }

  static DownloadState stateFor(String lessonId) =>
      _states[lessonId] ??
      DownloadState(
          lessonId: lessonId,
          status: DownloadStatus.notDownloaded);

  // ── Paths ────────────────────────────────────────────────────────────────────

  static Future<Directory> get _videosDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'preps233', 'videos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> _videoPath(String lessonId) async {
    final dir = await _videosDir;
    return p.join(dir.path, '$lessonId.mp4');
  }

  // ── Checks ───────────────────────────────────────────────────────────────────

  static Future<bool> isDownloaded(String lessonId) async {
    final path = await _videoPath(lessonId);
    return File(path).existsSync();
  }

  static Future<String?> localPath(String lessonId) async {
    final path = await _videoPath(lessonId);
    return File(path).existsSync() ? path : null;
  }

  /// Scan all lesson IDs and populate in-memory state from disk.
  static Future<void> initStates(List<String> lessonIds) async {
    for (final id in lessonIds) {
      final path = await _videoPath(id);
      if (File(path).existsSync()) {
        _states[id] = DownloadState(
            lessonId: id,
            status: DownloadStatus.downloaded,
            progress: 1.0,
            localPath: path);
      }
    }
    _notify();
  }

  // ── Download ─────────────────────────────────────────────────────────────────

  static Future<void> download(Lesson lesson) async {
    final id = lesson.id;
    if (_states[id]?.status == DownloadStatus.downloading) return;
    if (_states[id]?.status == DownloadStatus.downloaded) return;

    final savePath = await _videoPath(id);
    final cancel = CancelToken();
    _tokens[id] = cancel;

    _states[id] = DownloadState(
        lessonId: id, status: DownloadStatus.downloading, progress: 0);
    _notify();

    try {
      await _dio.download(
        lesson.downloadUrl,
        savePath,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          _states[id] = DownloadState(
            lessonId: id,
            status: DownloadStatus.downloading,
            progress: received / total,
          );
          _notify();
        },
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 400,
        ),
      );

      _states[id] = DownloadState(
        lessonId: id,
        status: DownloadStatus.downloaded,
        progress: 1.0,
        localPath: savePath,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _states[id] =
            DownloadState(lessonId: id, status: DownloadStatus.notDownloaded);
        // Clean up partial file
        final f = File(savePath);
        if (await f.exists()) await f.delete();
      } else {
        _states[id] =
            DownloadState(lessonId: id, status: DownloadStatus.failed);
      }
    } finally {
      _tokens.remove(id);
      _notify();
    }
  }

  static void cancel(String lessonId) {
    _tokens[lessonId]?.cancel('User cancelled');
  }

  static Future<void> delete(String lessonId) async {
    cancel(lessonId);
    final path = await _videoPath(lessonId);
    final f = File(path);
    if (await f.exists()) await f.delete();
    _states[lessonId] =
        DownloadState(lessonId: lessonId, status: DownloadStatus.notDownloaded);
    _notify();
  }

  /// Load video from a local folder (USB drive / network share).
  /// Copies the file to the app's private directory so it works offline.
  static Future<bool> importFromFile(String lessonId, String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;
      final dest = await _videoPath(lessonId);
      await src.copy(dest);
      _states[lessonId] = DownloadState(
        lessonId: lessonId,
        status: DownloadStatus.downloaded,
        progress: 1.0,
        localPath: dest,
      );
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }
}
