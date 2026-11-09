# Preps233 Learn — Android & Windows App

Offline-first mobile/desktop app. Download videos once, study anywhere — no internet needed.

## What you get
- **Android APK** — install on any Android 6+ phone or tablet
- **Windows EXE** — runs on Windows 10/11
- Videos downloaded to device storage
- Full quiz system works offline
- Progress syncs to cloud when you reconnect

---

## Prerequisites

Install Flutter SDK (free):
1. Download from https://flutter.dev/docs/get-started/install
2. Add `flutter/bin` to your PATH
3. Run `flutter doctor` and fix any warnings

For Android builds: install Android Studio and accept SDK licenses.
For Windows builds: requires Visual Studio 2022 with C++ workload.

---

## 1. Configure Supabase

Open `lib/main.dart` and replace:
```dart
const _supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
const _supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
```
Use the same Supabase project you set up for the web platform.
The database schema is shared — no changes needed.

---

## 2. Install dependencies

```bash
cd mobile-app
flutter pub get
```

---

## 3. Run in development

```bash
# Android (with device/emulator connected)
flutter run -d android

# Windows desktop
flutter run -d windows
```

---

## 4. Build for release

### Android APK (sideload — no Play Store needed)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

Send this APK to students via WhatsApp, school website, USB, or Google Drive. They tap it to install (may need to enable "Install from unknown sources" in Android settings).

### Windows installer
```bash
flutter build windows --release
```
Output: `build/windows/x64/runner/Release/`

Zip that folder and share it, or use Inno Setup to create a `.exe` installer.

---

## 5. Uploading videos for download

### Option A: Google Drive (free, up to ~100 downloads/day per file)
1. Upload your `.mp4` file to Google Drive
2. Right-click → Share → "Anyone with the link can view"
3. Copy the File ID from the URL: `drive.google.com/file/d/**FILE_ID**/view`
4. In the admin panel (web), add a lesson:
   - Video provider: `google_drive`
   - Video ID: paste the File ID

The app downloads from: `https://drive.google.com/uc?export=download&id=FILE_ID`

> **Note:** Google Drive shows a "can't scan for viruses" warning for large files. Students tap "Download anyway". This is fine for school use.

### Option B: Bunny.net Stream (~$10/month, unlimited)
1. Create a Bunny.net account → Storage Zone → upload videos
2. Set the video's CDN URL as the Video ID in the admin panel
3. Change video provider to `bunny`

Bunny.net gives direct download links with no quota limits — recommended for more than ~100 students.

### Option C: USB Drive / Local Folder
Students can copy `.mp4` files from a USB drive into the app manually:
- The lesson screen has an "Import from file" option
- Students paste the file path or use a file picker
- File is copied to app storage and plays offline

This is perfect for schools with no internet at all — distribute USB drives with video files.

---

## 6. Distributing to students

**Android:**
- Share the APK via WhatsApp, email, or school website
- Or set up a simple page at preps233.com/download

**Windows:**
- Zip `build/windows/x64/runner/Release/` and share it
- Or upload to preps233.com/download
- Students extract and run `preps233_learn.exe`

---

## Architecture notes

| Layer | Technology |
|-------|-----------|
| UI | Flutter (Dart) |
| Local DB | SQLite (`sqflite`) |
| Cloud sync | Supabase (same project as web) |
| Video player | media_kit (libmpv) |
| Video download | Dio |
| Auth | Supabase Auth |

**Offline-first:** All content (subjects, topics, lessons, questions) is cached in a local SQLite database after first sync. Quiz scoring happens on-device — no internet needed once videos are downloaded.

**Security note:** Because quizzes run offline, correct answers are stored locally in the SQLite database. For a school setting this is acceptable — determined students could technically extract them, but most won't. If this is a concern, keep high-stakes assessments on the web platform where answers never leave the server.

---

## Scaling to new subjects

The same Flutter app automatically supports Physics, Chemistry, Biology, and Electrical Engineering — they're controlled by the admin panel on the web. Mark a subject `is_active = true` and the app shows it on next sync.
