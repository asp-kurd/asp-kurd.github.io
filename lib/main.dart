import 'dart:async';
import 'package:flutter/material.dart';

import 'data/book.dart';
import 'data/cloze_bank.dart';
import 'data/curriculum.dart';
import 'data/tree.dart';
import 'services/rewards_service.dart';
import 'data/exams.dart';
import 'screens/account_screens.dart';
import 'screens/profile_screen.dart';
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
import 'screens/admin_tools.dart' show TreeEditor;
import 'screens/install_gate.dart';
import 'screens/chat_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/widgets/reward_fx.dart';
import 'data/pics.dart';
import 'data/path.dart';
import 'screens/path_view.dart' show PathFx;
import 'screens/onboarding_screen.dart';
import 'services/clone_service.dart';
import 'services/progress_service.dart';
import 'services/sfx.dart';
import 'data/glossary.dart';
import 'data/links.dart';
import 'services/theme_service.dart';
import 'services/voice_service.dart';
import 'screens/lesson_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/social_links.dart';
import 'screens/widgets/tap_words.dart';
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
  // 🔐 iPhone: Google/Facebook ل پەنجەرەکا جودا تەمام بوو ➔ تنێ «Done» (ئەپا سەر شاشێ تۆکنێ دخوینیت)
  if (oauthOverlay) {
    runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: OAuthDoneScreen()));
    return;
  }
  startAutoUpdate(const String.fromEnvironment('BUILD_ID'));
  await Backend.instance.init();
  // ⚡ هەمی پێکڤە (نە ل دویڤ ئێک) ➔ ئەپ زووتر ڤەدبیت
  await Future.wait<void>([
    Backend.instance.contentOverride('curriculum', fresh: false).then(loadCurriculum),
    loadClozeBank(),
    loadBook(),
    Exams.load(),
    RewardsService.instance.init(),
    VoiceService.instance.init(),
    CloneService.instance.load(),
    ThemeController.instance.load(),
    Glossary.load(),
    SocialLinks.load(),
  ]);
  Backend.instance.contentOverride('tree', fresh: false).then(loadTree); // 🌳 ناڤێن دارێ ژ ئەدمینی
  await ProgressService.instance.init();
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
      } else if (res.startsWith('oauth:')) {
        handoffEmail = ''; // 🔐 Google/Facebook ➔ ب هەمان دوگمێ بچە ژوور
      }
    } catch (_) {}
  }
  // ☁️ پێشکەفتن: ئەگەر ل مۆبایلەکا دی پێشکەفتنەکا مەزنتر هەبیت، وێ بینە؛ یان یا ڤێرێ بپارێزە
  if (!adminMode && Backend.instance.registered && !Backend.instance.isAdmin) {
    unawaited(ProgressService.instance.syncFromCloud(preferServer: Backend.instance.switchedAccount).catchError((_) => false));
  }
  if (Uri.base.queryParameters['demo'] != null) await A1Summary.load();
  // ?theme=light|dark — بۆ تاقیکرنێ
  // ?target=en — بۆ تاقیکرنا رێکا ئینگلیزی
  if (Uri.base.queryParameters['demo'] != null && Uri.base.queryParameters['target'] == 'en') {
    ProgressService.instance.targetLang = AppLanguage.english;
  }
  final qt = Uri.base.queryParameters['theme'];
  if (qt == 'light' || qt == 'dark' || qt == 'red' || qt == 'pink') AppColors.mode = qt!;
  runApp(const ZimanProApp());
  ThemeController.instance.markStarted();
  // 🔔 نامەکا نوو ➔ ئاوازا ASP
  Backend.onIncoming = Sfx.notify;
  listenPush(() => Backend.instance.loadMessages());
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
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: dark ? Brightness.dark : Brightness.light);
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
      'shop' => const ShopScreen(),
      'gate' => const InstallGateScreen(),
      'register' => const RegisterScreen(next: HomeScreen()),
      'login' => const LoginScreen(next: HomeScreen()),
      'guestlock' => const GuestLockScreen(),
      'profile' => const Scaffold(body: ProfileScreen()),
      'fire' => const _FxDemo(0),
      'fxfreeze' => const _FxDemo(1),
      'fxshatter' => const _FxDemo(2),
      'fxsmoke' => const _FxDemo(3),
      'reward' => () {
          RewardsService.instance.pending.add(RewardEvent(FxKind.reward, '⚡', '١٠ بەرسڤێن دروست ل دویف ئێک!', '10 richtig!', '10 in a row!',
              const [Reward.dinar(10)]));
          return const HomeScreen();
        }(),
      'pics' => InteractiveLessonScreen(unit: null, concepts: allConcepts.where(hasPic).skip(20).take(5).toList(), onlyType: ExerciseType.pickPicture),
      'match' => InteractiveLessonScreen(
          unit: null, concepts: appCurriculum.firstWhere((u) => u.id == 'unit_s3a').concepts, onlyType: ExerciseType.match),
      'cloze2' => () {
          final u = appCurriculum.firstWhere((u) => u.id == 'unit_s5a');
          return InteractiveLessonScreen(unit: u, concepts: u.concepts, onlyType: ExerciseType.cloze);
        }(),
      'admintree' => const Scaffold(body: TreeEditor()),
      'chat' => const ChatScreen(),
      'settings' => const SettingsScreen(),
      'examhint' || 'examtype' => () {
          // 🧪 پرسیارا وێنەیی (رستە) ب چاڤێ هاریکاریێ / نڤیسین «tschüss»
          final all = Exams.lektion.values.expand((x) => x).toList();
          final q = d == 'examhint'
              ? all.firstWhere((x) => x.type == QType.imgchoice && x.q == '☎️', orElse: () => all.first)
              : all.firstWhere((x) => x.type == QType.type && '${x.answer}'.startsWith('Auf Wiedersehen'), orElse: () => all.first);
          return QuizScreen(examId: 'demo', title: '🏁 ئەزموون', questions: [q]);
        }(),
      'pathgold' => () {
          // 🏅 قۆناغا ئێکێ زێڕ + وانەیەک نوکە تەمام بوو (هێل درێژ دبیت) + ⚡×٢
          final p = ProgressService.instance;
          final st = pathStages.where((x) => x.section == 1).toList();
          for (final l in st[0].lessons) {
            p.pathProg[l.id] = [l.courses, 1];
          }
          for (final l in st[1].lessons.take(2)) {
            p.pathProg[l.id] = [l.courses, 0];
          }
          PathFx.justDone = st[1].lessons[1].id;
          RewardsService.instance.demoBoost();
          return const HomeScreen();
        }(),
      'links' => const SocialLinksEditor(),
      'gloss' => const _GlossDemo(),
      'pathdone' => () {
          // بەشێ ١ تەمام ➔ تنێ بەشێ ٢ ل رێکێ + «بەشێ ١ د پرۆفایلێ دایە»
          final p = ProgressService.instance;
          for (final st in pathStages.where((x) => x.section == 1)) {
            for (final l in st.lessons) {
              p.pathProg[l.id] = [l.courses, 0];
            }
          }
          return const HomeScreen();
        }(),
      'path' || 'pathboost' || 'pathcele' => () {
          final p = ProgressService.instance;
          final ls = pathLessons;
          for (var i = 0; i < 11 && i < ls.length; i++) {
            p.pathProg[ls[i].id] = [ls[i].courses, (i == 2 || i == 4 || i == 7 || i == 8) ? 1 : 0];
          }
          if (ls.length > 11) p.pathProg[ls[11].id] = [2, 0];
          if (d == 'pathboost') RewardsService.instance.demoBoost();
          if (d == 'pathcele') PathFx.pendingGold = ls[7].id;
          return const HomeScreen();
        }(),
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
          // 📲 بەری هەر تشتەکی: ئەپ ل سەر شاشێ (Home Screen)
          (installGateNeeded ? const InstallGateScreen() : null) ??
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


/// 🎬 تاقیکرنا ئەنیمەیشنان (?demo=fire|fxfreeze|fxshatter|fxsmoke)
class _FxDemo extends StatelessWidget {
  final int kind;
  const _FxDemo(this.kind);
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B1116),
        body: Center(
          child: switch (kind) {
            1 => const FreezeAnim(size: 300),
            2 => const ShatterAnim(size: 300),
            3 => const SmokeAnim(size: 300),
            _ => const RealFire(size: 300),
          },
        ),
      );
}


/// 🧪 ?demo=gloss — بالۆنا رامانا پەیڤێ ل سەر وانەکێ
class _GlossDemo extends StatefulWidget {
  const _GlossDemo();
  @override
  State<_GlossDemo> createState() => _GlossDemoState();
}

class _GlossDemoState extends State<_GlossDemo> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 8), () {
      final g = Glossary.lookup('Tisch', AppLanguage.german);
      if (mounted && g != null) TapWords.showGloss(context, 'Tisch', g, const Offset(214, 300));
    });
  }

  @override
  Widget build(BuildContext context) => InteractiveLessonScreen(
      unit: null, concepts: allConcepts.where((c) => c.cloze != null).take(4).toList(), onlyType: ExerciseType.cloze);
}
