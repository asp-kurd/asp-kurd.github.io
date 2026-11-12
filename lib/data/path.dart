import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/progress_service.dart';
import 'curriculum.dart';

/// 🛤️ رێکا فێربوونێ (asp 2.22): ئەلفوبێ ➔ بەشا ١ (١٠ قۆناغ) ➔ بەشا ٢ (٢٢) ➔ بەشا ٣ (٣٣)
/// هەر قۆناغەک ٥–٦ وانەیە، و هەر وانەیەک ٣–٦ کۆرسە (شێوە: سێگۆشە … شەشگۆشە).
/// ناڤەرۆک ژ قۆناغێن curriculum.json دهێت؛ هەر وانەیەک ژ ئێک قۆناغا کەڤن (unit) پێکدهێت —
/// لەوما پێشکەفتنا کەڤن (completedUnits) ب خۆ وەکی وانەیێن تەمامکری دهێتە خواندن.

class PathLesson {
  final String id;
  final LessonUnit unit;
  final List<WordConcept> concepts;
  final int courses; // 3..6 ➔ شێوە
  late final PathStage stage;
  late final int index; // د ناڤ قۆناغێ دا
  PathLesson(this.id, this.unit, this.concepts, this.courses);
  bool get isAlphabet => unit.isAlphabet;
}

class PathStage {
  final String id;
  final int section; // 0 = ئەلفوبێ، 1..3
  final int no; // ژمارا قۆناغێ د بەشێ دا (1..)
  final int lektion; // 0 = ئەلفوبێ؛ 1..14 = A1؛ 15..28 = A2 (Lektion 1..14)
  final Color color;
  final List<PathLesson> lessons;
  final bool comingSoon;
  late final int gIndex; // ریزبەندی د هەمی رێکێ دا
  PathStage({
    required this.id,
    required this.section,
    required this.no,
    required this.lektion,
    required this.color,
    required this.lessons,
    this.comingSoon = false,
  });

  List<LessonUnit> get units {
    final out = <LessonUnit>[];
    for (final l in lessons) {
      if (!out.contains(l.unit)) out.add(l.unit);
    }
    return out;
  }

  String title(AppLanguage l) => units.map((u) => u.title(l)).toSet().take(2).join(' · ');
  GrammarCard? get grammar => units.map((u) => u.grammar).whereType<GrammarCard>().firstOrNull;
  LessonUnit? get grammarUnit => units.where((u) => u.grammar != null).firstOrNull;
}

class PathSection {
  final int n; // 0..3
  final String ku, de, en, level;
  final List<PathStage> stages;
  final bool comingSoon;
  PathSection(this.n, this.ku, this.de, this.en, this.level, this.stages, {this.comingSoon = false});
  String title(AppLanguage l) => switch (l) {
        AppLanguage.badini => ku,
        AppLanguage.german => de,
        AppLanguage.english => en,
      };
}

/// 🎲 هەڕەمەکیا جێگیر (هەمان ژمار ل هەمی مۆبایلان)
int seeded(String s) {
  // ژمار هەمیشە < 2^53 ➔ ل وێب و ئەندرۆید هەمان ئەنجام
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 131 + c) % 1000000007;
  }
  return h;
}

/// چەند قۆناغ بۆ هەر Lektionەکێ: { بەش: { Lektion: قۆناغ } }
const Map<int, Map<int, int>> _plan = {
  1: {1: 2, 2: 1, 3: 2, 4: 1, 5: 2, 6: 1, 7: 1}, // = 10 (A1.1)
  2: {8: 2, 9: 2, 10: 2, 11: 2, 12: 2, 13: 2, 14: 2, 15: 3, 16: 3, 17: 2}, // = 22 (A1.2 + دەستپێکا A2)
  3: {18: 3, 19: 3, 20: 3, 21: 3, 22: 3, 23: 3, 24: 3, 25: 3, 26: 3, 27: 3, 28: 3}, // = 33 (A2)
};

/// رەنگێن سروشتی بۆ قۆناغان (نە زۆر تیژ)
const _palette = <Color>[
  Color(0xFF58A55C), // کەسکێ گیای
  Color(0xFF3E8EDE), // شینێ ئەسمانی
  Color(0xFFE08A3C), // پرتەقالی
  Color(0xFF8E6CC8), // مۆری نەرم
  Color(0xFF2FA39A), // شینێ دەریایێ
  Color(0xFFD9625B), // سۆرێ هەناری
  Color(0xFFC9A227), // زەردێ گەنمی
  Color(0xFF5C7FC4), // شینێ ئێڤاری
  Color(0xFF7FA650), // کەسکێ زەیتوونی
  Color(0xFFCB6F9E), // پەمەیی
  Color(0xFF4F9FC0), // شینێ ئاڤێ
  Color(0xFFB7794A), // قاوەیی
];

String? _cacheKey;
List<PathSection> _sections = [];
List<PathStage> _stages = [];
List<PathLesson> _lessons = [];
Map<String, PathLesson> _byId = {};

List<PathSection> get pathSections => _build();
List<PathStage> get pathStages {
  _build();
  return _stages;
}

List<PathLesson> get pathLessons {
  _build();
  return _lessons;
}

PathLesson? pathLessonById(String id) {
  _build();
  return _byId[id];
}

List<PathSection> _build() {
  final units = appCurriculum;
  final key = '${ProgressService.instance.targetLang.code}#${identityHashCode(units)}#${units.length}';
  if (key == _cacheKey) return _sections;
  _cacheKey = key;
  final target = ProgressService.instance.targetLang;

  // ── ئەلفوبێ ──
  final alpha = units.where((u) => u.section == 1).toList();
  final alphaStages = <PathStage>[];
  if (alpha.isNotEmpty) {
    final groups = <List<LessonUnit>>[];
    final letters = alpha.where((u) => u.isAlphabet).toList();
    final sounds = alpha.where((u) => !u.isAlphabet).toList();
    if (letters.isNotEmpty) groups.add(letters);
    if (sounds.isNotEmpty) groups.add(sounds);
    for (var g = 0; g < groups.length; g++) {
      alphaStages.add(PathStage(
        id: 'st0_${g + 1}',
        section: 0,
        no: g + 1,
        lektion: 0,
        color: g == 0 ? const Color(0xFF4FA3D9) : const Color(0xFF9B7BD4),
        lessons: [for (final u in groups[g]) PathLesson('${u.id}@a', u, u.concepts, 3)],
      ));
    }
  }

  // ── Lektion ➔ پەیڤ (ب ریز) ──
  final byLek = <int, List<(LessonUnit, WordConcept)>>{};
  for (final u in units) {
    if (u.section < 2) continue;
    final lek = u.section - 1;
    (byLek[lek] ??= []).addAll(u.concepts.map((c) => (u, c)));
  }

  final secs = <PathSection>[];
  if (alphaStages.isNotEmpty) {
    secs.add(PathSection(0, 'دەستپێک · ئەلفوبێ', 'Start · Alphabet', 'Start · Alphabet', 'ABC', alphaStages));
  }
  var colorIdx = 0;
  for (final s in [1, 2, 3]) {
    final stages = <PathStage>[];
    var no = 0;
    final plan = _plan[s]!;
    var soon = false;
    for (final e in plan.entries) {
      final items = byLek[e.key];
      if (items == null || items.isEmpty) {
        // ناڤەرۆک هێشتا نینە (بۆ نموونە A2 بۆ ئینگلیزی) ➔ «🔒 زوو»
        soon = true;
        continue;
      }
      final parts = _split(items, e.value);
      for (final part in parts) {
        no++;
        final color = _palette[colorIdx++ % _palette.length];
        final sid = 'st${s}_${e.key}_${parts.indexOf(part) + 1}';
        stages.add(PathStage(
          id: sid,
          section: s,
          no: no,
          lektion: e.key,
          color: color,
          lessons: _lessonsFor(sid, part),
        ));
      }
    }
    final (ku, de, en, level) = switch (s) {
      1 => ('بەشا ١ · بنگەه', 'Teil 1 · Grundlagen', 'Section 1 · Basics', 'A1.1'),
      2 => ('بەشا ٢ · پێشکەفتن', 'Teil 2 · Weiter geht’s', 'Section 2 · Moving on', 'A1.2 · A2'),
      _ => ('بەشا ٣ · ئاستێ A2', 'Teil 3 · Niveau A2', 'Section 3 · Level A2', 'A2'),
    };
    secs.add(PathSection(s, ku, de, en, level, stages,
        comingSoon: stages.isEmpty || (s == 3 && target == AppLanguage.english) || (soon && stages.isEmpty)));
  }

  _sections = secs;
  _stages = [];
  _lessons = [];
  _byId = {};
  for (final sec in secs) {
    if (sec.comingSoon) continue;
    for (final st in sec.stages) {
      st.gIndex = _stages.length;
      _stages.add(st);
      for (var i = 0; i < st.lessons.length; i++) {
        final l = st.lessons[i];
        l.stage = st;
        l.index = i;
        _lessons.add(l);
        _byId[l.id] = l;
      }
    }
  }
  return _sections;
}

/// پەیڤێن Lektionەکێ ب [k] پشکان دابەش دکەت — هەولددەت ل سەر سنوورێ قۆناغێن کەڤن ببڕیت
List<List<(LessonUnit, WordConcept)>> _split(List<(LessonUnit, WordConcept)> items, int k) {
  if (k <= 1) return [items];
  final n = items.length;
  final cuts = <int>[0];
  for (var i = 1; i < k; i++) {
    var c = (i * n / k).round();
    // نێزیکی سنوورێ unitێ؟ ➔ ل وێرێ ببڕە
    for (var d = 0; d <= 1; d++) {
      if (c - d > cuts.last && c - d < n && items[c - d].$1 != items[c - d - 1].$1) {
        c = c - d;
        break;
      }
      if (c + d < n && c + d > cuts.last && items[c + d].$1 != items[c + d - 1].$1) {
        c = c + d;
        break;
      }
    }
    cuts.add(c);
  }
  cuts.add(n);
  return [for (var i = 0; i < k; i++) items.sublist(cuts[i], cuts[i + 1])];
}

List<PathLesson> _lessonsFor(String sid, List<(LessonUnit, WordConcept)> part) {
  // پشکێن ئێک unit
  final chunks = <(LessonUnit, List<WordConcept>)>[];
  for (final (u, c) in part) {
    if (chunks.isEmpty || chunks.last.$1 != u) chunks.add((u, []));
    chunks.last.$2.add(c);
  }
  var want = 5 + seeded(sid) % 2; // ٥ یان ٦
  // هەر وانەیەک ب کێمی ٢ پەیڤ — بەلێ قۆناغ هەردەم ٥+ وانە (ئەگەر پەیڤ هەبن)
  final hi = max(chunks.length, max((part.length + 1) ~/ 2, min(5, part.length)));
  want = want.clamp(chunks.length, hi);
  // دابەشکرنا وانەیان ل سەر پشکان (ب قەدەرێ)
  final alloc = [for (final _ in chunks) 1];
  var left = want - chunks.length;
  while (left > 0) {
    var best = 0;
    var bestScore = -1.0;
    for (var i = 0; i < chunks.length; i++) {
      final score = chunks[i].$2.length / (alloc[i] + 1);
      if (alloc[i] < chunks[i].$2.length && score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    if (bestScore < 0) break;
    alloc[best]++;
    left--;
  }
  final out = <PathLesson>[];
  for (var i = 0; i < chunks.length; i++) {
    final (u, cs) = chunks[i];
    final m = alloc[i];
    for (var j = 0; j < m; j++) {
      final a = (j * cs.length / m).round(), b = ((j + 1) * cs.length / m).round();
      final sub = cs.sublist(a, b);
      if (sub.isEmpty) continue;
      final id = '${u.id}@${sub.first.id}';
      out.add(PathLesson(id, u, sub, 3 + seeded(id) % 4));
    }
  }
  return out;
}

/// پەیڤێن کۆرسێ [c] ژ وانەیا [l]: کۆرسا ئێکێ = پەیڤێن نوو؛ پاشان تێکەل دگەل دووبارەکرنێ
List<WordConcept> courseConcepts(PathLesson l, int c, {bool hard = false}) {
  final review = <WordConcept>[
    for (final x in l.stage.lessons.take(l.index)) ...x.concepts,
    if (l.stage.gIndex > 0 && l.index < 2) ...pathStages[l.stage.gIndex - 1].lessons.last.concepts,
  ]..shuffle();
  final fresh = [...l.concepts];
  final extra = hard ? 6 : (c == 0 ? (3 - fresh.length).clamp(0, 3) : (c == 1 ? 2 : 4));
  final out = [...fresh, ...review.where((r) => !fresh.contains(r)).take(extra)];
  // هێشتا کێمە؟ ژ وانەیێن دی یێن ڤێ قۆناغێ
  if (out.length < 4) {
    for (final x in l.stage.lessons) {
      for (final w in x.concepts) {
        if (out.length >= 4) break;
        if (!out.contains(w)) out.add(w);
      }
    }
  }
  return out;
}
