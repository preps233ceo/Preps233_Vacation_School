import 'package:flutter/material.dart';
import '../config.dart';
import '../services/drive_service.dart';
import '../theme.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Loading…';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // First launch — ask for student name
    if (!AppConfig.hasName) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      return;
    }

    // Try to sync content from Drive (skip if offline / already synced today)
    final lastSync = AppConfig.lastSynced;
    final shouldSync = lastSync == null ||
        DateTime.now().difference(lastSync).inHours >= 24;

    if (shouldSync) {
      setState(() => _status = 'Syncing content…');
      try {
        await DriveService.syncContent();
      } catch (_) {
        // Offline — use cached content
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kHeaderGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Preps233',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'LEARN',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 56),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
