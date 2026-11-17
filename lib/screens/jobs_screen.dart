import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../services/progress_service.dart';
import '../services/sfx.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'lesson_screen.dart';

/// 💼 پەیڤێن کاری (A1): هەر کارەک ٤ قۆناغ + تاقیکرن ➔ نیشانا 🏅
///   ١ 📚 پەیڤێن سەرەکی (١٥) · ٢ ⚡ کار و ڕەنگدان (١٠) · ٣ 💬 رستە (١٢) · ٤ 🗣️ دیالۆگ · 🏆 تاقیکرن (١٥ پرسیار، ٨٠٪)
class DialogLine {
  final String who;
  final WordConcept c;
  const DialogLine(this.who, this.c);
}

class JobInfo {
  final String id, emoji, ku, de, en;
  final List<WordConcept> words, phrases;
  final List<DialogLine> dialog;
  const JobInfo(this.id, this.emoji, this.ku, this.de, this.en, this.words, this.phrases, this.dialog);

  List<WordConcept> get basics => words.take(15).toList();
  List<WordConcept> get actions => words.skip(15).toList();
  List<WordConcept> get all => [...words, ...phrases];

  String title(AppLanguage n) => switch (n) {
        AppLanguage.badini => ku,
        AppLanguage.german => de,
        AppLanguage.english => en,
      };
}

List<JobInfo>? _jobs;

Future<List<JobInfo>> loadJobs() async {
  if (_jobs != null) return _jobs!;
  final d = jsonDecode(await rootBundle.loadString('assets/jobs.json')) as Map<String, dynamic>;
  WordConcept wc(Map it) => WordConcept(
        '${it['id']}',
        emoji: '${it['emoji'] ?? ''}',
        ku: '${it['ku']}',
        kuLat: '${it['kuLat'] ?? ''}',
        de: '${it['de']}',
        deHint: '${it['deHint'] ?? ''}',
        en: '${it['en'] ?? ''}'.isEmpty ? '${it['de']}' : '${it['en']}',
        enHint: '',
      );
  return _jobs = [
    for (final j in d['jobs'] as List)
      JobInfo(
        '${j['id']}',
        '${j['emoji']}',
        '${j['ku']}',
        '${j['de']}',
        '${j['en']}',
        [for (final it in j['items'] as List) if (it['phrase'] != true && it['dialog'] != true) wc(it as Map)],
        [for (final it in j['items'] as List) if (it['phrase'] == true) wc(it as Map)],
        [for (final it in j['items'] as List) if (it['dialog'] == true) DialogLine('${it['who']}', wc(it as Map))],
      ),
  ];
}

// ───────── پێشکەفتن (ل سەر مۆبایلێ) ─────────
const _stageCount = 4;

Future<SharedPreferences> get _p => SharedPreferences.getInstance();
Future<int> jobStageBest(String id, int stage) async => (await _p).getInt('job_best_${id}_$stage') ?? 0;
Future<int> jobTestBest(String id) async => (await _p).getInt('job_test_$id') ?? 0;
Future<bool> jobBadge(String id) async => (await jobTestBest(id)) >= 80;

Future<void> _saveStage(String id, int stage, int pc) async {
  final p = await _p;
  if (pc > (p.getInt('job_best_${id}_$stage') ?? 0)) await p.setInt('job_best_${id}_$stage', pc);
}

/// 🏅 هەمی نیشانێن کاری یێن فێرخوازی (بۆ پرۆفایلێ)
Future<List<JobInfo>> earnedJobBadges() async {
  final all = await loadJobs();
  return [
    for (final j in all)
      if (await jobBadge(j.id)) j,
  ];
}

const _jobColors = [
  [Color(0xFF58CC02), Color(0xFF3A9A00)],
  [Color(0xFF1CB0F6), Color(0xFF1480C0)],
  [Color(0xFFFF9600), Color(0xFFE07000)],
  [Color(0xFFCE82FF), Color(0xFF9A4FE0)],
  [Color(0xFFFF4B4B), Color(0xFFD63030)],
  [Color(0xFF00C2A8), Color(0xFF00917E)],
  [Color(0xFFFFC800), Color(0xFFE0A800)],
];

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<JobInfo>? jobs;
  Map<String, int> stagesDone = {};
  Map<String, bool> badges = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final j = await loadJobs();
    final sd = <String, int>{}, bd = <String, bool>{};
    for (final x in j) {
      var n = 0;
      for (var s = 0; s < _stageCount; s++) {
        if (await jobStageBest(x.id, s) > 0) n++;
      }
      sd[x.id] = n;
      bd[x.id] = await jobBadge(x.id);
    }
    if (!mounted) return;
    setState(() {
      jobs = j;
      stagesDone = sd;
      badges = bd;
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = ProgressService.instance.nativeLang;
    return Directionality(
      textDirection: n.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(n, '💼 پەیڤێن کاری', '💼 Deutsch für den Beruf', '💼 Words for work'))),
        body: jobs == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
                Text(
                  tr(n, 'کارێ خۆ هەلبژێرە: هەر کارەک ٤ قۆناغ و تاقیکرنەک هەیە. ب ٨٠٪ ل تاقیکرنێ، نیشانا وی کاری 🏅 وەردگری.',
                      'Wähle deinen Beruf: 4 Stufen und ein Test. Mit 80 % im Test bekommst du das Abzeichen 🏅.',
                      'Pick your job: 4 stages and a test. Score 80% in the test to earn its badge 🏅.'),
                  style: TextStyle(color: AppColors.fg60, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: [
                    for (var i = 0; i < jobs!.length; i++) _tile(jobs![i], _jobColors[i % _jobColors.length], n),
                  ],
                ),
              ]),
      ),
    );
  }

  Widget _tile(JobInfo j, List<Color> c, AppLanguage n) {
    final done = stagesDone[j.id] ?? 0;
    final badge = badges[j.id] ?? false;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: j, colors: c)))
          .then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: badge ? Border.all(color: const Color(0xFFFFD54F), width: 3) : null,
          boxShadow: [BoxShadow(color: c[1].withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(j.emoji, style: const TextStyle(fontSize: 36)),
            const Spacer(),
            if (badge)
              const Text('🏅', style: TextStyle(fontSize: 26))
            else if (done > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                child: Text('$done/$_stageCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ]),
          const Spacer(),
          Text(j.title(n),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, height: 1.2)),
          if (n != AppLanguage.german)
            Text(j.de, textDirection: TextDirection.ltr, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
        ]),
      ),
    );
  }
}

class JobDetailScreen extends StatefulWidget {
  final JobInfo job;
  final List<Color> colors;
  const JobDetailScreen({super.key, required this.job, required this.colors});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  List<int> best = List.filled(_stageCount, 0);
  int testBest = 0;

  JobInfo get job => widget.job;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = [for (var s = 0; s < _stageCount; s++) await jobStageBest(job.id, s)];
    final t = await jobTestBest(job.id);
    if (mounted) {
      setState(() {
        best = b;
        testBest = t;
      });
    }
  }

  void _practice(int stage, List<WordConcept> concepts) {
    final list = [...concepts]..shuffle();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => InteractiveLessonScreen(unit: null, concepts: list, onDone: (pc) => _saveStage(job.id, stage, pc))),
    ).then((_) => _load());
  }

  void _test() {
    final n = ProgressService.instance.nativeLang;
    final before = testBest;
    final list = [...job.all, ...job.dialog.map((d) => d.c)]..shuffle();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InteractiveLessonScreen(
          unit: null,
          concepts: list.take(15).toList(),
          maxQuestions: 15,
          onDone: (pc) async {
            final p = await SharedPreferences.getInstance();
            if (pc > (p.getInt('job_test_${job.id}') ?? 0)) await p.setInt('job_test_${job.id}', pc);
          },
        ),
      ),
    ).then((_) async {
      await _load();
      if (!mounted) return;
      if (testBest >= 80 && before < 80) {
        Sfx.star();
        showDialog<void>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: n.direction,
            child: AlertDialog(
              title: Text('🏅 ${tr(n, 'نیشانا کاری!', 'Abzeichen!', 'Badge earned!')}', textAlign: TextAlign.center),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(job.emoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(
                  tr(n, 'دەستخۆش! تە نیشانا «${job.ku}» وەرگرت. ل سەر پرۆفایلا تە دیار دبیت.',
                      'Super! Du hast das Abzeichen „${job.de}“. Es erscheint in deinem Profil.',
                      'Great! You earned the “${job.en}” badge. It shows on your profile.'),
                  textAlign: TextAlign.center,
                ),
              ]),
              actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(n, 'باشە', 'OK', 'OK')))],
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = ProgressService.instance.nativeLang;
    final colors = widget.colors;
    final stages = <(String, String, List<WordConcept>, String)>[
      ('📚', tr(n, 'پەیڤێن سەرەکی', 'Grundwörter', 'Key words'), job.basics, tr(n, '١٥ پەیڤ', '15 Wörter', '15 words')),
      ('⚡', tr(n, 'کار و ڕەنگدان', 'Verben & Adjektive', 'Verbs & adjectives'), job.actions, tr(n, '١٠ پەیڤ', '10 Wörter', '10 words')),
      ('💬', tr(n, 'رستێن کاری', 'Sätze', 'Phrases'), job.phrases, tr(n, '١٢ رستە', '12 Sätze', '12 phrases')),
      ('🗣️', tr(n, 'دیالۆگ', 'Dialog', 'Dialogue'), job.dialog.map((d) => d.c).toList(),
          tr(n, '${job.dialog.length} ڕێز', '${job.dialog.length} Zeilen', '${job.dialog.length} lines')),
    ];
    return Directionality(
      textDirection: n.direction,
      child: Scaffold(
        body: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 170,
            backgroundColor: colors[1],
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(job.title(n), style: const TextStyle(fontWeight: FontWeight.w900)),
              background: Container(
                decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsetsDirectional.only(end: 24, top: 20),
                child: Text(job.emoji, style: const TextStyle(fontSize: 72)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
            sliver: SliverList.list(children: [
              for (var s = 0; s < stages.length; s++)
                _stageCard(
                  s,
                  stages[s].$1,
                  stages[s].$2,
                  stages[s].$4,
                  colors[0],
                  onTap: s == 3
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDialogScreen(job: job, color: colors[0])))
                          .then((_) => _load())
                      : () => _practice(s, stages[s].$3),
                ),
              const SizedBox(height: 6),
              _testCard(n),
              const SizedBox(height: 22),
              _head(tr(n, '📚 هەمی پەیڤ', '📚 Alle Wörter', '📚 All words')),
              for (final w in job.words) _row(w, n),
              const SizedBox(height: 16),
              _head(tr(n, '💬 هەمی رستە', '💬 Alle Sätze', '💬 All phrases')),
              for (final w in job.phrases) _row(w, n),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stageCard(int s, String emo, String title, String sub, Color color, {required VoidCallback onTap}) {
    final b = best[s];
    final done = b > 0;
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18), side: BorderSide(color: done ? color : AppColors.fg12, width: done ? 2 : 1)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.18),
          child: Text(emo, style: const TextStyle(fontSize: 24)),
        ),
        title: Text('${s + 1}. $title', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        subtitle: Text(sub, style: TextStyle(color: AppColors.fg60)),
        trailing: done
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                child: Text(b >= 90 ? '⭐ $b%' : '$b%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              )
            : Icon(Icons.play_circle_fill_rounded, color: color, size: 34),
      ),
    );
  }

  Widget _testCard(AppLanguage n) {
    final badge = testBest >= 80;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _test,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: badge ? const [Color(0xFFFFD54F), Color(0xFFFFA000)] : const [Color(0xFF3B4A55), Color(0xFF2A363F)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Text(badge ? '🏅' : '🏆', style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(n, 'تاقیکرنا کاری', 'Berufstest', 'Job test'),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: badge ? Colors.black87 : Colors.white)),
              Text(
                badge
                    ? tr(n, 'نیشان وەرگرت ✅ · $testBest%', 'Abzeichen ✅ · $testBest%', 'Badge earned ✅ · $testBest%')
                    : tr(n, '١٥ پرسیار · ب ٨٠٪ نیشانا 🏅 وەردگری', '15 Fragen · ab 80 % gibt es 🏅', '15 questions · 80% earns 🏅'),
                style: TextStyle(color: badge ? Colors.black54 : Colors.white70),
              ),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: badge ? Colors.black54 : Colors.white70),
        ]),
      ),
    );
  }

  Widget _head(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      );

  Widget _row(WordConcept w, AppLanguage n) => Card(
        color: AppColors.card,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          onTap: () => VoiceService.instance.speakText(w.de, AppLanguage.german, rate: 0.9),
          leading: w.emoji.isEmpty ? null : Text(w.emoji, style: const TextStyle(fontSize: 26)),
          title: Text(w.de, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (w.deHint.isNotEmpty && n == AppLanguage.badini) Text(w.deHint, style: TextStyle(color: AppColors.accent, fontSize: 12)),
            Text(n == AppLanguage.english ? w.en : w.ku, style: TextStyle(color: AppColors.fg70)),
          ]),
          trailing: Icon(Icons.volume_up_rounded, color: AppColors.fg54),
        ),
      );
}

/// 🗣️ دیالۆگا کاری: ڕێز ب ڕێز (گوهداری + وەرگێڕان) پاشان راهێنان
class JobDialogScreen extends StatefulWidget {
  final JobInfo job;
  final Color color;
  const JobDialogScreen({super.key, required this.job, required this.color});

  @override
  State<JobDialogScreen> createState() => _JobDialogScreenState();
}

class _JobDialogScreenState extends State<JobDialogScreen> {
  int shown = 1; // ڕێز ب ڕێز دیار دبن
  bool showKu = true;
  int? playing;

  List<DialogLine> get lines => widget.job.dialog;

  Future<void> _play(int k) async {
    setState(() => playing = k);
    await VoiceService.instance.speakText(lines[k].c.de, AppLanguage.german, gender: k.isEven ? 'f' : 'm');
    if (mounted) setState(() => playing = null);
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _play(0);
    });
  }

  @override
  void dispose() {
    VoiceService.instance.stopPlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = ProgressService.instance.nativeLang;
    final first = lines.first.who;
    final done = shown >= lines.length;
    return Directionality(
      textDirection: n.direction,
      child: Scaffold(
        appBar: AppBar(
          title: Text('🗣️ ${tr(n, 'دیالۆگ', 'Dialog', 'Dialogue')} · ${widget.job.title(n)}'),
          actions: [
            IconButton(
              tooltip: tr(n, 'وەرگێڕان', 'Übersetzung', 'Translation'),
              icon: Icon(showKu ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              onPressed: () => setState(() => showKu = !showKu),
            ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              for (var k = 0; k < shown && k < lines.length; k++) _bubble(k, lines[k].who == first),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: done
                ? BigButton(
                    label: tr(n, 'راهێنان ل سەر دیالۆگێ', 'Dialog üben', 'Practise the dialogue'),
                    icon: Icons.fitness_center_rounded,
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InteractiveLessonScreen(
                          unit: null,
                          concepts: [for (final l in lines) l.c],
                          onDone: (pc) => _saveStage(widget.job.id, 3, pc),
                        ),
                      ),
                    ),
                  )
                : BigButton(
                    label: tr(n, 'ڕێزا دی ➜', 'Weiter ➜', 'Next line ➜'),
                    onPressed: () {
                      setState(() => shown++);
                      _play(shown - 1);
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _bubble(int k, bool left) {
    final l = lines[k];
    final active = playing == k;
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onTap: () => _play(k),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: left ? AppColors.card : widget.color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? widget.color : AppColors.fg12, width: active ? 2.4 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.who, textDirection: TextDirection.ltr, style: TextStyle(color: widget.color, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(l.c.de, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            if (showKu) ...[
              const SizedBox(height: 6),
              Text(l.c.ku, textDirection: TextDirection.rtl, style: TextStyle(color: AppColors.fg60)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// 🏅 ریزا نیشانێن کاری (بۆ پرۆفایلێ)
class JobBadgesRow extends StatelessWidget {
  const JobBadgesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final n = ProgressService.instance.nativeLang;
    return FutureBuilder<List<JobInfo>>(
      future: earnedJobBadges(),
      builder: (_, s) {
        final list = s.data ?? const <JobInfo>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(n, '🏅 نیشانێن کاری', '🏅 Berufs-Abzeichen', '🏅 Job badges'), style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final j in list)
                Tooltip(
                  message: j.title(n),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFA000)]),
                      boxShadow: [BoxShadow(color: const Color(0xFFFFA000).withValues(alpha: 0.4), blurRadius: 8)],
                    ),
                    child: Text(j.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ]),
          ]),
        );
      },
    );
  }
}
