import 'dart:async';
import 'package:flutter/material.dart';

import 'data/book.dart';
import 'data/curriculum.dart';
import 'data/exams.dart';
import 'screens/account_screens.dart';
import 'screens/admin_screens.dart';
import 'services/backend.dart';
import 'services/push_stub.dart' if (dart.library.js_interop) 'services/push_web.dart';
import 'services/updater_stub.dart' if (dart.library.js_interop) 'services/updater_web.dart';
import 'screens/character_screen.dart';
import 'screens/book_screen.dart';
import 'screens/games/extra_games.dart';
import 'screens/games/games_hub.dart';
import 'screens/games/goethe_mock.dart';
import 'screens/grammar_screen.dart';
import 'screens/voice_backup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mascot_demo.dart';
import 'screens/onboarding_screen.dart';
import 'services/clone_service.dart';
import 'services/progress_service.dart';
import 'services/theme_service.dart';
import 'services/voice_service.dart';
import 'screens/lesson_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/streak_screen.dart';
import 'screens/widgets/combo.dart' show ToastDemo;
import 'models.dart';
import 'ui.dart';

/// ئیمەیلا هەژمارێ ژ لینکێ ئەپا سەر شاشێ (پاسۆرد پێدڤییە)
String? handoffEmail;

/// 🛡️ پەڕێ ئەدمینی تنێ ب ڤی لینکی ڤەدبیت: https://asp-poya.com/?admin=asp-d7k2
const _adminKey = 'asp-d7k2';
/// یان پەڕێ جودا: https://asp-poya.com/asp-d7k2/ (بۆ Home Screen)
final bool adminMode = Uri.base.queryParameters['admin'] == _adminKey || isAdminPage;

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
  await ThemeController.instance.load();
  // 📲 iPhone: ئەپا سەر شاشێ ب کۆدێ لینکی هەمان هەژمار بەردەوام دکەت (نە ژ نوی)
  final handoff = Uri.base.queryParameters['h'];
  if (adminMode && !isAdminPage) prepareAdminHomeScreen();
  if (!adminMode && handoff != null && Backend.instance.enabled && !Backend.instance.registered) {
    try {
      final res = await Backend.instance.handoffLogin(handoff).timeout(const Duration(seconds: 12));
      if (res == null) {
        await ProgressService.instance.syncFromCloud(preferServer: true).timeout(const Duration(seconds: 12));
      } else if (res.startsWith('email:')) {
        handoffEmail = res.substring(6);
      }
    } catch (_) {}
  }
  // ☁️ پێشکەفتن: ئەگەر ل مۆبایلەکا دی پێشکەفتنەکا مەزنتر هەبیت، وێ بینە؛ یان یا ڤێرێ بپارێزە
  if (!adminMode && Backend.instance.registered && !Backend.instance.isAdmin) {
    unawaited(ProgressService.instance.syncFromCloud().catchError((_) => false));
  }
  if (Uri.base.queryParameters['demo'] != null) await A1Summary.load();
  // ?theme=light|dark — بۆ تاقیکرنێ
  final qt = Uri.base.queryParameters['theme'];
  if (qt == 'light' || qt == 'dark') AppColors.dark = qt == 'dark';
  runApp(const ZimanProApp());
  ThemeController.instance.markStarted();
  // Safari ل iPhone: لینکێ ئامادە بکە دا «Add to Home Screen» هەژمارێ دگەل خۆ ببەت
  if (!adminMode && platformKind == 'ios' && !isStandalone && Backend.instance.registered && !Backend.instance.isAdmin) {
    unawaited(Backend.instance.handoffCode().then((c) {
      if (c != null) prepareHomeScreenHandoff(c);
    }).catchError((_) {}));
  }
}

class ZimanProApp extends StatelessWidget {
  const ZimanProApp({super.key});

  static ThemeData _theme() {
    final dark = AppColors.dark;
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.blue, brightness: dark ? Brightness.dark : Brightness.light);
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      // لاتینی/ئەلمانی/ئینگلیزی ب Roboto؛ هەر پیتەکا کوردی/عەرەبی ب Shasenem
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['Shasenem', 'Sarchia'],
      colorScheme: scheme.copyWith(surface: AppColors.bg, onSurface: AppColors.fg),
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.card,
      dividerColor: AppColors.fg12,
      appBarTheme: AppBarTheme(backgroundColor: AppColors.bg, foregroundColor: AppColors.fg, elevation: 0, scrolledUnderElevation: 0),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: AppColors.card),
      dialogTheme: DialogThemeData(backgroundColor: AppColors.card),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: AppColors.bg),
    );
  }

  static Widget? _demo() {
    final d = Uri.base.queryParameters['demo'];
    if (d == null) return null;
    return switch (d) {
      'mascot' => const MascotDemo(),
      'pick' => const CharacterPickerScreen(),
      'book' => const Scaffold(body: BookScreen()),
      'letters' => LetterLessonScreen(unit: appCurriculum.firstWhere((u) => u.isAlphabet)),
      'gpractice' => const _GramPracticeDemo(),
      'article' => const ArticleGameScreen(),
      'backup' => const VoiceBackupScreen(),
      'leader' => const LeaderboardScreen(),
      'conj' => const ConjugationGameScreen(),
      'goethe' => const GoetheMockScreen(),
      'games' => const Scaffold(body: GamesHubScreen()),
      'gram4' => const GrammarLektionScreen(n: 4),
      'grammar' => const GrammarLektionScreen(n: 6),
      'grammarlist' => const GrammarListScreen(),
      'home' => const HomeScreen(),
      'summary' => const SummaryListScreen(),
      'streak' => const StreakScreen(from: 3, to: 4),
      'toast' => const ToastDemo(),
      'combo' => () {
          ProgressService.instance.combo = 14;
          return InteractiveLessonScreen(
              unit: null, concepts: allConcepts.where((c) => c.cloze != null).take(4).toList(), onlyType: ExerciseType.cloze);
        }(),
      'combo10' => () {
          ProgressService.instance.combo = 19;
          return InteractiveLessonScreen(
              unit: null, concepts: allConcepts.where((c) => c.cloze != null).take(4).toList(), onlyType: ExerciseType.cloze);
        }(),
      'cloze' => InteractiveLessonScreen(
          unit: null, concepts: allConcepts.where((c) => c.cloze != null).take(4).toList(), onlyType: ExerciseType.cloze),
      'card' => const SummaryCardScreen(start: 9),
      'lesson' => InteractiveLessonScreen(unit: appCurriculum[10], concepts: appCurriculum[10].concepts),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
      title: 'ASP',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: (adminMode ? const AdminEntry() : null) ??
          _demo() ??
          (handoffEmail != null && !Backend.instance.registered
              ? LoginScreen(next: const HomeScreen(), prefillEmail: handoffEmail)
              : null) ??
          (!ProgressService.instance.onboarded
          ? const LanguageOnboardingScreen()
          : (Backend.instance.enabled && !Backend.instance.registered && !Backend.instance.isAdmin)
              ? const RegisterScreen(next: HomeScreen())
              : SetupScreen.needed()
                  ? const SetupScreen(next: HomeScreen())
                  : const HomeScreen())),
    );
  }
}


/// 🎯 بۆ وێنەگرتنا تاقیکرنێ
class _GramPracticeDemo extends StatefulWidget {
  const _GramPracticeDemo();
  @override
  State<_GramPracticeDemo> createState() => _GramPracticeDemoState();
}

class _GramPracticeDemoState extends State<_GramPracticeDemo> {
  @override
  void initState() {
    super.initState();
    Grammar.load().then((_) => mounted ? setState(() {}) : null);
  }

  @override
  Widget build(BuildContext context) {
    final t = Grammar.byLektion[6]?.first;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return GrammarPracticeScreen(topic: t, color: const Color(0xFF00CD9C), pool: Grammar.byLektion[6]!);
  }
}
