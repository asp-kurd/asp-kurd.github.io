import 'dart:math';

import 'book.dart';
import 'exams.dart';

/// 🏋️ راهێنان بۆ هەر بەشەکێ رێزمانێ (پەرتووکا «Deutsch mit Poya») — ژ ناڤەرۆکا بەشی ب خۆ:
///  - خشتە: ئەلمانی ⇄ بادینی (رامان)، و فۆرم (ich + helfen ➔ helfe · نێر + Akkusativ ➔ den Tisch)
///  - لیست: «German — بادینی»
///  - راهێنانێن جهێ ڤالا (quiz) و ئارتیکل (der/die/das)

const _lri = '⁦', _pdi = '⁩';
final _ar = RegExp('[؀-ۿ]');
final _lat = RegExp('[A-Za-zÄÖÜäöüß]');

String _clean(String s) => s.replaceAll('**', '').replaceAll(RegExp(r'\s+'), ' ').trim();
String _ltr(String s) => '$_lri$s$_pdi';
bool _isK(String s) => _ar.hasMatch(s);
bool _isG(String s) => _lat.hasMatch(s) && !_ar.hasMatch(s);

/// جۆرێ ستوونێ: G ئەلمانی · K بادینی · ? تێکەل
String _kind(List<List<String>> rows, int c) {
  final cells = [for (final r in rows) if (c < r.length) r[c]];
  if (cells.isEmpty) return '?';
  final k = cells.where(_isK).length, g = cells.where(_isG).length;
  if (k * 2 > cells.length) return 'K';
  if (g * 2 > cells.length) return 'G';
  return '?';
}

ExamQuestion? _choice(String q, String correct, Iterable<String> pool, Random r, {String explain = ''}) {
  final others = pool.map(_clean).where((x) => x.isNotEmpty && x != correct).toSet().toList()..shuffle(r);
  if (others.length < 2) return null;
  final opts = [correct, ...others.take(min(3, others.length))]..shuffle(r);
  return ExamQuestion(type: QType.choice, q: q, options: opts, answer: opts.indexOf(correct), explain: explain);
}

/// پرسیارێن بەشەکێ (هەتا [count])؛ جۆرێن جودا ب نۆرە
List<ExamQuestion> bookPractice(BookChapter ch, {int count = 8, int? seed}) {
  final r = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
  final meaning = <ExamQuestion>[], forms = <ExamQuestion>[], blanks = <ExamQuestion>[], arts = <ExamQuestion>[];

  void pair(String g, String k, List<String> gPool, List<String> kPool) {
    g = _clean(g);
    k = _clean(k);
    if (g.isEmpty || k.isEmpty || g.length > 70 || k.length > 70) return;
    if (r.nextInt(3) == 0) {
      final q = _choice('$k\nب ئەلمانی چییە؟', g, gPool, r, explain: '$g = $k');
      if (q != null) meaning.add(q);
    } else {
      final q = _choice('${_ltr(g)}\nرامانا وێ چییە؟', k, kPool, r, explain: '$g = $k');
      if (q != null) meaning.add(q);
    }
  }

  for (final b in ch.blocks) {
    switch (b.type) {
      case 'table':
        final rows = b.rows.where((x) => x.length == b.head.length).toList();
        if (rows.length < 3) break;
        final kinds = [for (var c = 0; c < b.head.length; c++) _kind(rows, c)];
        // ١) ئەلمانی ➔ بادینی (ستوونا پشتی وێ)
        for (var c = 0; c + 1 < kinds.length; c++) {
          if (kinds[c] != 'G' || kinds[c + 1] != 'K') continue;
          if (b.head[c + 1].contains('دەنگ')) continue; // دەنگ نە رامانە
          final gPool = [for (final x in rows) x[c]], kPool = [for (final x in rows) x[c + 1]];
          for (final x in rows) {
            if (_isG(x[c]) && _isK(x[c + 1])) pair(x[c], x[c + 1], gPool, kPool);
          }
        }
        // ٢) فۆرم: ستوونێن ئەلمانی یێن کورت (نە ستوونا ئێکێ)
        final formCols = [for (var c = 1; c < kinds.length; c++) if (kinds[c] == 'G') c];
        if (formCols.length >= 2) {
          // سەرێن ستوونان کەس/حالەت (ich، du، Akkusativ …) ➔ هەلبژارتن ژ هەمان ریزێ؛ یان نە ➔ ژ هەمان ستوونێ
          final byRow = formCols.every((c) => _lat.hasMatch(b.head[c]));
          for (final x in rows) {
            final label = _clean(x[0]);
            if (label.isEmpty || label.length > 30) continue;
            for (final c in formCols) {
              final cell = _clean(x[c]);
              if (cell.isEmpty || cell.length > 32 || !_isG(cell)) continue;
              final pool = [if (byRow) for (final cc in formCols) x[cc], for (final y in rows) y[c]];
              final head = _clean(b.head[c]);
              final q = _choice('${_isK(label) ? label : _ltr(label)}  ·  ${_isK(head) ? head : _ltr(head)}\nفۆرما دروست کیژە؟', cell, pool, r,
                  explain: '$label · $head ➔ $cell');
              if (q != null) forms.add(q);
            }
          }
        }
      case 'ul' || 'ol':
        final pairs = <(String, String)>[];
        for (final it in b.items) {
          final p = it.split(' — ');
          if (p.length == 2 && _isG(_clean(p[0])) && _isK(p[1])) pairs.add((p[0], p[1]));
        }
        if (pairs.length >= 3) {
          for (final p in pairs) {
            pair(p.$1, p.$2, [for (final x in pairs) x.$1], [for (final x in pairs) x.$2]);
          }
        }
      case 'quiz':
        final answers = [for (final it in b.quiz) it.a];
        for (final it in b.quiz) {
          // «(habe / bin)» د پرسیارێ دا ➔ ئەو هەلبژارتن
          final inline = RegExp(r'\(([^)]*/[^)]*)\)').firstMatch(it.q);
          final pool = inline != null ? inline.group(1)!.split('/').map((s) => s.trim()) : answers;
          final q = _choice('${_ltr(it.q.replaceAll(RegExp(r'_{3,}'), '_____'))}\nجهێ ڤالا پڕ بکە', _clean(it.a), pool, r,
              explain: it.a);
          if (q != null) blanks.add(q);
        }
      case 'vocab':
        for (final x in b.rows) {
          if (x.length < 2) continue;
          final m = RegExp(r'^(der|die|das)\s+(.+)$').firstMatch(_clean(x[0]));
          if (m == null) continue;
          const opts = ['der', 'die', 'das'];
          arts.add(ExamQuestion(
            type: QType.choice,
            q: '${_ltr(m.group(2)!)}  (${_clean(x[1])})\nئارتیکلێ وێ چییە؟',
            options: opts,
            answer: opts.indexOf(m.group(1)!),
            explain: '${m.group(1)} ${m.group(2)} = ${_clean(x[1])}',
          ));
        }
    }
  }
  final groups = [meaning, forms, blanks, arts].where((g) => g.isNotEmpty).toList();
  for (final g in groups) {
    g.shuffle(r);
  }
  // ب نۆرە ژ هەر جۆرەکی
  final out = <ExamQuestion>[];
  var i = 0;
  while (out.length < count && groups.any((g) => g.length > i ~/ groups.length)) {
    final g = groups[i % groups.length];
    final k = i ~/ groups.length;
    if (k < g.length) out.add(g[k]);
    i++;
    if (i > 400) break;
  }
  return out;
}
