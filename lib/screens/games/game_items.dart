import 'dart:math';

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/progress_service.dart';
import '../../services/voice_service.dart';
import '../../ui.dart';
import '../widgets/record_button.dart';
import 'game_kind.dart';
import 'game_session.dart';

typedef AnswerFn = Future<void> Function(WordConcept c, bool ok);
typedef CompleteFn = void Function({required bool ok, String? answer});

/// هەر پرسیارەک ل دویڤ جۆرێ یاریێ
class GameItemView extends StatelessWidget {
  final GameItem item;
  final AppLanguage native, target;
  final AnswerFn onAnswer;
  final CompleteFn onComplete;
  const GameItemView({
    super.key,
    required this.item,
    required this.native,
    required this.target,
    required this.onAnswer,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return switch (item.kind) {
      GameKind.pickPicture => _PickPicture(this),
      GameKind.matchPairs => _MatchPairs(this),
      GameKind.typeWord => _TypeWord(this, dictation: false),
      GameKind.dictation => _TypeWord(this, dictation: true),
      GameKind.finishSentence => _FinishSentence(this),
      GameKind.wordSearch => _WordSearch(this),
      GameKind.shadowing => _Shadowing(this),
    };
  }
}

// ───────── هاریکار ─────────
Widget bigPic(String pic, {double size = 92}) => Container(
      width: size * 1.5,
      height: size * 1.5,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFF253740), borderRadius: BorderRadius.circular(size * 0.35)),
      child: Text(pic, style: TextStyle(fontSize: size)),
    );

Widget soundBtn(VoidCallback onTap, {IconData icon = Icons.volume_up_rounded, double size = 56, Color color = AppColors.blue}) =>
    InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );

void say(WordConcept c, AppLanguage l, {double rate = 1.0}) => VoiceService.instance.speak(c, l, rate: rate);

// ───────── 🖼️ وێنەیی هەلبژێرە ─────────
class _PickPicture extends StatefulWidget {
  final GameItemView g;
  const _PickPicture(this.g);
  @override
  State<_PickPicture> createState() => _PickPictureState();
}

class _PickPictureState extends State<_PickPicture> {
  String? picked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => say(widget.g.item.word, widget.g.target));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final c = g.item.word;
    return Column(children: [
      Text(c.text(g.target),
          textDirection: g.target.direction,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      soundBtn(() => say(c, g.target)),
      const SizedBox(height: 18),
      Expanded(
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          children: [
            for (final o in g.item.choices)
              GestureDetector(
                onTap: picked != null
                    ? null
                    : () async {
                        setState(() => picked = o.id);
                        final ok = o.id == c.id;
                        await g.onAnswer(c, ok);
                        g.onComplete(ok: ok, answer: '${c.pic}  ${c.text(g.target)}');
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _bg(o, c),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _border(o, c), width: 3),
                  ),
                  child: Text(o.pic, style: const TextStyle(fontSize: 64)),
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Color _border(WordConcept o, WordConcept c) {
    if (picked == null) return Colors.white12;
    if (o.id == c.id) return AppColors.green;
    if (o.id == picked) return AppColors.red;
    return Colors.white12;
  }

  Color _bg(WordConcept o, WordConcept c) {
    final b = _border(o, c);
    return b == Colors.white12 ? AppColors.card : b.withValues(alpha: 0.18);
  }
}

// ───────── 🧩 جووتان بدۆزە ─────────
class _MatchPairs extends StatefulWidget {
  final GameItemView g;
  const _MatchPairs(this.g);
  @override
  State<_MatchPairs> createState() => _MatchPairsState();
}

class _MatchPairsState extends State<_MatchPairs> {
  late final List<WordConcept> left = [...widget.g.item.words]..shuffle();
  late final List<WordConcept> right = [...widget.g.item.words]..shuffle();
  WordConcept? selL, selR;
  final matched = <String>{};
  final missed = <String>{};
  String? wrong;
  bool anyMistake = false;

  Future<void> _try() async {
    final l = selL, r = selR;
    if (l == null || r == null) return;
    final g = widget.g;
    if (l.id == r.id || l.pic == r.pic) {
      setState(() {
        matched..add(l.id)..add(r.id);
        selL = selR = null;
      });
      if (!missed.contains(l.id)) await g.onAnswer(l, true);
      if (matched.length >= left.length * 2 || left.every((c) => matched.contains(c.id))) {
        g.onComplete(ok: !anyMistake);
      }
    } else {
      setState(() {
        wrong = '${l.id}|${r.id}';
        anyMistake = true;
      });
      if (missed.add(l.id)) await g.onAnswer(l, false);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        wrong = null;
        selL = selR = null;
      });
    }
  }

  Widget _card(WordConcept c, bool isLeft) {
    final g = widget.g;
    final done = matched.contains(c.id);
    final sel = isLeft ? selL?.id == c.id : selR?.id == c.id;
    final bad = wrong != null && wrong!.split('|')[isLeft ? 0 : 1] == c.id;
    final color = done ? AppColors.green : (bad ? AppColors.red : (sel ? g.item.kind.color : Colors.white12));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: done
            ? null
            : () {
                setState(() {
                  if (isLeft) {
                    selL = c;
                  } else {
                    selR = c;
                  }
                });
                if (!isLeft) say(c, g.target);
                _try();
              },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: done ? 0.35 : 1,
          child: Container(
            height: 84,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: color == Colors.white12 ? AppColors.card : color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color, width: 2.5),
            ),
            child: isLeft
                ? Text(c.pic, style: const TextStyle(fontSize: 44))
                : Text(c.text(g.target),
                    textAlign: TextAlign.center,
                    textDirection: g.target.direction,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: [for (final c in left) _card(c, true)])),
        const SizedBox(width: 14),
        Expanded(child: Column(children: [for (final c in right) _card(c, false)])),
      ]),
    );
  }
}

// ───────── ⌨️ پەیڤێ بنڤیسە / 🎧 دیکتە ─────────
String normAnswer(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class _TypeWord extends StatefulWidget {
  final GameItemView g;
  final bool dictation;
  const _TypeWord(this.g, {required this.dictation});
  @override
  State<_TypeWord> createState() => _TypeWordState();
}

class _TypeWordState extends State<_TypeWord> {
  final ctrl = TextEditingController();
  final focus = FocusNode();
  bool? result;

  String get answer => widget.g.item.word.text(widget.g.target);

  @override
  void initState() {
    super.initState();
    if (widget.dictation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => say(widget.g.item.word, widget.g.target));
    }
  }

  @override
  void dispose() {
    ctrl.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (result != null || ctrl.text.trim().isEmpty) return;
    final input = normAnswer(ctrl.text);
    final full = normAnswer(answer);
    final noArticle = normAnswer(answer.replaceFirst(RegExp(r'^(der|die|das|the|a|an)\s+', caseSensitive: false), ''));
    final ok = input == full || input == noArticle;
    setState(() => result = ok);
    focus.unfocus();
    await widget.g.onAnswer(widget.g.item.word, ok);
    say(widget.g.item.word, widget.g.target);
    widget.g.onComplete(ok: ok, answer: answer);
  }

  void _hint() {
    final a = answer;
    final t = ctrl.text;
    var i = 0;
    while (i < t.length && i < a.length && t[i].toLowerCase() == a[i].toLowerCase()) {
      i++;
    }
    final next = min(i + 1, a.length);
    ctrl.text = a.substring(0, next);
    ctrl.selection = TextSelection.collapsed(offset: next);
    focus.requestFocus();
  }

  void _insert(String ch) {
    final sel = ctrl.selection;
    final t = ctrl.text;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    ctrl.text = t.replaceRange(start, end, ch);
    ctrl.selection = TextSelection.collapsed(offset: start + ch.length);
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final c = g.item.word;
    final pale = ProgressService.instance.paleLetters && !widget.dictation;
    final color = result == null ? g.item.kind.color : (result! ? AppColors.green : AppColors.red);
    return SingleChildScrollView(
      child: Column(children: [
        if (widget.dictation) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            soundBtn(() => say(c, g.target), size: 84, color: g.item.kind.color),
            const SizedBox(width: 18),
            soundBtn(() => say(c, g.target, rate: 0.65), icon: Icons.slow_motion_video_rounded, size: 60, color: g.item.kind.color),
          ]),
          const SizedBox(height: 14),
          Text(tr(g.native, 'تشتێ تو دبهیسی بنڤیسە', 'Schreib, was du hörst', 'Type what you hear'),
              style: const TextStyle(color: Colors.white60)),
        ] else ...[
          bigPic(c.pic, size: 72),
          const SizedBox(height: 12),
          Text(c.text(g.native),
              textDirection: g.native.direction, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: ctrl,
          focusNode: focus,
          autofocus: !widget.dictation,
          enabled: result == null,
          textDirection: g.target.direction,
          textAlign: TextAlign.center,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _check(),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: result == null ? Colors.white : color),
          decoration: InputDecoration(
            hintText: pale ? answer : '…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: pale ? 0.16 : 0.3), fontSize: 24),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: 2)),
            enabledBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: 2)),
            focusedBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: 3)),
            disabledBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: 2)),
          ),
        ),
        const SizedBox(height: 12),
        if (result == null) ...[
          if (g.target == AppLanguage.german)
            Wrap(spacing: 8, children: [
              for (final ch in ['ä', 'ö', 'ü', 'ß'])
                ActionChip(label: Text(ch, style: const TextStyle(fontSize: 18)), onPressed: () => _insert(ch)),
            ]),
          const SizedBox(height: 8),
          Row(children: [
            TextButton.icon(
              onPressed: _hint,
              icon: const Icon(Icons.lightbulb_rounded, color: AppColors.gold),
              label: Text(tr(g.native, 'پیتەکێ نیشان بدە', 'Tipp', 'Hint')),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: g.item.kind.color, padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14)),
              onPressed: _check,
              child: Text(tr(g.native, 'پشکنین', 'Prüfen', 'Check'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ───────── ✍️ رستێ تەمام بکە ─────────
class _FinishSentence extends StatefulWidget {
  final GameItemView g;
  const _FinishSentence(this.g);
  @override
  State<_FinishSentence> createState() => _FinishSentenceState();
}

class _FinishSentenceState extends State<_FinishSentence> {
  String? picked;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final c = g.item.word;
    final ws = c.text(g.target).split(RegExp(r'\s+'));
    final right = GameSessionHelpers.clean(ws[g.item.blank]);
    return SingleChildScrollView(
      child: Column(children: [
        bigPic(c.pic, size: 64),
        const SizedBox(height: 10),
        Text(c.text(g.native), textDirection: g.native.direction, style: const TextStyle(fontSize: 18, color: Colors.white70)),
        const SizedBox(height: 22),
        Directionality(
          textDirection: g.target.direction,
          child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 10, children: [
            for (var i = 0; i < ws.length; i++)
              if (i == g.item.blank)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: picked == null ? g.item.kind.color : _col(picked!), width: 3)),
                  ),
                  child: Text(picked == null ? '      ' : right,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: picked == null ? Colors.white : AppColors.green)),
                )
              else
                Text(ws[i], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 30),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (final o in g.item.options)
            ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(o, textDirection: g.target.direction, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
              ),
              selected: picked == o,
              selectedColor: _col(o).withValues(alpha: 0.35),
              backgroundColor: picked != null && o.toLowerCase() == right.toLowerCase() ? AppColors.green.withValues(alpha: 0.25) : AppColors.card,
              onSelected: picked != null
                  ? null
                  : (_) async {
                      setState(() => picked = o);
                      final ok = o.toLowerCase() == right.toLowerCase();
                      await g.onAnswer(c, ok);
                      say(c, g.target);
                      g.onComplete(ok: ok, answer: c.text(g.target));
                    },
            ),
        ]),
      ]),
    );
  }

  Color _col(String o) {
    final right = GameSessionHelpers.clean(widget.g.item.word.text(widget.g.target).split(RegExp(r'\s+'))[widget.g.item.blank]);
    return o.toLowerCase() == right.toLowerCase() ? AppColors.green : AppColors.red;
  }
}

// ───────── 🔤 پەیڤا ڤەشارتی (Word Search) ─────────
class _WordSearch extends StatefulWidget {
  final GameItemView g;
  const _WordSearch(this.g);
  @override
  State<_WordSearch> createState() => _WordSearchState();
}

class _Placed {
  final WordConcept c;
  final String word;
  final List<int> cells;
  _Placed(this.c, this.word, this.cells);
}

class _WordSearchState extends State<_WordSearch> {
  static const _colors = [
    Color(0xFF1CB0F6), Color(0xFFFF4B91), Color(0xFF58CC02), Color(0xFFFF9600), Color(0xFFCE82FF), Color(0xFF00C2A8),
  ];
  final rng = Random();
  late int n;
  late List<String> grid;
  final placed = <_Placed>[];
  final found = <String>{}; // concept ids
  final cellColor = <int, Color>{};
  int? start;
  bool flashBad = false;
  bool gaveUp = false;

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    final g = widget.g;
    final ws = <(WordConcept, String)>[];
    for (final c in g.item.words) {
      final w = GameSessionHelpers.searchWord(c, g.target);
      if (w != null) ws.add((c, w));
    }
    ws.sort((a, b) => b.$2.length.compareTo(a.$2.length));
    n = max(8, ws.isEmpty ? 8 : ws.first.$2.length);
    if (n > 10) n = 10;
    grid = List.filled(n * n, '');
    const dirs = [(0, 1), (1, 0), (1, 1)]; // ➡️ ⬇️ ↘️
    for (final (c, w) in ws) {
      for (var attempt = 0; attempt < 300; attempt++) {
        final (dr, dc) = dirs[rng.nextInt(dirs.length)];
        final maxR = n - (dr == 0 ? 1 : w.length);
        final maxC = n - (dc == 0 ? 1 : w.length);
        if (maxR < 0 || maxC < 0) continue;
        final r0 = rng.nextInt(maxR + 1), c0 = rng.nextInt(maxC + 1);
        final cells = [for (var i = 0; i < w.length; i++) (r0 + dr * i) * n + (c0 + dc * i)];
        var fits = true;
        for (var i = 0; i < w.length; i++) {
          final cur = grid[cells[i]];
          if (cur.isNotEmpty && cur != w[i]) {
            fits = false;
            break;
          }
        }
        if (!fits) continue;
        for (var i = 0; i < w.length; i++) {
          grid[cells[i]] = w[i];
        }
        placed.add(_Placed(c, w, cells));
        break;
      }
    }
    final letters = g.target == AppLanguage.german
        ? 'ABCDEFGHIJKLMNOPRSTUVWZEEINNRSTAÄÖÜ'
        : (g.target == AppLanguage.english ? 'ABCDEFGHIJKLMNOPRSTUVWYEEAIONRST' : 'ئابپتجچحخدرزژسشعغفڤقکگلمنوهیێۆە');
    for (var i = 0; i < grid.length; i++) {
      if (grid[i].isEmpty) grid[i] = letters[rng.nextInt(letters.length)];
    }
  }

  Future<void> _tap(int i) async {
    if (gaveUp) return;
    if (start == null) {
      setState(() => start = i);
      return;
    }
    final s = start!;
    setState(() => start = null);
    final line = _line(s, i);
    if (line == null) return;
    for (final p in placed) {
      if (found.contains(p.c.id)) continue;
      final same = _eq(line, p.cells) || _eq(line.reversed.toList(), p.cells);
      if (same) {
        final col = _colors[found.length % _colors.length];
        setState(() {
          found.add(p.c.id);
          for (final cell in p.cells) {
            cellColor[cell] = col;
          }
        });
        say(p.c, widget.g.target);
        await widget.g.onAnswer(p.c, true);
        if (found.length == placed.length) widget.g.onComplete(ok: true);
        return;
      }
    }
    setState(() => flashBad = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => flashBad = false);
  }

  bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// خانێن د ناڤبەرا دوو خانان دا (ئاسۆیی، ستوونی یان ب لار)
  List<int>? _line(int a, int b) {
    final r1 = a ~/ n, c1 = a % n, r2 = b ~/ n, c2 = b % n;
    final dr = (r2 - r1).sign, dc = (c2 - c1).sign;
    final len = max((r2 - r1).abs(), (c2 - c1).abs());
    if (!(r1 == r2 || c1 == c2 || (r2 - r1).abs() == (c2 - c1).abs())) return null;
    return [for (var i = 0; i <= len; i++) (r1 + dr * i) * n + (c1 + dc * i)];
  }

  Future<void> _giveUp() async {
    setState(() => gaveUp = true);
    for (final p in placed) {
      if (found.contains(p.c.id)) continue;
      for (final cell in p.cells) {
        cellColor[cell] = Colors.white38;
      }
      await widget.g.onAnswer(p.c, false);
    }
    setState(() {});
    widget.g.onComplete(ok: false);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    return SingleChildScrollView(
      child: Column(children: [
        Text(tr(g.native, 'دەست ل پیتا ئێکێ و یا دووماهیێ بدە', 'Tippe auf den ersten und letzten Buchstaben',
                'Tap the first and the last letter'),
            style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: LayoutBuilder(builder: (context, box) {
            final cell = ((box.maxWidth - 6) / n).floorToDouble();
            return Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: flashBad ? AppColors.red : Colors.white12, width: 2),
              ),
              child: Wrap(children: [
                for (var i = 0; i < grid.length; i++)
                  GestureDetector(
                    onTap: () => _tap(i),
                    child: Container(
                      width: cell,
                      height: cell,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: start == i
                            ? g.item.kind.color
                            : (cellColor[i]?.withValues(alpha: 0.45) ?? Colors.transparent),
                        borderRadius: BorderRadius.circular(cell * 0.3),
                      ),
                      child: Text(grid[i],
                          style: TextStyle(fontSize: cell * 0.48, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
              ]),
            );
          }),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < placed.length; i++)
            Chip(
              backgroundColor: found.contains(placed[i].c.id)
                  ? cellColor[placed[i].cells.first]!.withValues(alpha: 0.35)
                  : AppColors.card,
              label: Text(
                '${placed[i].c.pic} ${found.contains(placed[i].c.id) || gaveUp ? placed[i].word : placed[i].c.text(g.native)}',
                style: const TextStyle(fontSize: 15),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        if (!gaveUp && found.length < placed.length)
          TextButton.icon(
            onPressed: _giveUp,
            icon: const Icon(Icons.visibility_rounded),
            label: Text(tr(g.native, 'بەرسڤان نیشان بدە', 'Lösung zeigen', 'Show answers')),
          ),
      ]),
    );
  }
}

// ───────── 🎙️ Shadowing: گوهداری بکە، بخوینە، بێژە ─────────
class _Shadowing extends StatefulWidget {
  final GameItemView g;
  const _Shadowing(this.g);
  @override
  State<_Shadowing> createState() => _ShadowingState();
}

class _ShadowingState extends State<_Shadowing> {
  final voice = VoiceService.instance;
  bool recorded = false;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => say(widget.g.item.word, widget.g.target));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final c = g.item.word;
    final practice = voice.practiceRecording;
    return SingleChildScrollView(
      child: Column(children: [
        bigPic(c.pic, size: 64),
        const SizedBox(height: 12),
        Text(c.text(g.target),
            textDirection: g.target.direction,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('💡 ${c.hint(g.target)}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.blue)),
        Text(c.text(g.native), textDirection: g.native.direction, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          soundBtn(() => say(c, g.target), size: 60, color: g.item.kind.color),
          const SizedBox(width: 16),
          soundBtn(() => say(c, g.target, rate: 0.65), icon: Icons.slow_motion_video_rounded, size: 48, color: g.item.kind.color),
        ]),
        const SizedBox(height: 22),
        RecordButton(
          size: 92,
          onStart: () => voice.startRecording(practice: true),
          onStop: () async {
            final path = await voice.stopRecording();
            if (path == null) return;
            setState(() => recorded = true);
            await voice.playFile(path);
          },
          hintText: tr(g.native, 'دەست ب سەر دا بگرە و بێژە', 'Gedrückt halten und sprechen', 'Hold and speak'),
        ),
        const SizedBox(height: 12),
        if (recorded && practice != null)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: () => voice.playFile(practice),
              icon: const Icon(Icons.person_rounded),
              label: Text(tr(g.native, 'دەنگێ من', 'Meine', 'Mine')),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => say(c, g.target),
              icon: const Icon(Icons.record_voice_over_rounded),
              label: Text(tr(g.native, 'نموونە', 'Vorlage', 'Model')),
            ),
          ]),
        const SizedBox(height: 12),
        if (!finished)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: recorded ? AppColors.green : Colors.white24),
            onPressed: () async {
              setState(() => finished = true);
              if (recorded) await g.onAnswer(c, true);
              g.onComplete(ok: recorded);
            },
            child: Text(recorded ? tr(g.native, 'من گۆت ✓', 'Gesagt ✓', 'I said it ✓') : tr(g.native, 'دەرباز بکە', 'Überspringen', 'Skip')),
          ),
      ]),
    );
  }
}
