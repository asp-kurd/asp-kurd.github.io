import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/sfx.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'book_screen.dart' show BookTable;
import 'widgets/combo.dart' show showXpPop;
import 'widgets/mascot.dart';

/// 📘 رێزمان ل دویف وانێ (Lektion 1–14): ڕوونکرن ب ئەلمانی، ب دوگمەیەکێ دبیتە کوردی.

class GramText {
  final String de, ku;
  const GramText(this.de, this.ku);
  factory GramText.of(dynamic m) => GramText(m['de'] as String, m['ku'] as String);
  String get(bool ku) => ku ? this.ku : de;
}

/// 🎯 پرسیار و بەرسڤ بۆ راهێنانێ
class GramPractice {
  final String q, qku, cue, a, aku;
  const GramPractice(this.q, this.qku, this.cue, this.a, this.aku);
  factory GramPractice.of(dynamic m) =>
      GramPractice(m['q'] as String, (m['qku'] ?? '') as String, (m['cue'] ?? '') as String, m['a'] as String, (m['aku'] ?? '') as String);

  /// پرسیارێن وەکی «der Apfel → Plural?» دەنگ نینن
  bool get speakableQ => !RegExp(r'[→:(]|___').hasMatch(q);
}

class GramTopic {
  final String emoji;
  final GramText title, explain;
  final GramText? tip;
  final List<String> head;
  final List<List<String>> rows;
  final List<GramText> examples;
  final List<GramPractice> practice;
  const GramTopic(this.emoji, this.title, this.explain, this.tip, this.head, this.rows, this.examples, this.practice);
}

/// 💬 رستێن ئامادە یێن وانێ (Kommunikation)
class KommGroup {
  final String emoji, de, ku;
  final List<GramText> lines;
  const KommGroup(this.emoji, this.de, this.ku, this.lines);
}

class Grammar {
  static Map<int, List<GramTopic>> byLektion = {};
  static Map<int, List<KommGroup>> komm = {};
  static Future<void>? _loading;

  static Future<void> load() => _loading ??= () async {
        final m = jsonDecode(await rootBundle.loadString('assets/grammar.json')) as Map<String, dynamic>;
        List<String> strs(dynamic v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();
        try {
          final k = jsonDecode(await rootBundle.loadString('assets/kommunikation.json')) as Map<String, dynamic>;
          komm = {
            for (final l in k['lektionen'] as List)
              l['n'] as int: [
                for (final g in l['groups'] as List)
                  KommGroup(g['emoji'] as String, g['de'] as String, g['ku'] as String, (g['lines'] as List).map(GramText.of).toList()),
              ],
          };
        } catch (_) {}
        byLektion = {
          for (final l in m['lektionen'] as List)
            l['n'] as int: [
              for (final t in l['topics'] as List)
                GramTopic(
                  t['emoji'] as String,
                  GramText.of(t['title']),
                  GramText.of(t['explain']),
                  t['tip'] == null ? null : GramText.of(t['tip']),
                  strs(t['head']),
                  (t['rows'] as List).map(strs).toList(),
                  (t['examples'] as List).map(GramText.of).toList(),
                  ((t['practice'] as List?) ?? const []).map(GramPractice.of).toList(),
                ),
            ],
        };
      }();

  /// 'de' (سەرەکی) یان 'ku'
  static bool kurdish = false;
  static Future<void> loadLang() async {
    try {
      kurdish = (await SharedPreferences.getInstance()).getBool('gram_ku') ?? false;
    } catch (_) {}
  }

  static Future<void> setKurdish(bool v) async {
    kurdish = v;
    try {
      await (await SharedPreferences.getInstance()).setBool('gram_ku', v);
    } catch (_) {}
  }
}

Future<void> _say(String de) => VoiceService.instance.speakText(de, AppLanguage.german);

/// 📘 کارتا دەستپێکێ (د تابێ پەرتووکێ دا)
class GrammarBanner extends StatelessWidget {
  const GrammarBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrammarListScreen())),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF58CC02), Color(0xFF1CB0F6)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(children: [
          Text('📘', style: TextStyle(fontSize: 34)),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Grammatik — Lektion 1–14', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              SizedBox(height: 4),
              Text('رێزمانا هەر وانەکێ ب ئەلمانی + کوردی', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
          Icon(Icons.chevron_left_rounded, color: Colors.white, size: 30),
        ]),
      ),
    );
  }
}

// ───────── لیستا وانان ─────────
class GrammarListScreen extends StatefulWidget {
  const GrammarListScreen({super.key});
  @override
  State<GrammarListScreen> createState() => _GrammarListScreenState();
}

class _GrammarListScreenState extends State<GrammarListScreen> {
  @override
  void initState() {
    super.initState();
    Future.wait([Grammar.load(), Grammar.loadLang()]).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ns = Grammar.byLektion.keys.toList()..sort();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('📘 رێزمان ل دویف وانێ')),
        body: ns.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [for (final n in ns) _tile(n)],
              ),
      ),
    );
  }

  Widget _tile(int n) {
    final lek = appLektionen.where((l) => l.n == n).firstOrNull;
    final color = lek?.color ?? AppColors.blue;
    final topics = Grammar.byLektion[n]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GrammarLektionScreen(n: n))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color,
              child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lek?.titleKu ?? 'Lektion $n', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(topics.map((t) => '${t.emoji} ${t.title.de}').join('  ·  '),
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.fg60, fontSize: 13)),
                ),
              ]),
            ),
            Icon(Icons.chevron_left_rounded, color: AppColors.fg54),
          ]),
        ),
      ),
    );
  }
}

// ───────── رێزمانا ئێک وانێ ─────────
class GrammarLektionScreen extends StatefulWidget {
  final int n;
  const GrammarLektionScreen({super.key, required this.n});
  @override
  State<GrammarLektionScreen> createState() => _GrammarLektionScreenState();
}

class _GrammarLektionScreenState extends State<GrammarLektionScreen> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    Future.wait([Grammar.load(), Grammar.loadLang()]).then((_) {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lek = appLektionen.where((l) => l.n == widget.n).firstOrNull;
    final color = lek?.color ?? AppColors.blue;
    final topics = Grammar.byLektion[widget.n] ?? const [];
    final ku = Grammar.kurdish;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('📘 Lektion ${widget.n} · Grammatik')),
        body: !ready
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                children: [
                  if (lek != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('${lek.titleKu} · ${lek.titleDe}',
                          style: TextStyle(fontFamily: 'Sarchia', fontSize: 17, color: color, fontWeight: FontWeight.bold)),
                    ),
                  _langSwitch(ku),
                  const SizedBox(height: 14),
                  if ((Grammar.komm[widget.n] ?? const []).isNotEmpty) _kommCard(Grammar.komm[widget.n]!, color),
                  for (var i = 0; i < topics.length; i++) _topic(topics[i], i + 1, color, ku),
                ],
              ),
      ),
    );
  }

  bool _kommOpen = false;

  /// 💬 Kommunikation: رستێن ئامادە یێن پەرتووکێ — بکە تپ دا گوهداری بکەی
  Widget _kommCard(List<KommGroup> groups, Color color) {
    final count = groups.fold<int>(0, (a, g) => a + g.lines.length);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _kommOpen = !_kommOpen),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Text('💬', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kommunikation — رستێن ئامادە', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('$count رستە ژ پەرتووکێ · بکە تپ دا گوهداری بکەی', style: TextStyle(color: AppColors.fg60, fontSize: 13)),
                ]),
              ),
              Icon(_kommOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.fg60),
            ]),
          ),
        ),
        if (_kommOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Text('${g.emoji} ${g.ku} · ${g.de}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                ),
                for (final l in g.lines) _example(l, color),
              ],
            ]),
          ),
      ]),
    );
  }

  /// 🇩🇪 Deutsch ⇄ ☀️ کوردی
  Widget _langSwitch(bool ku) {
    Widget opt(bool v, String label) {
      final sel = ku == v;
      return Expanded(
        child: GestureDetector(
          onTap: () async {
            await Grammar.setKurdish(v);
            setState(() {});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? AppColors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: sel ? Colors.white : AppColors.fg70)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(15)),
      child: Row(children: [opt(false, '🇩🇪 Deutsch'), const SizedBox(width: 4), opt(true, '☀️ کوردی')]),
    );
  }

  Widget _topic(GramTopic t, int i, Color color, bool ku) {
    final dir = ku ? TextDirection.rtl : TextDirection.ltr;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border(top: BorderSide(color: color, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // سەرناڤ: هەردەم ب ئەلمانی + کوردی ل بن
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            Text(t.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${widget.n}.$i  ${t.title.de}',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.germanText)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Text(t.title.ku, textDirection: TextDirection.rtl, style: TextStyle(color: AppColors.fg54, fontSize: 14)),
        ),
        // ڕوونکرن
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(t.explain.get(ku),
              key: ValueKey(ku), textDirection: dir, style: TextStyle(fontSize: 16, height: 1.6, color: AppColors.fg)),
        ),
        if (t.head.isNotEmpty) ...[
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: BookTable(head: t.head, rows: t.rows, accent: color),
          ),
        ],
        const SizedBox(height: 12),
        Text(ku ? '🔊 نموونە — بکە تپ دا گوهداری بکەی' : '🔊 Beispiele — tippen zum Anhören',
            textDirection: dir, style: TextStyle(color: AppColors.fg60, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        for (final e in t.examples) _example(e, color),
        if (t.practice.length >= 2)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => GrammarPracticeScreen(topic: t, color: color, pool: Grammar.byLektion[widget.n] ?? const []))),
              icon: const Text('🎯', style: TextStyle(fontSize: 18)),
              label: Text(ku ? 'راهێنان — نوکە تو بەرسڤێ بدە!' : 'Üben – jetzt bist du dran!',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        if (t.tip != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Text('💡 ${t.tip!.get(ku)}', textDirection: dir, style: TextStyle(height: 1.5, color: AppColors.fg)),
          ),
      ]),
    );
  }

  Widget _example(GramText e, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _say(e.de),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
          child: Row(textDirection: TextDirection.ltr, children: [
            Icon(Icons.volume_up_rounded, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(e.de, textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.germanText)),
                const SizedBox(height: 2),
                Text(e.ku, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 14, color: AppColors.fg60)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}


// ═════════════════════════ 🎯 راهێنانا رێزمانێ ═════════════════════════
/// ئێکەم: نموونە (پرسیار + بەرسڤ). پاشان: پرسیار دهێت و تو بەرسڤێ ددەی —
/// ✍️ بنڤیسە، یان 🧩 پەیڤان هەلبژێرە، یان ⏭️ دەرباز بکە.
class GrammarPracticeScreen extends StatefulWidget {
  final GramTopic topic;
  final Color color;
  final List<GramTopic> pool;
  const GrammarPracticeScreen({super.key, required this.topic, required this.color, this.pool = const []});

  @override
  State<GrammarPracticeScreen> createState() => _GrammarPracticeScreenState();
}

class _GrammarPracticeScreenState extends State<GrammarPracticeScreen> {
  final voice = VoiceService.instance;
  late final model = widget.topic.practice.first;
  late final tasks = widget.topic.practice.skip(1).toList();
  int step = -1; // -1 = نموونە
  bool writeMode = false;
  final ctrl = TextEditingController();
  List<String> tiles = [];
  List<int> picked = [];
  bool? result; // null = هێشتا نەهاتییە پشکنین
  bool skipped = false;
  int correct = 0, xp = 0;
  late final MascotChar asker = MascotChar.forUser().gender == 'f' ? MascotChar.hawraz : MascotChar.nazdar;
  late final MascotChar me = MascotChar.forUser();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playModel());
  }

  @override
  void dispose() {
    ctrl.dispose();
    voice.stopPlayback();
    super.dispose();
  }

  Future<void> _playModel() async {
    if (!mounted || step != -1) return;
    if (model.speakableQ) {
      await voice.speakText(model.q, AppLanguage.german, gender: asker.gender);
      await Future.delayed(Duration(milliseconds: 900 + model.q.length * 70));
    }
    if (!mounted || step != -1) return;
    voice.speakText(model.a, AppLanguage.german, gender: me.gender);
  }

  GramPractice get task => tasks[step];

  void _go(int k) {
    voice.stopPlayback();
    setState(() {
      step = k;
      result = null;
      skipped = false;
      ctrl.clear();
      picked = [];
      if (k >= 0 && k < tasks.length) {
        final words = _words(task.a);
        final others = <String>{
          for (final t in [...widget.pool, widget.topic])
            for (final p in t.practice)
              for (final w in _words(p.a))
                if (!words.contains(w)) w,
        }.toList()
          ..shuffle(Random());
        tiles = [...words, ...others.take(3)]..shuffle(Random());
      }
    });
    if (k >= 0 && k < tasks.length && task.speakableQ) {
      final s = k;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && step == s) voice.speakText(task.q, AppLanguage.german, gender: asker.gender);
      });
    }
  }

  static List<String> _words(String s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[.,!?;:„“"«»]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String get _answerText => writeMode ? ctrl.text : picked.map((i) => tiles[i]).join(' ');

  void _check() {
    final ok = _norm(_answerText) == _norm(task.a);
    setState(() => result = ok);
    if (ok) {
      Sfx.correct();
      correct++;
      xp += 3;
      showXpPop(context, 3);
    } else {
      Sfx.wrong();
    }
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) voice.speakText(task.a, AppLanguage.german, gender: me.gender);
    });
  }

  void _skip() {
    setState(() {
      skipped = true;
      result = false;
    });
    voice.speakText(task.a, AppLanguage.german, gender: me.gender);
  }

  Future<void> _finish() async {
    if (xp > 0) await ProgressService.instance.earn(xp);
    if (mounted) setState(() => step = tasks.length);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('🎯 ${widget.topic.title.de}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 17)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(
              value: (step + 1).clamp(0, tasks.length + 1) / (tasks.length + 1),
              color: color,
              backgroundColor: AppColors.card,
              minHeight: 6,
            ),
          ),
        ),
        body: SafeArea(
          child: step == -1 ? _modelView(color) : (step >= tasks.length ? _doneView(color) : _taskView(color)),
        ),
      ),
    );
  }

  Widget _bubble(MascotChar c, String de, String ku, {required bool left, VoidCallback? onTap, Color? border}) {
    final b = Flexible(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border ?? AppColors.fg12, width: 2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(textDirection: TextDirection.ltr, children: [
              Expanded(
                child: Text(de, textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.germanText)),
              ),
              if (onTap != null) Icon(Icons.volume_up_rounded, color: AppColors.blue, size: 22),
            ]),
            if (ku.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(ku, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 14, color: AppColors.fg60)),
            ],
          ]),
        ),
      ),
    );
    final av = MascotAvatar(char: c, size: 54);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: left ? [av, const SizedBox(width: 8), b] : [b, const SizedBox(width: 8), av],
      ),
    );
  }

  Widget _modelView(Color color) => ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: const Text('👀 نموونە — بەری هەمیان گوهداری بکە', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        _bubble(asker, model.q, model.qku,
            left: true, onTap: model.speakableQ ? () => voice.speakText(model.q, AppLanguage.german, gender: asker.gender) : null),
        if (model.cue.isNotEmpty) _cue(model.cue),
        _bubble(me, model.a, model.aku,
            left: false, border: AppColors.green, onTap: () => voice.speakText(model.a, AppLanguage.german, gender: me.gender)),
        const SizedBox(height: 18),
        BigButton(label: 'نوکە تو! 💪', color: color, onPressed: () => _go(0)),
      ]);

  Widget _cue(String cue) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
            child: Text('💡 $cue', textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.goldText)),
          ),
        ),
      );

  Widget _taskView(Color color) {
    final t = task;
    final done = result != null;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          _bubble(asker, t.q, t.qku, left: true, onTap: t.speakableQ ? () => voice.speakText(t.q, AppLanguage.german, gender: asker.gender) : null),
          if (t.cue.isNotEmpty) _cue(t.cue),
          if (done)
            _bubble(me, t.a, t.aku,
                left: false,
                border: result! ? AppColors.green : AppColors.red,
                onTap: () => voice.speakText(t.a, AppLanguage.german, gender: me.gender)),
          if (!done) ...[
            // ✍️ / 🧩
            Row(children: [
              Expanded(child: _modeBtn(false, '🧩 پەیڤان هەلبژێرە')),
              const SizedBox(width: 8),
              Expanded(child: _modeBtn(true, '✍️ بنڤیسە')),
            ]),
            const SizedBox(height: 14),
            if (writeMode)
              TextField(
                controller: ctrl,
                autofocus: true,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 20),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Schreib deine Antwort …',
                  hintTextDirection: TextDirection.ltr,
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )
            else
              _bank(color),
          ],
          if (done && !result!)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(skipped ? '⏭️ بەرسڤا دروست ئەڤەیە 👆' : '❌ نە دروستە — بەرسڤا دروست ئەڤەیە 👆',
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
            ),
          if (done && result!)
            const Text('✅ دروستە! دەستخۆش', textAlign: TextAlign.center, style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: done
            ? BigButton(
                label: step + 1 < tasks.length ? 'پرسیارا دی' : 'تەمام',
                color: result! ? AppColors.green : color,
                onPressed: () => step + 1 < tasks.length ? _go(step + 1) : _finish(),
              )
            : Row(children: [
                TextButton.icon(
                  onPressed: _skip,
                  icon: const Text('⏭️'),
                  label: const Text('دەرباز بکە'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BigButton(
                    label: 'پشکنین',
                    color: AppColors.blue,
                    onPressed: _answerText.trim().isEmpty ? null : _check,
                  ),
                ),
              ]),
      ),
    ]);
  }

  Widget _modeBtn(bool write, String label) {
    final sel = writeMode == write;
    return GestureDetector(
      onTap: () => setState(() => writeMode = write),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? AppColors.blue : AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.fg70)),
      ),
    );
  }

  Widget _bank(Color color) {
    Widget chip(int i, bool inAnswer) => Padding(
          padding: const EdgeInsets.all(4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => inAnswer ? picked.remove(i) : picked.add(i)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: inAnswer ? color : AppColors.fg24, width: 2),
              ),
              child: Text(tiles[i], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
        );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.fg24, width: 2))),
          child: Wrap(children: [for (final i in picked) chip(i, true)]),
        ),
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.center, children: [
          for (var i = 0; i < tiles.length; i++)
            if (!picked.contains(i)) chip(i, false),
        ]),
      ]),
    );
  }

  Widget _doneView(Color color) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            MascotView(char: me, mood: correct == tasks.length ? MascotMood.happy : MascotMood.think, height: 170),
            const SizedBox(height: 14),
            Text('${kuDigits(correct)} ژ ${kuDigits(tasks.length)} دروست', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            if (xp > 0) Text('+$xp XP', style: TextStyle(fontSize: 20, color: AppColors.goldText, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            BigButton(label: 'دیسا راهێنان بکە 🔁', color: color, onPressed: () {
              setState(() {
                correct = 0;
                xp = 0;
              });
              _go(0);
            }),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('زڤڕین بۆ رێزمانێ')),
          ]),
        ),
      );
}

String kuDigits(int n) => n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();
