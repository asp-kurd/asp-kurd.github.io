import 'package:flutter/material.dart';

import '../models.dart';
import '../services/progress_service.dart';
import '../ui.dart';
import '../services/backend.dart';
import '../services/rewards_service.dart';
import 'account_screens.dart';
import 'book_screen.dart';
import 'character_screen.dart';
import 'course_screens.dart';
import 'streak_screen.dart';
import 'games/game_session.dart';
import 'games/games_hub.dart';
import 'lesson_screen.dart';
import 'path_view.dart';
import 'dart:math' show min;
import '../data/path.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'teacher_tasks.dart';
import 'widgets/reward_fx.dart';
import 'voice_studio_screen.dart';

/// شاشەیا سەرەکی: فێربوون + ستۆدیۆیا دەنگی + پرۆفایل
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  final progress = ProgressService.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([progress, Backend.instance, RewardsService.instance]),
      builder: (context, _) {
        final n = progress.nativeLang;
        // 🔒 هەژمارا ب ناڤ تنێ پشتی ٣ رۆژان: دڤێت بهێتە پاراستن (پێشکەفتن ناچیت)
        if (Backend.instance.isGuest && Backend.instance.guestDaysLeft <= 0) return const GuestLockScreen();
        // 🔥 ستریک زێدە بوو (بۆ نموونە ژ یاریێ) ➔ شاشا ئاهەنگێ
        // 🦸 بکارهێنەرێن کەڤن: جارەکێ کاراکتەرێ خۆ هەلبژێرن
        if (Backend.instance.registered && !Backend.instance.isAdmin && progress.mascotId == null && !Backend.instance.flag('asked_mascot')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false) || Backend.instance.flag('asked_mascot')) return;
            Backend.instance.setFlag('asked_mascot');
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CharacterPickerScreen()));
          });
        }
        // 🪙 دیاریێن ئەدمینی + خەلاتێن چاڤەڕێ (دیالۆگ و فڕینا دیناران)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
          applyAdminGifts();
          RewardsService.instance.ensureQuests(); // 🎯 رۆژا نوو ➔ ٣ ئەرکێن نوو
          if (RewardsService.instance.pending.isNotEmpty && progress.streakEvent == null) showPendingRewards(context);
        });
        if (progress.streakEvent != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) maybeShowStreak(context);
          });
        }
        return Directionality(
          textDirection: n.direction,
          child: Scaffold(
            appBar: tab == 0 ? _statsBar(context) : null,
            body: IndexedStack(
              index: tab,
              // نە const: دا دەمێ XP/دل دگوهۆڕن ژ نوو بهێنە ئاڤاکرن
              // ignore: prefer_const_constructors
              children: [
                // ignore: prefer_const_constructors
                _LearnPath(),
                // ignore: prefer_const_constructors
                BookScreen(),
                // ignore: prefer_const_constructors
                GamesHubScreen(),
                VoiceStudioScreen(key: ValueKey('studio_$n')),
                // ignore: prefer_const_constructors
                ProfileScreen(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              backgroundColor: AppColors.card,
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: [
                NavigationDestination(icon: const Icon(Icons.home_rounded), label: tr(n, 'فێربوون', 'Lernen', 'Learn')),
                NavigationDestination(icon: const Icon(Icons.menu_book_rounded), label: tr(n, 'رێزمان', 'Grammatik', 'Grammar')),
                NavigationDestination(icon: const Icon(Icons.sports_esports_rounded), label: tr(n, 'یاری', 'Spiele', 'Games')),
                NavigationDestination(icon: const Icon(Icons.mic_rounded), label: tr(n, 'دەنگێ من', 'Meine Stimme', 'My Voice')),
                NavigationDestination(icon: const Icon(Icons.person_rounded), label: tr(n, 'پرۆفایل', 'Profil', 'Profile')),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _statsBar(BuildContext context) {
    Widget stat(IconData i, String v, Color c) => Row(children: [
          Icon(i, color: c),
          const SizedBox(width: 4),
          Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: c)),
        ]);
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 🪙 دینار (گوهۆڕینا زمانی نوکە تنێ ل پرۆفایلێ یە)
          DinarChip(target: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()))),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen())),
            child: StreakFlame(streak: progress.streak),
          ),
          stat(Icons.bolt, '${progress.xp}', AppColors.gold),
          Column(mainAxisSize: MainAxisSize.min, children: [
            stat(Icons.favorite, '${progress.hearts}', AppColors.red),
            if (progress.nextHeartIn != null)
              Text(_mmss(progress.nextHeartIn!), style: const TextStyle(fontSize: 10, color: AppColors.red)),
          ]),
        ],
      ),
    );
  }
}

/// رێکا وانەیان (Skill path) — asp 2.22: بەش ➔ قۆناغ ➔ وانە (شێوە) ➔ کۆرس
class _LearnPath extends StatefulWidget {
  const _LearnPath();

  @override
  State<_LearnPath> createState() => _LearnPathState();
}

class _LearnPathState extends State<_LearnPath> {
  final _scroll = ScrollController();
  final _curKey = GlobalKey();
  bool _scrolled = false;
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _toCurrent());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final ctx = _curKey.currentContext;
    var off = true;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.attached) {
        final y = box.localToGlobal(Offset.zero).dy;
        final h = MediaQuery.of(context).size.height;
        off = y < 60 || y > h - 120;
      }
    }
    if (off != _showJump) setState(() => _showJump = off);
  }

  /// 🎯 بچە سەر وانەیا نوکە (ListView تنێ یێن نێزیک ئاڤا دکەت ➔ گاڤ ب گاڤ)
  bool _seeking = false;

  /// تنێ ئێک گەڕیان د ئێک دەم دا (نە ئەو ژ ڤێ ڕێکێ دەرباز ببیت)
  void _toCurrent({bool animate = false}) {
    if (_seeking || !mounted || !_scroll.hasClients) return;
    _seeking = true;
    final ctx0 = _curKey.currentContext;
    // دووری ژ سەری ڤە: ئەگەر وانەیا نوکە یا ل خوارێ بیت، ژ سەری دەستپێبکە
    if (ctx0 == null && _scroll.position.pixels > 0) _scroll.jumpTo(0);
    void step(int tries) {
      if (!mounted || !_scroll.hasClients) {
        _seeking = false;
        return;
      }
      final ctx = _curKey.currentContext;
      if (ctx != null) {
        _seeking = false;
        _scrolled = true;
        Scrollable.ensureVisible(ctx, alignment: 0.45, duration: Duration(milliseconds: animate ? 450 : 1));
        return;
      }
      final pos = _scroll.position;
      final next = min(pos.pixels + pos.viewportDimension * 0.8, pos.maxScrollExtent);
      if (tries > 120 || next <= pos.pixels) {
        _seeking = false;
        _scrolled = true;
        return;
      }
      _scroll.jumpTo(next);
      WidgetsBinding.instance.addPostFrameCallback((_) => step(tries + 1));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => step(0));
  }

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final n = p.nativeLang;
    final weak = p.weakConcepts;
    // 🏅 ئاهەنگا زێڕ / قۆناغ تەمام (پشتی زڤڕینێ ژ وانێ)
    if (PathFx.pendingGold != null || PathFx.pendingStage != null || PathFx.goldFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) maybeCelebratePath(context);
      });
    }
    if (!_scrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toCurrent());
    }

    return Stack(children: [
      ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
      children: [
        if (Backend.instance.registered)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('${tr(n, 'سلاڤ', 'Hallo', 'Hi')} ${Backend.instance.name} 👋',
                style: const TextStyle(fontFamily: 'Sarchia', fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        // 🔒 هەژمارێن ب ناڤ تنێ: ٣ رۆژ — پاشان دڤێت Google / Facebook / ئیمەیل گرێبدەت
        if (Backend.instance.isGuest &&
            !Backend.instance.flag('nag_${DateTime.now().toIso8601String().substring(0, 10)}'))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GuestBanner(
              onClose: () => Backend.instance.setFlagNotify('nag_${DateTime.now().toIso8601String().substring(0, 10)}'),
            ),
          ),
        if (p.streakAtRisk)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF4B4B), Color(0xFFFF9600)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              const Text('⏳', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr(n, 'دەمەکێ کێم ماوە! وانەیەکا کورت بکە دا Streak ـا تە (${p.streak} 🔥) نەچیت.',
                      'Nicht mehr viel Zeit! Mach eine kurze Lektion für deine Serie (${p.streak} 🔥).',
                      'Not much time left! Do a short lesson to keep your ${p.streak} 🔥 streak.'),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ]),
          ),
        if (Backend.instance.unread > 0)
          Card(
            color: AppColors.tint,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.gold)),
            child: ListTile(
              leading: const Text('📬', style: TextStyle(fontSize: 26)),
              title: Text(Backend.instance.messages.firstWhere((m) => !m.read).title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(tr(n, 'نامەیەکا نوو ژ ASP', 'Neue Nachricht', 'New message')),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen())),
            ),
          ),
        const TeacherTaskCards(),
        _dailyGoalCard(p),
        const SizedBox(height: 12),
        if (p.dueConcepts.isNotEmpty)
          Card(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.green.withValues(alpha: 0.6)),
            ),
            child: ListTile(
              leading: const Icon(Icons.autorenew_rounded, color: AppColors.green),
              title: Text(tr(n, 'دووبارەکرنا ب دەم', 'Wiederholung', 'Spaced repetition'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(tr(n, '${p.dueConcepts.length} پەیڤ ئەڤرۆ دڤێت بهێنە دووبارەکرن',
                  '${p.dueConcepts.length} Wörter sind heute fällig', '${p.dueConcepts.length} words are due today')),
              trailing: const Icon(Icons.play_arrow_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GameSessionScreen(kind: null, concepts: p.dueConcepts.take(10).toList())),
              ),
            ),
          ),
        if (weak.isNotEmpty)
          Card(
            color: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.fitness_center_rounded, color: AppColors.orange),
              title: Text(tr(n, 'دووبارەکرنا خەلەتیان', 'Fehler wiederholen', 'Review mistakes'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(tr(n, '${weak.length} پەیڤ', '${weak.length} Wörter', '${weak.length} words')),
              trailing: const Icon(Icons.play_arrow_rounded),
              onTap: () => _open(context, null, weak),
            ),
          ),
        _practiceCard(context, p),
        const SizedBox(height: 8),
        // 🇩🇪 تاقیکرنا ئاستی و ئەزموونا A1 یێن ئەلمانینە
        if (p.targetLang == AppLanguage.german) ...[_examCards(context, p), const SizedBox(height: 12)],
        ...buildPathItems(context, currentKey: _curKey),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Center(child: Text('asp 2.22', style: TextStyle(color: AppColors.fg30, fontSize: 12))),
        ),
      ],
    ),
      if (_showJump && p.currentLesson != null)
        Positioned(
          bottom: 16,
          left: n.direction == TextDirection.rtl ? 16 : null,
          right: n.direction == TextDirection.rtl ? null : 16,
          child: FloatingActionButton.small(
            heroTag: 'toCurrent',
            backgroundColor: p.currentLesson!.stage.color,
            foregroundColor: Colors.white,
            onPressed: () => _toCurrent(animate: true),
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
    ]);
  }

  /// 🎯 تاقیکرنا ئاستی + 🏆 ئەزموونا A1
  Widget _examCards(BuildContext context, ProgressService p) {
    final n = p.nativeLang;
    final best = p.examBest('final');
    Widget card(String emoji, String title, String sub, List<Color> colors, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                Text(sub, style: TextStyle(fontSize: 12, color: AppColors.fg70)),
              ]),
            ),
          ),
        );
    return Row(children: [
      card('🎯', tr(n, 'تاقیکرنا ئاستی', 'Einstufungstest', 'Placement test'),
          p.placementDone ? tr(n, 'جارەکا دی تاقی بکە', 'Nochmal', 'Try again') : tr(n, 'تو چەند دزانی؟', 'Was kannst du?', 'What do you know?'),
          const [Color(0xFF1CB0F6), Color(0xFF2B70C9)], () => openPlacement(context)),
      const SizedBox(width: 10),
      card('🏆', tr(n, 'ئەزموونا A1', 'Prüfung A1', 'A1 exam'),
          best == null ? tr(n, 'وەکی Goethe', 'wie Goethe', 'Goethe style') : '${tr(n, 'باشترین', 'Beste', 'Best')}: $best%',
          const [Color(0xFFFFC800), Color(0xFFFF9600)], () => openFinalExam(context)),
    ]);
  }

  /// 🔁 ڕاهێنانا ئازاد — ٨ پەیڤێن هەڕەمەکی ژ قۆناغێن تە دیتین (هەرگیز ب دویماهی نائێت)
  Widget _practiceCard(BuildContext context, ProgressService p) {
    final n = p.nativeLang;
    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.all_inclusive_rounded, color: AppColors.blue),
        title: Text(tr(n, 'ڕاهێنانا ئازاد', 'Freies Training', 'Free practice'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(tr(n, '٨ پەیڤێن هەڕەمەکی ژ وانەیێن تە', '8 zufällige Wörter', '8 random words from your lessons')),
        trailing: const Icon(Icons.play_arrow_rounded),
        onTap: () {
          final pool = [
            for (final l in pathLessons)
              if (p.lessonDone(l) || p.coursesDone(l) > 0) ...l.concepts,
          ]..shuffle();
          if (pool.length < 4) pool.addAll(pathLessons.take(3).expand((l) => l.concepts));
          _open(context, null, pool.take(8).toList());
        },
      ),
    );
  }

  /// ☀️ ئارمانجا رۆژانە — شێوازێ تایبەت یێ ZimanPro: رۆژا کوردی کو ب XP رۆهن دبیت
  Widget _dailyGoalCard(ProgressService p) {
    final n = p.nativeLang;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: p.dailyGoalMet
              ? const [Color(0xFFFFC800), Color(0xFFFF9600)]
              : (AppColors.dark ? const [Color(0xFF202F36), Color(0xFF1A3A4A)] : const [Color(0xFF1CB0F6), Color(0xFF2B70C9)]),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: p.dailyProgress,
              strokeWidth: 7,
              backgroundColor: AppColors.fg12,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
            Text(p.dailyGoalMet ? '☀️' : '🌤️', style: const TextStyle(fontSize: 26)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              p.dailyGoalMet
                  ? tr(n, 'رۆژا تە رۆهن بوو! ☀️', 'Tagesziel erreicht! ☀️', 'Daily goal reached! ☀️')
                  : tr(n, 'ئارمانجا ئەڤرۆ', 'Tagesziel', "Today's goal"),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text('${p.todayXp} / ${p.dailyGoal} XP', style: TextStyle(color: AppColors.fg70)),
          ]),
        ),
      ]),
    );
  }

  void _open(BuildContext context, LessonUnit? unit, List<WordConcept> concepts) {
    final p = ProgressService.instance;
    if (p.hearts <= 0) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr(p.nativeLang, 'دلێن تە نەمان 💔', 'Keine Herzen mehr 💔', 'Out of hearts 💔')),
          content: Text(tr(p.nativeLang, 'هەر خولەکەکێ دلەک ب خۆ دزڤڕیت ❤️ دلێ بهێت پشتی: ${_mmss(p.nextHeartIn ?? Duration.zero)}',
              'Jede Minute kommt ein Herz zurück ❤️ Nächstes in ${_mmss(p.nextHeartIn ?? Duration.zero)}',
              'A heart comes back every minute ❤️ Next in ${_mmss(p.nextHeartIn ?? Duration.zero)}')),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => unit != null && unit.isAlphabet && concepts.where((c) => c.letter != null).length >= 2
              ? LetterLessonScreen(unit: unit)
              : InteractiveLessonScreen(unit: unit, concepts: concepts)),
    );
  }
}

String _mmss(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
