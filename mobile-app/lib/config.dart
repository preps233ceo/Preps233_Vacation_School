import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// ── CONFIGURE THIS ───────────────────────────────────────────────────────────
/// 1. Upload content.json to your Google Drive
/// 2. Right-click → Share → "Anyone with the link can view"
/// 3. Copy the file ID from the URL:
///    drive.google.com/file/d/  >>>FILE_ID<<<  /view
/// 4. Paste it below:
const kContentFileId = 'YOUR_CONTENT_JSON_FILE_ID';
/// ─────────────────────────────────────────────────────────────────────────────

/// App-wide state that persists between launches
class AppConfig {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Generate a stable device ID on first launch
    if (_prefs!.getString('device_id') == null) {
      await _prefs!.setString('device_id', const Uuid().v4());
    }
  }

  static String get deviceId => _prefs?.getString('device_id') ?? 'unknown';
  static String get studentName => _prefs?.getString('student_name') ?? '';
  static bool get hasName => studentName.isNotEmpty;

  static Future<void> setStudentName(String name) async {
    await _prefs?.setString('student_name', name.trim());
  }

  static DateTime? get lastSynced {
    final ms = _prefs?.getInt('last_synced');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setLastSynced() async {
    await _prefs?.setInt(
        'last_synced', DateTime.now().millisecondsSinceEpoch);
  }
}
