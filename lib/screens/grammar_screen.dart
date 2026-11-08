import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'book_screen.dart' show BookTable;

/// 📘 رێزمان ل دویف وانێ (Lektion 1–14): ڕوونکرن ب ئەلمانی، ب دوگمەیەکێ دبیتە کوردی.

class GramText {
  final String de, ku;
  const GramText(this.de, this.ku);
  factory GramText.of(dynamic m) => GramText(m['de'] as String, m['ku'] as String);
  String get(bool ku) => ku ? this.ku : de;
}

class GramTopic {
  final String emoji;
  final GramText title, explain;
  final GramText? tip;
  final List<String> head;
  final List<List<String>> rows;
  final List<GramText> examples;
  const GramTopic(this.emoji, this.title, this.explain, this.tip, this.head, this.rows, this.examples);
}

class Grammar {
  static Map<int, List<GramTopic>> byLektion = {};
  static Future<void>? _loading;

  static Future<void> load() => _loading ??= () async {
        final m = jsonDecode(await rootBundle.loadString('assets/grammar.json')) as Map<String, dynamic>;
        List<String> strs(dynamic v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();
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
                  for (var i = 0; i < topics.length; i++) _topic(topics[i], i + 1, color, ku),
                ],
              ),
      ),
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
