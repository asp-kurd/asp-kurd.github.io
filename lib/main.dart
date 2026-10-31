import 'package:flutter/material.dart';

import 'data/book.dart';
import 'data/curriculum.dart';
import 'data/exams.dart';
import 'screens/account_screens.dart';
import 'services/backend.dart';
import 'services/updater_stub.dart' if (dart.library.js_interop) 'services/updater_web.dart';
import 'screens/home_screen.dart';
import 'screens/mascot_demo.dart';
import 'screens/onboarding_screen.dart';
import 'services/clone_service.dart';
import 'services/progress_service.dart';
import 'services/voice_service.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  startAutoUpdate(const String.fromEnvironment('BUILD_ID'));
  await Backend.instance.init();
  await loadCurriculum(await Backend.instance.contentOverride('curriculum'));
  await loadBook();
  await Exams.load();
  await ProgressService.instance.init();
  await VoiceService.instance.init();
  await CloneService.instance.load();
  runApp(const ZimanProApp());
}

class ZimanProApp extends StatelessWidget {
  const ZimanProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // لاتینی/ئەلمانی ب League Gothic؛ هەر پیتەکا کوردی/عەرەبی ب Shasenem
        fontFamily: 'LeagueGothic',
        fontFamilyFallback: const ['Shasenem', 'Sarchia'],
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue, brightness: Brightness.dark),
        scaffoldBackgroundColor: AppColors.bg,
        appBarTheme: const AppBarTheme(backgroundColor: AppColors.bg, elevation: 0),
      ),
      home: Uri.base.queryParameters['demo'] == 'mascot'
          ? const MascotDemo()
          : !ProgressService.instance.onboarded
          ? const LanguageOnboardingScreen()
          : (Backend.instance.enabled && !Backend.instance.registered && !Backend.instance.isAdmin)
              ? const RegisterScreen(next: HomeScreen())
              : SetupScreen.needed()
                  ? const SetupScreen(next: HomeScreen())
                  : const HomeScreen(),
    );
  }
}
