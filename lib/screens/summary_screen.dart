import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  const SumCard(this.id, this.emoji, this.color, this.title, this.de, this.rules, this.head, this.rows, this.examples, this.tip);
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
            (c['examples'] as List)
                .map((e) => SumExample(e['de'] as String, e['ku'] as String,
                    (e['parts'] as List).map((p) => SumPart((p as List)[0] as String, p[1] as String)).toList()))
                .toList(),
            c['tip'] as String?,
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
          title: Text('${i + 1} / ${cards.length}'),
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

  Widget _example(SumCard c, int k) {
    final e = c.examples[k];
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
            for (var p = 0; p < e.parts.length; p++) _chip(e.parts[p], '${c.id}/$k/$p'),
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


