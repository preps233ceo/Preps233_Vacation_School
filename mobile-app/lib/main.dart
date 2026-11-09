import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

// ── Configure these before building ─────────────────────────────────────────
// 1. Create a Supabase project at https://supabase.com
// 2. Run supabase/schema.sql from the web platform folder
// 3. Paste your project URL and anon key below
const _supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
const _supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop SQLite driver (Windows / Linux)
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Cross-platform video player
  MediaKit.ensureInitialized();

  // Allow both orientations on mobile
  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(const Preps233App());
}

class Preps233App extends StatelessWidget {
  const Preps233App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Preps233 Learn',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const SplashScreen(),
    );
  }
}
