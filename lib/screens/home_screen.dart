import 'package:flutter/material.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../ui.dart';
import '../services/backend.dart';
import '../services/rewards_service.dart';
import 'account_screens.dart';
import 'book_screen.dart';
import 'character_screen.dart';
import 'course_screens.dart';
import 'grammar_screen.dart';
import 'streak_screen.dart';
import 'widgets/combo.dart' show kuNum;
import 'games/game_session.dart';
import 'games/games_hub.dart';
import 'lesson_screen.dart';
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
          if (Backend.instance.registered)
            ListenableBuilder(
              listenable: Backend.instance,
              builder: (_, __) => IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen())),
                icon: Badge(
                  isLabelVisible: Backend.instance.unread > 0,
                  label: Text('${Backend.instance.unread}'),
                  child: const Icon(Icons.mail_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// رێکا وانەیان (Skill path)
class _LearnPath extends StatelessWidget {
  const _LearnPath();

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final n = p.nativeLang;
    final weak = p.weakConcepts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        if (Backend.instance.registered)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('${tr(n, 'سلاڤ', 'Hallo', 'Hi')} ${Backend.instance.name} 👋',
                style: const TextStyle(fontFamily: 'Sarchia', fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        // 🔒 هەژمارێن ب ناڤ تنێ: بیرئینان بۆ زێدەکرنا ئیمەیلێ (هەر رۆژ ئێک جار، دشێی بگری)
        if (Backend.instance.registered &&
            !Backend.instance.hasEmail &&
            !Backend.instance.flag('nag_${DateTime.now().toIso8601String().substring(0, 10)}'))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AccountCard(
              compact: true,
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
        const QuestsCard(),
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
        for (var i = 0; i < appCurriculum.length; i++) ...[
          if (i == 0 || appCurriculum[i].section != appCurriculum[i - 1].section) _sectionHeader(appCurriculum[i].section, n),
          _unitBlock(context, i),
          // 📝 ئەزموونا وانێ: پشتی دویماهیک قۆناغا وێ (هەر کەسێ بڤێت)
          if ((i == appCurriculum.length - 1 || appCurriculum[i + 1].section != appCurriculum[i].section) &&
              lektionForSection(appCurriculum[i].section) != null &&
              p.targetLang == AppLanguage.german)
            _lektionTestCard(context, lektionForSection(appCurriculum[i].section)!, i, n),
        ],
        if (p.completedUnits.length >= appCurriculum.length)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
            child: Text(
              tr(n, '👑 تە هەمی قۆناغ تەمام کرن! ب «ڕاهێنانا ئازاد» بەردەوام بە دا ژ بیر نەکەی.',
                  '👑 Alle Einheiten geschafft! Übe weiter mit „Freies Training“.',
                  '👑 All units done! Keep practising with Free practice.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
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

  Widget _sectionHeader(int section, AppLanguage n) {
    final title = section - 1 < appSections.length ? appSections[section - 1].title(n) : '';
    final lek = lektionForSection(section);
    // Lektion (دیالۆگ + رێزمان) ژ پەرتووکا ئەلمانی نە — بۆ ئینگلیزی سەرناڤەکێ ئاسایی
    if (lek != null && ProgressService.instance.targetLang == AppLanguage.german) return _lektionHeader(lek, title, n);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(children: [
        Expanded(child: Divider(color: AppColors.fg24)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(title, style: TextStyle(color: AppColors.fg70, fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Divider(color: AppColors.fg24)),
      ]),
    );
  }

  /// سەرێ وانەیەکا پەرتووکێ: ناڤ + 💬 دیالۆگ + 📝 ئەزموون
  Widget _lektionHeader(LektionInfo lek, String title, AppLanguage n) {
    return Builder(builder: (context) {
      return Container(
        margin: const EdgeInsets.only(top: 12, bottom: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: lek.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: lek.color.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: TextStyle(fontFamily: 'Sarchia', fontSize: 19, color: lek.color, fontWeight: FontWeight.bold)),
          Text(lek.titleDe, textDirection: TextDirection.ltr, textAlign: TextAlign.end,
              style: TextStyle(color: AppColors.fg60, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.fg, side: BorderSide(color: AppColors.fg30)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DialogScreen(lektion: lek))),
                icon: const Text('💬'),
                label: Text(tr(n, 'دیالۆگ', 'Dialog', 'Dialogue')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.fg, side: BorderSide(color: AppColors.fg30)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GrammarLektionScreen(n: lek.n))),
                icon: const Text('📘'),
                label: Text(tr(n, 'رێزمان', 'Grammatik', 'Grammar')),
              ),
            ),
          ]),
        ]),
      );
    });
  }

  /// 🏁 ئەزموونا وانێ — پشتی قۆناغێن وێ (نە بەری)
  Widget _lektionTestCard(BuildContext context, LektionInfo lek, int lastIndex, AppLanguage n) {
    final p = ProgressService.instance;
    final best = p.examBest('lek_${lek.n}');
    final units = appCurriculum.where((u) => u.section == appCurriculum[lastIndex].section);
    final ready = units.every((u) => p.completedUnits.contains(u.id));
    final passed = best != null && best >= 60;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 22),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (!ready) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(tr(n, 'پێشی قۆناغێن ڤێ وانێ تەمام بکە، پاشان ئەزموون ڤەدبیت 🔒',
                    'Schließe zuerst die Einheiten ab 🔒', 'Finish this lesson’s units first 🔒'))));
            return;
          }
          openLektionTest(context, lek);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: ready
                ? LinearGradient(colors: passed ? const [Color(0xFF58CC02), Color(0xFF2E9E00)] : [lek.color, lek.color.withValues(alpha: 0.7)])
                : null,
            color: ready ? null : AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ready ? Colors.transparent : AppColors.fg12, width: 1.5),
          ),
          child: Row(children: [
            Text(passed ? '🏆' : (ready ? '📝' : '🔒'), style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(n, 'ئەزموونا وانا ${kuNum(lek.n)}', 'Test Lektion ${lek.n}', 'Lesson ${lek.n} test'),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ready ? Colors.white : AppColors.fg)),
                Text(
                  best != null
                      ? '${tr(n, 'باشترین ئەنجام', 'Bestes Ergebnis', 'Best')}: $best%'
                      : (ready
                          ? tr(n, 'ئەگەر تە بڤێت خۆ تاقی بکە ✨', 'Teste dich, wenn du willst ✨', 'Test yourself if you like ✨')
                          : tr(n, 'پشتی تەمامکرنا قۆناغێن سەری ڤەدبیت', 'Nach den Einheiten oben', 'Unlocks after the units above')),
                  style: TextStyle(fontSize: 13, color: ready ? Colors.white70 : AppColors.fg60),
                ),
              ]),
            ),
            if (ready) const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
          ]),
        ),
      ),
    );
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
            for (var i = 0; i < appCurriculum.length; i++)
              if (p.isUnlocked(i)) ...appCurriculum[i].concepts,
          ]..shuffle();
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

  Widget _unitBlock(BuildContext context, int i) {
    final p = ProgressService.instance;
    final unit = appCurriculum[i];
    final unlocked = p.isUnlocked(i);
    final done = p.completedUnits.contains(unit.id);
    final color = unlocked ? unit.color : Colors.grey.shade700;
    // شێوازێ زیگزاگ وەکی Duolingo
    const offsets = [0.0, 60.0, 0.0, -60.0];
    final dx = offsets[i % offsets.length];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(unit.title(p.nativeLang),
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                if (unit.isAlphabet && unlocked)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => LetterCardsScreen.open(context, unit),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                      child: Text('🔤 ${tr(p.nativeLang, 'پیت', 'Buchstaben', 'Letters')}',
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  )
                else if (unit.grammar != null && unlocked)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showGrammarCard(context, unit),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                      child: Text('📘 ${tr(p.nativeLang, 'رێزمان', 'Grammatik', 'Grammar')}',
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(unit.title(p.targetLang), style: TextStyle(color: AppColors.fg70)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Transform.translate(
          offset: Offset(dx, 0),
          child: GestureDetector(
            onTap: unlocked
                ? () {
                    if (unit.isAlphabet && !p.grammarSeen('${unit.id}_letters')) {
                      LetterCardsScreen.open(context, unit, onStart: () => _open(context, unit, unit.concepts));
                    } else if (unit.grammar != null && !p.grammarSeen(unit.id)) {
                      showGrammarCard(context, unit, onStart: () => _open(context, unit, unit.concepts));
                    } else {
                      _open(context, unit, unit.concepts);
                    }
                  }
                : () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr(p.nativeLang, 'پێنگاڤا بەری ڤێ تەمام بکە 🔒', 'Schließe zuerst die vorherige Einheit ab 🔒',
                        'Finish the previous unit first 🔒')))),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Icon(
                done ? Icons.check_rounded : (unlocked ? unit.icon : Icons.lock_rounded),
                size: 42,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
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
