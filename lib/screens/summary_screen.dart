import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/sfx.dart';
import '../ui.dart';
import 'book_screen.dart';

/// ⚡ «A1 mit Poya» — پوختەیێن رێزمانێ یێن A1: یاسا، خشتە، و شیکرنا رستان ب رەنگان.

class SumPart {
  final String text, kind;
  const SumPart(this.text, this.kind);
}

class SumExample {
  final String de, ku;
  final List<SumPart> parts;
  const SumExample(this.de, this.ku, this.parts);
}

class SumCard {
  final String id, emoji, title, de;
  final Color color;
  final List<String> rules;
  final List<String> head;
  final List<List<String>> rows;
  final List<SumExample> examples;
  final String? tip;

  /// ⬇️ نموونەیێن زێدەتر (ل بن تیرێ) — هەروەسا بۆ راهێنانێ دهێنە بکارئینان
  final List<SumExample> more;
  const SumCard(this.id, this.emoji, this.color, this.title, this.de, this.rules, this.head, this.rows, this.examples, this.tip,
      {this.more = const []});
}

class A1Summary {
  static String title = 'A1 mit Poya', subtitle = '';
  static Map<String, (String ku, String de, Color color)> legend = {};
  static List<SumCard> cards = [];
  static Future<void>? _loading;

  static Color _hex(String s) => Color(int.parse('FF${s.replaceAll('#', '')}', radix: 16));

  static Future<void> load() => _loading ??= () async {
        final m = jsonDecode(await rootBundle.loadString('assets/a1_summary.json')) as Map<String, dynamic>;
        title = m['title'] as String;
        subtitle = (m['subtitle'] as String?) ?? '';
        legend = {
          for (final e in (m['legend'] as Map<String, dynamic>).entries)
            e.key: ((e.value as List)[0] as String, (e.value as List)[1] as String, _hex((e.value as List)[2] as String)),
        };
        List<String> strs(dynamic v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();
        List<SumExample> exs(dynamic v) => ((v as List?) ?? const [])
            .map((e) => SumExample(e['de'] as String, e['ku'] as String,
                (e['parts'] as List).map((p) => SumPart((p as List)[0] as String, p[1] as String)).toList()))
            .toList();
        cards = (m['cards'] as List).map((c) {
          final t = c['table'] as Map<String, dynamic>?;
          return SumCard(
            c['id'] as String,
            c['emoji'] as String,
            _hex(c['color'] as String),
            c['title'] as String,
            c['de'] as String,
            strs(c['rules']),
            t == null ? const [] : strs(t['head']),
            t == null ? const [] : (t['rows'] as List).map(strs).toList(),
            exs(c['examples']),
            c['tip'] as String?,
            more: exs(c['more']),
          );
        }).toList();
      }();
}

/// 📗 کارتا دەستپێکێ د تابێ رێزمانێ دا
class SummaryBanner extends StatelessWidget {
  const SummaryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryListScreen())),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1CB0F6), Color(0xFF8E2DE2)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(children: [
          Text('⚡', style: TextStyle(fontSize: 34)),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('A1 mit Poya — پوختە', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
              SizedBox(height: 4),
              Text('هەمی رێزمانا A1 ب کورتی + شیکرنا رستان ب رەنگان',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
          Icon(Icons.chevron_left_rounded, color: Colors.white, size: 30),
        ]),
      ),
    );
  }
}

// ───────── لیستا پوختەیان ─────────
class SummaryListScreen extends StatefulWidget {
  const SummaryListScreen({super.key});
  @override
  State<SummaryListScreen> createState() => _SummaryListScreenState();
}

class _SummaryListScreenState extends State<SummaryListScreen> {
  String q = '';

  @override
  void initState() {
    super.initState();
    A1Summary.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = A1Summary.cards.where((c) {
      if (q.isEmpty) return true;
      final s = q.toLowerCase();
      return c.title.toLowerCase().contains(s) ||
          c.de.toLowerCase().contains(s) ||
          c.rules.any((r) => r.toLowerCase().contains(s)) ||
          c.examples.any((e) => e.de.toLowerCase().contains(s));
    }).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('⚡ A1 mit Poya')),
        body: A1Summary.cards.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
                Text(A1Summary.subtitle, style: TextStyle(color: AppColors.fg70, fontSize: 15)),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => q = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'بگەڕە… (بۆ نموونە: Dativ، kein، Perfekt)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                const LegendBox(),
                const SizedBox(height: 14),
                for (final c in cards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SummaryCardScreen(start: A1Summary.cards.indexOf(c))),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.color.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Row(children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: c.color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                            child: Text(c.emoji, style: const TextStyle(fontSize: 26)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${A1Summary.cards.indexOf(c) + 1}. ${c.title}',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              Text(c.de, textDirection: TextDirection.ltr, style: TextStyle(color: c.color, fontSize: 14)),
                            ]),
                          ),
                          Icon(Icons.chevron_left_rounded, color: AppColors.fg38),
                        ]),
                      ),
                    ),
                  ),
                if (cards.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('چ ئەنجام نەهاتنە دیتن', textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg60)),
                  ),
              ]),
      ),
    );
  }
}

/// 🎨 رامانا رەنگان د شیکرنا رستێ دا
class LegendBox extends StatelessWidget {
  const LegendBox({super.key});
  @override
  Widget build(BuildContext context) {
    const order = ['S', 'V', 'O', 'D', 'T', 'L', 'W', 'N', 'K', 'A'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🎨 شیکرنا رستێ: هەر رەنگەک چ دبێژیت؟', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in order)
            if (A1Summary.legend[k] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: A1Summary.legend[k]!.$3.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: A1Summary.legend[k]!.$3),
                ),
                child: Text('${A1Summary.legend[k]!.$1} · ${A1Summary.legend[k]!.$2}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.fg)),
              ),
        ]),
      ]),
    );
  }
}

// ───────── ئێک پوختە (ب swipe بۆ یا دی) ─────────
class SummaryCardScreen extends StatefulWidget {
  final int start;
  const SummaryCardScreen({super.key, required this.start});
  @override
  State<SummaryCardScreen> createState() => _SummaryCardScreenState();
}

class _SummaryCardScreenState extends State<SummaryCardScreen> {
  late final PageController _pc = PageController(initialPage: widget.start);
  late int i = widget.start;
  bool quiz = false; // 🧩 خۆ تاقی بکە: ناڤێن پارچان ڤەشارتینە
  final Set<String> revealed = {};
  final Set<String> moreOpen = {}; // ⬇️ کیژ کارت نموونەیێن زێدەتر ڤەکرینە

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = A1Summary.cards;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${i + 1} ژ ${cards.length}'),
          actions: [
            TextButton.icon(
              onPressed: () => setState(() {
                quiz = !quiz;
                revealed.clear();
              }),
              icon: Text(quiz ? '👁️' : '🧩'),
              label: Text(quiz ? 'نیشان بدە' : 'خۆ تاقی بکە'),
            ),
          ],
        ),
        body: PageView.builder(
          controller: _pc,
          reverse: true, // RTL: بۆ چەپێ = یا دی
          itemCount: cards.length,
          onPageChanged: (k) => setState(() {
            i = k;
            revealed.clear();
          }),
          itemBuilder: (_, k) => _page(cards[k]),
        ),
      ),
    );
  }

  Widget _page(SumCard c) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c.color, c.color.withValues(alpha: 0.7)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Text(c.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              Text(c.de, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 15, color: Colors.white)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _section('📌 یاسا'),
      for (final r in c.rules)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 9, left: 8),
              child: Container(width: 7, height: 7, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
            ),
            Expanded(child: rich(r, size: 16)),
          ]),
        ),
      if (c.head.isNotEmpty) ...[
        const SizedBox(height: 6),
        _section('📊 خشتە'),
        BookTable(head: c.head, rows: c.rows, accent: c.color),
      ],
      const SizedBox(height: 12),
      _section('🔍 شیکرنا رستان'),
      for (var k = 0; k < c.examples.length; k++) _example(c, k),
      if (c.more.isNotEmpty) ...[
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: moreOpen.contains(c.id)
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var k = 0; k < c.more.length; k++) _exampleOf(c, c.more[k], '${c.id}/m$k'),
                ])
              : const SizedBox(width: double.infinity),
        ),
        _moreArrow(c),
      ],
      const SizedBox(height: 10),
      _section('🎯 راهێنان: ئەڤ پەیڤە چ کارێ دکەت؟'),
      RoleDrill(key: ValueKey('drill-${c.id}'), card: c),
      if (c.tip != null) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💡 ', style: TextStyle(fontSize: 18)),
            Expanded(child: rich(c.tip!, size: 15)),
          ]),
        ),
      ],
    ]);
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      );

  Widget _moreArrow(SumCard c) {
    final open = moreOpen.contains(c.id);
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => setState(() => open ? moreOpen.remove(c.id) : moreOpen.add(c.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(open ? 'کێمتر نیشان بدە' : '${c.more.length} نموونەیێن زێدەتر',
                style: TextStyle(color: c.color, fontSize: 14, fontWeight: FontWeight.bold)),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 280),
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: c.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: c.color, size: 32),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _example(SumCard c, int k) => _exampleOf(c, c.examples[k], '${c.id}/$k');

  Widget _exampleOf(SumCard c, SumExample e, String key) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton.filledTonal(
            onPressed: () => sayGerman(e.de),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(e.de,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(spacing: 6, runSpacing: 8, children: [
            for (var p = 0; p < e.parts.length; p++) _chip(e.parts[p], '$key/$p'),
          ]),
        ),
        const SizedBox(height: 10),
        Text('💬 ${e.ku}', style: TextStyle(color: AppColors.fg70, fontSize: 15.5)),
      ]),
    );
  }

  Widget _chip(SumPart p, String key) {
    final l = A1Summary.legend[p.kind];
    if (l == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(p.text, style: TextStyle(fontSize: 18, color: AppColors.fg60)),
      );
    }
    final show = !quiz || revealed.contains(key);
    return GestureDetector(
      onTap: quiz ? () => setState(() => revealed.add(key)) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        decoration: BoxDecoration(
          color: (show ? l.$3 : AppColors.fg38).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: show ? l.$3 : AppColors.fg38, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(p.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(show ? l.$1 : '؟', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 11.5, color: show ? l.$3 : AppColors.fg60, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}




/// 🎯 راهێنان: پەیڤەکا رستێ دیار دبیت ➔ «ل ڤێرە چ کارێ دکەت؟» (بکەر، کار، بەرکار، دەم، جه …)
class RoleDrill extends StatefulWidget {
  final SumCard card;
  const RoleDrill({super.key, required this.card});
  @override
  State<RoleDrill> createState() => _RoleDrillState();
}

class _RoleDrillState extends State<RoleDrill> {
  static const _roles = ['S', 'V', 'O', 'D', 'T', 'L', 'W', 'N', 'K', 'V2'];
  static const _base = ['S', 'V', 'O', 'T', 'L', 'D'];
  static const _len = 6;
  final _rng = Random();
  late List<(SumExample, int)> qs;
  List<String> options = [];
  int i = 0, score = 0;
  String? picked;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final all = <(SumExample, int)>[
      for (final e in [...widget.card.examples, ...widget.card.more])
        for (var p = 0; p < e.parts.length; p++)
          if (_roles.contains(e.parts[p].kind)) (e, p),
    ]..shuffle(_rng);
    // هەر جارەکێ رستەکا جودا و رۆلەکێ جودا (نە هەمان پرسیار ل دویف ئێک)
    final out = <(SumExample, int)>[];
    final usedEx = <SumExample>{};
    final kinds = <String, int>{};
    for (final q in all) {
      if (out.length >= _len) break;
      final k = q.$1.parts[q.$2].kind;
      if (usedEx.contains(q.$1) || (kinds[k] ?? 0) >= 2) continue;
      out.add(q);
      usedEx.add(q.$1);
      kinds[k] = (kinds[k] ?? 0) + 1;
    }
    for (final q in all) {
      if (out.length >= _len) break;
      if (!out.contains(q)) out.add(q);
    }
    qs = out;
    i = 0;
    score = 0;
    _prepare();
  }

  void _prepare() {
    picked = null;
    if (qs.isEmpty) return;
    final k = qs[i].$1.parts[qs[i].$2].kind;
    final verbish = {'V', 'V2'};
    final present = {for (final q in qs) q.$1.parts[q.$2].kind};
    final pool = {..._base, ...present}
        .where((r) => r != k && !(verbish.contains(r) && verbish.contains(k)) && A1Summary.legend[r] != null)
        .toList()
      ..shuffle(_rng);
    options = [k, ...pool.take(3)]..shuffle(_rng);
  }

  void _pick(String r) {
    if (picked != null) return;
    final k = qs[i].$1.parts[qs[i].$2].kind;
    setState(() => picked = r);
    if (r == k) {
      score++;
      Sfx.correct();
    } else {
      Sfx.wrong();
    }
  }

  void _next() => setState(() {
        if (i + 1 < qs.length) {
          i++;
          _prepare();
        } else {
          i = qs.length; // دووماهی
        }
      });

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    if (qs.isEmpty) return const SizedBox.shrink();
    final box = BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: c.color.withValues(alpha: 0.45), width: 1.5),
    );
    if (i >= qs.length) {
      final good = score >= qs.length - 1;
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: box,
        child: Column(children: [
          Text(good ? '🏆' : '💪', style: const TextStyle(fontSize: 42)),
          Text('$score ژ ${qs.length} دروست', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(good ? 'ئافەرین! تو رۆلێن پەیڤان باش دناسی.' : 'باشە! جارەکا دی تاقی بکە دا باشتر لێ بێت.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg70)),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: c.color),
            onPressed: () => setState(_start),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('دیسا راهێنان بکە'),
          ),
        ]),
      );
    }
    final (e, target) = qs[i];
    final k = e.parts[target].kind;
    final ok = picked == k;
    final right = A1Summary.legend[k]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: box,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('پرسیار ${i + 1} ژ ${qs.length}', style: TextStyle(color: c.color, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('✅ $score', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(onPressed: () => sayGerman(e.de), icon: const Icon(Icons.volume_up_rounded)),
        ]),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(spacing: 6, runSpacing: 8, children: [
            for (var p = 0; p < e.parts.length; p++) _tile(e.parts[p], p == target, c.color),
          ]),
        ),
        const SizedBox(height: 10),
        Text('پەیڤا «${e.parts[target].text}» ل ڤێرە چ کارێ دکەت؟',
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in options) _option(r, k),
        ]),
        if (picked != null) ...[
          const SizedBox(height: 10),
          Text(
            ok ? '✅ دروستە! «${e.parts[target].text}» = ${right.$1} (${right.$2})' : '❌ نە. «${e.parts[target].text}» = ${right.$1} (${right.$2})',
            style: TextStyle(color: ok ? AppColors.green : AppColors.red, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text('💬 ${e.ku}', style: TextStyle(color: AppColors.fg70, fontSize: 14.5)),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ok ? AppColors.green : c.color),
              onPressed: _next,
              child: Text(i + 1 < qs.length ? 'پرسیارا دی ←' : 'ئەنجام'),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _tile(SumPart p, bool target, Color accent) {
    if (A1Summary.legend[p.kind] == null) {
      return Padding(padding: const EdgeInsets.only(top: 6), child: Text(p.text, style: TextStyle(fontSize: 18, color: AppColors.fg60)));
    }
    final done = picked != null;
    final col = target ? (done ? A1Summary.legend[p.kind]!.$3 : AppColors.gold) : AppColors.fg24;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: target ? col.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col, width: target ? 3 : 1.5),
      ),
      child: Text(p.text,
          style: TextStyle(fontSize: 18, fontWeight: target ? FontWeight.w900 : FontWeight.w600,
              color: target ? AppColors.fg : AppColors.fg70)),
    );
  }

  Widget _option(String r, String k) {
    final l = A1Summary.legend[r]!;
    final isRight = r == k;
    final isPicked = r == picked;
    final Color border = picked == null ? l.$3 : (isRight ? AppColors.green : (isPicked ? AppColors.red : AppColors.fg24));
    return GestureDetector(
      onTap: () => _pick(r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: border.withValues(alpha: picked != null && (isRight || isPicked) ? 0.22 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(l.$2, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 11.5, color: AppColors.fg60)),
        ]),
      ),
    );
  }
}
