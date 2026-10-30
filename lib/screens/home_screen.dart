import 'package:flutter/material.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../ui.dart';
import 'book_screen.dart';
import 'course_screens.dart';
import 'games/game_session.dart';
import 'games/games_hub.dart';
import 'lesson_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';
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
      listenable: progress,
      builder: (context, _) {
        final n = progress.nativeLang;
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
          GestureDetector(
            onTap: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LanguageOnboardingScreen())),
            child: Text('${progress.nativeLang.flag} ➔ ${progress.targetLang.flag}', style: const TextStyle(fontSize: 20)),
          ),
          stat(Icons.local_fire_department, '${progress.streak}', AppColors.orange),
          stat(Icons.bolt, '${progress.xp}', AppColors.gold),
          stat(Icons.favorite, '${progress.hearts}', AppColors.red),
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
        _examCards(context, p),
        const SizedBox(height: 12),
        for (var i = 0; i < appCurriculum.length; i++) ...[
          if (i == 0 || appCurriculum[i].section != appCurriculum[i - 1].section) _sectionHeader(appCurriculum[i].section, n),
          _unitBlock(context, i),
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
                Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
    if (lek != null) return _lektionHeader(lek, title, n);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(children: [
        const Expanded(child: Divider(color: Colors.white24)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        ),
        const Expanded(child: Divider(color: Colors.white24)),
      ]),
    );
  }

  /// سەرێ وانەیەکا پەرتووکێ: ناڤ + 💬 دیالۆگ + 📝 ئەزموون
  Widget _lektionHeader(LektionInfo lek, String title, AppLanguage n) {
    return Builder(builder: (context) {
      final best = ProgressService.instance.examBest('lek_${lek.n}');
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
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DialogScreen(lektion: lek))),
                icon: const Text('💬'),
                label: Text(tr(n, 'دیالۆگ', 'Dialog', 'Dialogue')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white, side: BorderSide(color: best != null && best >= 60 ? AppColors.green : Colors.white30)),
                onPressed: () => openLektionTest(context, lek),
                icon: Text(best != null && best >= 60 ? '✅' : '📝'),
                label: Text(best == null ? tr(n, 'ئەزموون', 'Test', 'Test') : '$best%'),
              ),
            ),
          ]),
        ]),
      );
    });
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
              : const [Color(0xFF202F36), Color(0xFF1A3A4A)],
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
              backgroundColor: Colors.white12,
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
            Text('${p.todayXp} / ${p.dailyGoal} XP', style: const TextStyle(color: Colors.white70)),
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
                if (unit.grammar != null && unlocked)
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
              Text(unit.title(p.targetLang), style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Transform.translate(
          offset: Offset(dx, 0),
          child: GestureDetector(
            onTap: unlocked
                ? () {
                    if (unit.grammar != null && !p.grammarSeen(unit.id)) {
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
          content: Text(tr(p.nativeLang, 'سوبەهی دێ دبنە ٥. یان ل «دەنگێ من» پەیڤان تۆمار بکە دا دلان وەرگری.',
              'Morgen wieder 5. Oder nimm im Studio Wörter auf, um Herzen zu bekommen.',
              'They refill tomorrow. Or record words in My Voice to earn hearts.')),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InteractiveLessonScreen(unit: unit, concepts: concepts)),
    );
  }
}
