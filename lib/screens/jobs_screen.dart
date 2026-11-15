import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../services/progress_service.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'lesson_screen.dart';

/// 💼 پەیڤێن کاری (A1): فێرخواز کارەکێ هەلدبژێریت و ل سەر پەیڤ و رستێن وی کاری راهێنانێ دکەت.
class JobInfo {
  final String id, emoji, ku, de, en;
  final List<WordConcept> words, phrases;
  const JobInfo(this.id, this.emoji, this.ku, this.de, this.en, this.words, this.phrases);

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
        en: '${it['en']}',
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
        [for (final it in j['items'] as List) if (it['phrase'] != true) wc(it as Map)],
        [for (final it in j['items'] as List) if (it['phrase'] == true) wc(it as Map)],
      ),
  ];
}

/// باشترین ئەنجام (٪) بۆ هەر کارەکی — ل سەر مۆبایلێ (و دگەل پێشکەفتنێ دچیتە سەر سێرڤەری)
Future<int> jobBest(String id) async => (await SharedPreferences.getInstance()).getInt('job_best_$id') ?? 0;

Future<void> _saveBest(String id, int percent) async {
  final p = await SharedPreferences.getInstance();
  if (percent > (p.getInt('job_best_$id') ?? 0)) await p.setInt('job_best_$id', percent);
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
  Map<String, int> best = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final j = await loadJobs();
    final b = {for (final x in j) x.id: await jobBest(x.id)};
    if (!mounted) return;
    setState(() {
      jobs = j;
      best = b;
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
                  tr(n, 'کارێ خۆ هەلبژێرە و ئەو پەیڤ و رستێن کو ل سەر کاری پێدڤی دبن فێر ببە. هەمی ژ ئاستێ A1 دەست پێ دکەن.',
                      'Wähle deinen Beruf und lerne die wichtigsten Wörter und Sätze. Alles auf Niveau A1.',
                      'Pick your job and learn the words and phrases you need at work. Everything starts at A1.'),
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
    final b = best[j.id] ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: j, colors: c)))
          .then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: c[1].withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(j.emoji, style: const TextStyle(fontSize: 36)),
            const Spacer(),
            if (b > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                child: Text(b >= 90 ? '⭐ $b%' : '$b%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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

class JobDetailScreen extends StatelessWidget {
  final JobInfo job;
  final List<Color> colors;
  const JobDetailScreen({super.key, required this.job, required this.colors});

  void _practice(BuildContext context, List<WordConcept> concepts) {
    final list = [...concepts]..shuffle();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InteractiveLessonScreen(unit: null, concepts: list, onDone: (pc) => _saveBest(job.id, pc)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = ProgressService.instance.nativeLang;
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
              BigButton(
                label: tr(n, 'دەست ب راهێنانێ بکە', 'Üben', 'Start practice'),
                icon: Icons.play_arrow_rounded,
                onPressed: () => _practice(context, job.all),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _practice(context, job.words),
                    icon: const Icon(Icons.abc_rounded),
                    label: Text(tr(n, 'تنێ پەیڤ', 'Nur Wörter', 'Words only')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _practice(context, job.phrases),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(tr(n, 'تنێ رستە', 'Nur Sätze', 'Phrases only')),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              _head(tr(n, '📚 پەیڤ', '📚 Wörter', '📚 Words')),
              for (final w in job.words) _row(w, n),
              const SizedBox(height: 16),
              _head(tr(n, '💬 رستە', '💬 Sätze', '💬 Phrases')),
              for (final w in job.phrases) _row(w, n),
            ]),
          ),
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
            if (w.deHint.isNotEmpty && n == AppLanguage.badini)
              Text(w.deHint, style: TextStyle(color: AppColors.accent, fontSize: 12)),
            Text(n == AppLanguage.english ? w.en : w.ku, style: TextStyle(color: AppColors.fg70)),
          ]),
          trailing: Icon(Icons.volume_up_rounded, color: AppColors.fg54),
        ),
      );
}
