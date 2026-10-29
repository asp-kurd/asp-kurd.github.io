import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/curriculum.dart';
import '../../models.dart';
import '../../services/progress_service.dart';
import '../../services/sfx.dart';
import '../../services/voice_service.dart';
import '../../ui.dart';
import 'game_items.dart';
import 'game_kind.dart';

/// هاریکارێن دەقی بۆ یاریان
class GameSessionHelpers {
  static final articles = RegExp(r'^(der|die|das|the|a|an)\s+', caseSensitive: false);
  static List<String> words(String s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  static String clean(String w) => w.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  /// پەیڤا بۆ Word Search: بێ ئارتیکل، ئێک پەیڤ، تنێ پیت
  static String? searchWord(WordConcept c, AppLanguage l) {
    final t = c.text(l).replaceFirst(articles, '').trim();
    if (t.contains(' ')) return null;
    final w = clean(t).toUpperCase();
    return (w.length >= 3 && w.length <= 9) ? w : null;
  }
}

/// ئێک پرسیار / قۆناغ د ناڤ یاریەکێ دا
class GameItem {
  final GameKind kind;
  final List<WordConcept> words; // match/search: چەند پەیڤ؛ یێن دی: ئێک
  final List<WordConcept> choices; // pick: ٤ وێنە
  final int blank; // finish: کیژ پەیڤ ڤەشارتییە
  final List<String> options; // finish: پەیڤێن هەلبژارتنێ
  const GameItem(this.kind, this.words, {this.choices = const [], this.blank = -1, this.options = const []});
  WordConcept get word => words.first;
}

/// 🎮 دانیشتنا یاریێ: ٦–١٠ پرسیار ➔ ستێر + XP
/// [kind] == null ➔ تێکەل (بۆ دووبارەکرنا ب دەم و پەیڤێن خەلەت)
class GameSessionScreen extends StatefulWidget {
  final GameKind? kind;
  final List<WordConcept> concepts;
  final LessonUnit? unit;
  const GameSessionScreen({super.key, required this.kind, required this.concepts, this.unit});

  @override
  State<GameSessionScreen> createState() => _GameSessionScreenState();
}

class _GameSessionScreenState extends State<GameSessionScreen> {
  final p = ProgressService.instance;
  final voice = VoiceService.instance;
  final rng = Random();
  final watch = Stopwatch()..start();

  late final AppLanguage native = p.nativeLang;
  late final AppLanguage target = p.targetLang;
  late List<GameItem> items;
  int index = 0;
  int correct = 0;
  int mistakes = 0;
  bool done = false; // پرسیارا نوکە تەمام بوو
  bool lastOk = true;
  String? answerText;
  final Set<String> _wrongIds = {};

  @override
  void initState() {
    super.initState();
    items = buildItems();
  }

  @override
  void dispose() {
    voice.stopPlayback();
    p.addStudyTime(watch.elapsed);
    super.dispose();
  }

  // ───────── دروستکرنا پرسیاران ─────────
  static List<String> words(String s) => GameSessionHelpers.words(s);
  static String clean(String w) => GameSessionHelpers.clean(w);

  List<GameItem> buildItems() {
    final cs = [...widget.concepts]..shuffle(rng);
    final k = widget.kind;
    if (k == null) {
      // تێکەل: وێنە ➔ نڤیسین ➔ گوهداری
      final out = <GameItem>[];
      for (var i = 0; i < cs.length && i < 10; i++) {
        final c = cs[i];
        final cycle = [GameKind.pickPicture, GameKind.typeWord, GameKind.dictation];
        var kind = cycle[i % cycle.length];
        if (kind == GameKind.dictation && !voice.canSpeak(c, target)) kind = GameKind.typeWord;
        out.add(kind == GameKind.pickPicture ? _pickItem(c, cs) : GameItem(kind, [c]));
      }
      return out;
    }
    switch (k) {
      case GameKind.pickPicture:
        return [for (final c in cs.take(10)) _pickItem(c, cs)];
      case GameKind.matchPairs:
        final pool = _distinctPics(cs);
        final out = <GameItem>[];
        for (var i = 0; i < pool.length; i += 4) {
          final chunk = pool.sublist(i, min(i + 4, pool.length));
          if (chunk.length < 2 && out.isNotEmpty) {
            out.last.words.addAll(chunk);
          } else {
            out.add(GameItem(k, [...chunk]));
          }
        }
        return out;
      case GameKind.typeWord:
        return [for (final c in cs.take(10)) GameItem(k, [c])];
      case GameKind.dictation:
        final ok = cs.where((c) => voice.canSpeak(c, target)).take(10).toList();
        return [for (final c in (ok.isEmpty ? cs.take(10) : ok)) GameItem(ok.isEmpty ? GameKind.typeWord : k, [c])];
      case GameKind.finishSentence:
        return _finishItems(cs);
      case GameKind.wordSearch:
        return _searchItems(cs);
      case GameKind.shadowing:
        return [for (final c in cs.take(8)) GameItem(k, [c])];
    }
  }

  List<WordConcept> _distinctPics(List<WordConcept> cs) {
    final seen = <String>{};
    return [for (final c in cs) if (seen.add(c.pic)) c];
  }

  GameItem _pickItem(WordConcept c, List<WordConcept> local) {
    final pics = <String>{c.pic};
    final distract = <WordConcept>[];
    for (final pool in [local, [...allConcepts]..shuffle(rng)]) {
      for (final d in pool) {
        if (distract.length >= 3) break;
        if (d.id != c.id && d.emoji.isNotEmpty && pics.add(d.pic)) distract.add(d);
      }
    }
    final choices = [c, ...distract]..shuffle(rng);
    return GameItem(GameKind.pickPicture, [c], choices: choices);
  }

  List<GameItem> _finishItems(List<WordConcept> cs) {
    bool usable(WordConcept c) => words(c.text(target)).length >= 2;
    final pool = cs.where(usable).toList();
    if (pool.length < 5) {
      final extra = allConcepts.where((c) => usable(c) && !pool.contains(c)).toList()..shuffle(rng);
      pool.addAll(extra.take(6 - pool.length));
    }
    final allWords = {
      for (final c in allConcepts)
        for (final w in words(c.text(target)))
          if (clean(w).length >= 3) clean(w),
    }.toList();
    final out = <GameItem>[];
    for (final c in pool.take(8)) {
      final ws = words(c.text(target));
      int blank;
      List<String> opts;
      final first = clean(ws.first).toLowerCase();
      if (ws.length == 2 && const ['der', 'die', 'das'].contains(first)) {
        blank = 0;
        opts = ['der', 'die', 'das'];
      } else {
        final cand = [for (var i = 0; i < ws.length; i++) if (clean(ws[i]).length >= 3) i];
        blank = cand.isEmpty ? ws.length - 1 : cand[rng.nextInt(cand.length)];
        final right = clean(ws[blank]);
        final upper = right.isNotEmpty && right[0] == right[0].toUpperCase();
        final d = (allWords.where((w) => w.toLowerCase() != right.toLowerCase() && (w[0] == w[0].toUpperCase()) == upper).toList()
              ..shuffle(rng))
            .take(3);
        opts = [right, ...d];
      }
      opts.shuffle(rng);
      out.add(GameItem(GameKind.finishSentence, [c], blank: blank, options: opts));
    }
    return out;
  }

  List<GameItem> _searchItems(List<WordConcept> cs) {
    final pool = <WordConcept>[];
    final seen = <String>{};
    for (final c in cs) {
      final w = GameSessionHelpers.searchWord(c, target);
      if (w != null && seen.add(w)) pool.add(c);
    }
    if (pool.length < 5) {
      final extra = allConcepts.where((c) => GameSessionHelpers.searchWord(c, target) != null).toList()..shuffle(rng);
      for (final c in extra) {
        if (pool.length >= 6) break;
        if (seen.add(GameSessionHelpers.searchWord(c, target)!)) pool.add(c);
      }
    }
    final out = <GameItem>[];
    for (var i = 0; i < pool.length; i += 6) {
      out.add(GameItem(GameKind.wordSearch, pool.sublist(i, min(i + 6, pool.length))));
    }
    return out;
  }

  // ───────── بەرسڤ ─────────
  Future<void> onAnswer(WordConcept c, bool ok) async {
    if (ok) {
      correct++;
      Sfx.correct();
      await p.clearMistake(c.id);
    } else {
      mistakes++;
      _wrongIds.add(c.id);
      Sfx.wrong();
      await p.recordMistake(c.id);
    }
    await p.recordAnswer(c.id, ok);
    if (mounted) setState(() {});
  }

  void onComplete({required bool ok, String? answer}) {
    if (!mounted) return;
    setState(() {
      done = true;
      lastOk = ok;
      answerText = answer;
    });
  }

  Future<void> next() async {
    if (index + 1 < items.length) {
      setState(() {
        index++;
        done = false;
        answerText = null;
      });
      return;
    }
    await finish();
  }

  Future<void> finish() async {
    final stars = starsForMistakes(mistakes);
    final xp = 5 + correct * 2;
    await p.earn(xp);
    if (widget.kind != null && widget.unit != null) await p.setStars(widget.kind!.id, widget.unit!.id, stars);
    Sfx.done();
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultScreen(
          kind: widget.kind,
          unit: widget.unit,
          concepts: widget.concepts,
          stars: stars,
          xp: xp,
          correct: correct,
          wrong: mistakes,
        ),
      ),
    );
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(tr(native, 'پەیڤ بۆ ڤێ یاریێ نینن', 'Keine Wörter für dieses Spiel', 'No words for this game'))),
      );
    }
    final item = items[index];
    final color = (widget.kind ?? item.kind).color;
    return Directionality(
      textDirection: native.direction,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
          title: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (index + (done ? 1 : 0)) / items.length,
              minHeight: 12,
              backgroundColor: AppColors.card,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Icon(Icons.check_circle, color: AppColors.green, size: 20),
                Text(' $correct  ', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                const Icon(Icons.cancel, color: AppColors.red, size: 20),
                Text(' $mistakes', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${item.kind.emoji}  ${item.kind.title(native)}',
                  style: TextStyle(fontSize: 17, color: item.kind.color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: GameItemView(
                  key: ValueKey(index),
                  item: item,
                  native: native,
                  target: target,
                  onAnswer: onAnswer,
                  onComplete: onComplete,
                ),
              ),
              if (done) ...[
                _feedback(item),
                BigButton(
                  label: tr(native, 'بەردەوام بە', 'Weiter', 'CONTINUE'),
                  color: lastOk ? AppColors.green : AppColors.orange,
                  onPressed: next,
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _feedback(GameItem item) {
    final c = lastOk ? AppColors.green : AppColors.orange;
    final msg = lastOk
        ? tr(native, 'دەستخۆش! 🎉', 'Super! 🎉', 'Great! 🎉')
        : tr(native, 'ئاریشە نینە — جارا بێت 💪', 'Kein Problem — nächstes Mal 💪', 'No problem — next time 💪');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(msg, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16)),
        if (answerText != null) ...[
          const SizedBox(height: 4),
          Text(answerText!, textDirection: target.direction, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(item.word.text(native), textDirection: native.direction, style: const TextStyle(color: Colors.white60)),
        ],
      ]),
    );
  }
}

/// 🏆 ئەنجام: ستێر + XP
class GameResultScreen extends StatefulWidget {
  final GameKind? kind;
  final LessonUnit? unit;
  final List<WordConcept> concepts;
  final int stars, xp, correct, wrong;
  const GameResultScreen({
    super.key,
    required this.kind,
    required this.unit,
    required this.concepts,
    required this.stars,
    required this.xp,
    required this.correct,
    required this.wrong,
  });

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen> {
  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.stars; i++) {
      Future.delayed(Duration(milliseconds: 700 + i * 350), () {
        if (mounted) Sfx.star();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = ProgressService.instance.nativeLang;
    final total = widget.correct + widget.wrong;
    final pct = total == 0 ? 100 : (widget.correct * 100 / total).round();
    return Directionality(
      textDirection: n.direction,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              Text(widget.stars == 3 ? '🏆' : (widget.stars == 2 ? '🎉' : '👏'), style: const TextStyle(fontSize: 84)),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 3; i++)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 500 + i * 350),
                    curve: Curves.elasticOut,
                    builder: (_, v, __) => Transform.scale(
                      scale: i < widget.stars ? v : 1,
                      child: Icon(Icons.star_rounded,
                          size: i == 1 ? 76 : 60, color: i < widget.stars ? AppColors.gold : Colors.white24),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              Text(
                widget.stars == 3
                    ? tr(n, 'بێ خەلەتی! تو قارەمانی', 'Fehlerfrei!', 'Flawless!')
                    : tr(n, 'یاری تەمام بوو!', 'Geschafft!', 'Round complete!'),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _pill(Icons.bolt, AppColors.gold, '+${widget.xp} XP'),
                const SizedBox(width: 10),
                _pill(Icons.gps_fixed_rounded, AppColors.blue, '$pct%'),
                const SizedBox(width: 10),
                _pill(Icons.check_circle, AppColors.green, '${widget.correct}'),
                const SizedBox(width: 10),
                _pill(Icons.cancel, AppColors.red, '${widget.wrong}'),
              ]),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: BigButton(
                  label: tr(n, 'دیسا یاری بکە', 'Nochmal', 'Play again'),
                  color: AppColors.blue,
                  icon: Icons.replay_rounded,
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GameSessionScreen(kind: widget.kind, concepts: widget.concepts, unit: widget.unit)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: BigButton(label: tr(n, 'بەردەوام بە', 'Weiter', 'CONTINUE'), onPressed: () => Navigator.pop(context)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData i, Color c, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, color: c, size: 20),
          const SizedBox(width: 4),
          Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      );
}
