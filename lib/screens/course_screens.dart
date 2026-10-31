import 'package:flutter/material.dart';

import '../data/curriculum.dart';
import '../data/exams.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'quiz_screen.dart';
import 'widgets/mascot.dart';

AppLanguage get _ui => ProgressService.instance.nativeLang;

// ───────────────────────── 📘 کارتا رێزمانێ ─────────────────────────

/// کارتا رێزمانێ وەکی Bottom Sheet. [onStart] ئەگەر هەبیت، دوگمەیا «دەستپێبکە» نیشان ددەت.
Future<void> showGrammarCard(BuildContext context, LessonUnit unit, {VoidCallback? onStart}) {
  final g = unit.grammar!;
  ProgressService.instance.setGrammarSeen(unit.id);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => Directionality(
      textDirection: _ui.direction,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.95,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
          children: [
            Center(
                child: Container(
                    width: 44, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: unit.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                child: const Text('📘', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.titleKu, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, fontFamily: 'Sarchia')),
                  if (g.titleDe.isNotEmpty)
                    Text(g.titleDe, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.gold)),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            for (final line in g.lines) _GrammarLine(line),
            if (g.table != null) ...[const SizedBox(height: 10), _GrammarTable(g.table!, unit.color)],
            const SizedBox(height: 22),
            if (onStart != null)
              BigButton(
                label: tr(_ui, 'تێگەهشتم — دەستپێبکە', 'Verstanden – los!', 'Got it — start'),
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  Navigator.pop(ctx);
                  onStart();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _GrammarLine extends StatelessWidget {
  final String text;
  const _GrammarLine(this.text);

  @override
  Widget build(BuildContext context) {
    // پشکێن ئەلمانی (پیتێن لاتینی) ب رەنگێ زێڕی و دوگمەیا گوهداریێ
    final hasLatin = RegExp(r'[A-Za-zÄÖÜäöüß]{3,}').hasMatch(text);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.6))),
        if (hasLatin)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.volume_up_rounded, color: AppColors.blue),
            onPressed: () {
              final de = RegExp(r'[A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß ,.!?\-|/…]+').allMatches(text).map((m) => m.group(0)!.trim()).where((s) => s.length > 2).join('. ');
              VoiceService.instance.speakText(de.replaceAll('|', ' '), AppLanguage.german, rate: 0.9);
            },
          ),
      ]),
    );
  }
}

class _GrammarTable extends StatelessWidget {
  final List<List<String>> rows;
  final Color color;
  const _GrammarTable(this.rows, this.color);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Table(
          border: TableBorder.all(color: Colors.white12),
          children: [
            for (var r = 0; r < rows.length; r++)
              TableRow(
                decoration: BoxDecoration(color: r == 0 ? color.withValues(alpha: 0.35) : (r.isOdd ? AppColors.card : AppColors.bg)),
                children: [
                  for (var c = 0; c < rows[r].length; c++)
                    InkWell(
                      onTap: r > 0 && c > 0
                          ? () => VoiceService.instance.speakText('${rows[r][0].split('/').first} ${rows[r][c]}', AppLanguage.german)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        child: Text(rows[r][c],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: r == 0 || c == 0 ? FontWeight.bold : FontWeight.w500,
                                color: c == 0 && r > 0 ? AppColors.gold : Colors.white)),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 💬 دیالۆگ ─────────────────────────

class DialogScreen extends StatefulWidget {
  final LektionInfo lektion;
  const DialogScreen({super.key, required this.lektion});

  @override
  State<DialogScreen> createState() => _DialogScreenState();
}

class _DialogScreenState extends State<DialogScreen> {
  bool showKu = true;
  int? playing;
  bool auto = false;

  Future<void> _playAll() async {
    setState(() => auto = true);
    for (var k = 0; k < widget.lektion.dialog.length && auto && mounted; k++) {
      setState(() => playing = k);
      final line = widget.lektion.dialog[k];
      await VoiceService.instance.speakText(line.de, AppLanguage.german);
      // دەمێ خواندنێ ب نێزیکی
      await Future.delayed(Duration(milliseconds: 900 + line.de.length * 75));
    }
    if (mounted) setState(() => auto = false);
  }

  @override
  void dispose() {
    auto = false;
    VoiceService.instance.stopPlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lektion;
    final speakers = l.dialog.map((d) => d.who).toSet().toList();
    return Directionality(
      textDirection: _ui.direction,
      child: Scaffold(
        appBar: AppBar(
          title: Text('💬 ${l.dialogTitleKu}'),
          actions: [
            IconButton(
              tooltip: 'Kurdî',
              icon: Icon(showKu ? Icons.translate_rounded : Icons.translate_outlined, color: showKu ? AppColors.gold : null),
              onPressed: () => setState(() => showKu = !showKu),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            for (var k = 0; k < l.dialog.length; k++) _bubble(l.dialog[k], k, speakers.indexOf(l.dialog[k].who)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.green,
          onPressed: auto
              ? () => setState(() => auto = false)
              : _playAll,
          icon: Icon(auto ? Icons.stop_rounded : Icons.play_arrow_rounded),
          label: Text(auto ? tr(_ui, 'راوەستە', 'Stopp', 'Stop') : tr(_ui, 'هەمییێ گوهداری بکە', 'Alles anhören', 'Play all')),
        ),
      ),
    );
  }

  Widget _bubble(DialogLine d, int k, int who) {
    final active = playing == k;
    final left = who.isEven;
    final avatar = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedScale(
        scale: active ? 1.12 : 1,
        duration: const Duration(milliseconds: 200),
        child: MascotAvatar(
          char: MascotChar.forSpeaker(d.who),
          talking: active,
          size: 52,
          ring: active ? AppColors.gold : (left ? AppColors.blue : AppColors.green),
        ),
      ),
    );
    return Row(
      mainAxisAlignment: left ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (left) ...[avatar, const SizedBox(width: 8)],
        Flexible(child: _bubbleBody(d, k, left, active)),
        if (!left) ...[const SizedBox(width: 8), avatar],
      ],
    );
  }

  Widget _bubbleBody(DialogLine d, int k, bool left, bool active) {
    return Align(
      alignment: left ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onTap: () {
          setState(() => playing = k);
          VoiceService.instance.speakText(d.de, AppLanguage.german);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(maxWidth: 290),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: left ? AppColors.card : const Color(0xFF1B3A4B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? AppColors.gold : Colors.white12, width: active ? 2.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.who, textDirection: TextDirection.ltr, style: TextStyle(color: left ? AppColors.blue : AppColors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(d.de, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (showKu) ...[
              const SizedBox(height: 6),
              Text(d.ku, textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── 📝 ئەزموون ─────────────────────────

void openLektionTest(BuildContext context, LektionInfo l) {
  final qs = Exams.lektion[l.n] ?? const [];
  if (qs.isEmpty) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => QuizScreen(
        examId: 'lek_${l.n}',
        title: tr(_ui, 'ئەزموونا وانا ${l.n}', 'Test Lektion ${l.n}', 'Lesson ${l.n} test'),
        questions: qs,
      ),
    ),
  );
}

void openFinalExam(BuildContext context) {
  final qs = <ExamQuestion>[];
  final parts = <String>[];
  for (final p in Exams.finalParts) {
    for (final q in p.items) {
      qs.add(q);
      parts.add(p.titleKu);
    }
  }
  if (qs.isEmpty) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => QuizScreen(examId: 'final', title: Exams.finalTitleKu, questions: qs, partTitles: parts),
    ),
  );
}

/// 🎯 تاقیکرنا ئاستی: ٢ پرسیار بۆ هەر وانەیەکێ. ئەگەر هەردوو دروست بن، وانە دهێتە ڤەکرن.
void openPlacement(BuildContext context) {
  final qs = Exams.placement;
  if (qs.isEmpty) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => QuizScreen(
        examId: 'placement',
        title: tr(_ui, 'تاقیکرنا ئاستی', 'Einstufungstest', 'Placement test'),
        questions: qs,
        onDone: (ctx, results) async {
          final p = ProgressService.instance;
          // ئاستێ تە: ئێکەم وانا کو تێدا خەلەتی هەبیت
          var level = 1;
          final byLevel = <int, List<bool>>{};
          for (var k = 0; k < qs.length; k++) {
            byLevel.putIfAbsent(qs[k].level, () => []).add(results[k]);
          }
          final levels = byLevel.keys.toList()..sort();
          for (final lv in levels) {
            if (byLevel[lv]!.every((r) => r)) {
              level = lv + 1;
            } else {
              break;
            }
          }
          // هەمی قۆناغێن بەری وانا [level] دبنە تەمامکری (پیت ژی)
          final ids = appCurriculum.where((u) => u.section <= level).map((u) => u.id);
          if (level > 1) await p.markUnitsDone(ids);
          await p.setPlacementDone();
          final score = results.where((r) => r).length;
          if (!ctx.mounted) return;
          Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(
              builder: (_) => QuizResultScreen(
                title: tr(_ui, 'تاقیکرنا ئاستی', 'Einstufungstest', 'Placement test'),
                score: score,
                total: results.length,
                extra: level > 14
                    ? tr(_ui, 'تو هەمی A1 دزانی! 👑 ئەزموونا A1 تاقی بکە.', 'Du kannst A1 schon! 👑', 'You already know A1! 👑')
                    : tr(_ui, 'ب پێشنیارا مە ژ وانا $level دەستپێبکە.', 'Wir empfehlen: Start bei Lektion $level.',
                        'We suggest starting at lesson $level.'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

// ───────────────────────── 🔤 کارتێن پیتان ─────────────────────────

/// هەر پیتەک: ناڤێ وێ (C = تسێ)، دەنگێ وێ، و پەیڤەکا نموونە کو پیت تێدا یە.
class LetterCardsScreen extends StatefulWidget {
  final LessonUnit unit;
  final VoidCallback? onStart;
  const LetterCardsScreen({super.key, required this.unit, this.onStart});

  static Future<void> open(BuildContext context, LessonUnit unit, {VoidCallback? onStart}) {
    ProgressService.instance.setGrammarSeen('${unit.id}_letters');
    return Navigator.push(context, MaterialPageRoute(builder: (_) => LetterCardsScreen(unit: unit, onStart: onStart)));
  }

  @override
  State<LetterCardsScreen> createState() => _LetterCardsScreenState();
}

class _LetterCardsScreenState extends State<LetterCardsScreen> {
  late final cards = widget.unit.concepts.where((c) => c.letter != null).toList();
  final _page = PageController();
  int i = 0;
  AppLanguage get target => ProgressService.instance.targetLang;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _say());
  }

  @override
  void dispose() {
    _page.dispose();
    VoiceService.instance.stopPlayback();
    super.dispose();
  }

  void _say([double rate = 1.0]) {
    if (cards.isEmpty) return;
    VoiceService.instance.speak(cards[i], target, rate: rate);
  }

  @override
  Widget build(BuildContext context) {
    final last = i == cards.length - 1;
    return Directionality(
      textDirection: _ui.direction,
      child: Scaffold(
        appBar: AppBar(
          title: Text('🔤 ${widget.unit.title(_ui)}', style: const TextStyle(fontSize: 17)),
        ),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: MascotSays(
                mood: MascotMood.speak,
                height: 120,
                text: tr(_ui, 'گوهـ بدە 🔊 و ب دەنگێ بلند دووبارە بکە!', 'Hör zu und sprich nach!', 'Listen and repeat!'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: cards.isEmpty ? 1 : (i + 1) / cards.length,
                  minHeight: 8,
                  backgroundColor: AppColors.card,
                  valueColor: AlwaysStoppedAnimation(widget.unit.color),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: cards.length,
                onPageChanged: (k) {
                  setState(() => i = k);
                  _say();
                },
                itemBuilder: (_, k) => _card(cards[k]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                if (i > 0)
                  IconButton.filledTonal(
                    onPressed: () => _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                    icon: Icon(_ui.direction == TextDirection.rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: BigButton(
                    label: last
                        ? (widget.onStart != null
                            ? tr(_ui, 'تێگەهشتم — دەستپێبکە', 'Los geht’s', 'Start')
                            : tr(_ui, 'تەمام', 'Fertig', 'Done'))
                        : tr(_ui, 'پیتا دی', 'Nächster Buchstabe', 'Next letter'),
                    color: widget.unit.color,
                    onPressed: () {
                      if (!last) {
                        _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                      } else {
                        Navigator.pop(context);
                        widget.onStart?.call();
                      }
                    },
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _card(WordConcept c) {
    final l = c.letter!;
    final color = widget.unit.color;
    Widget chip(String title, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gold)),
            ]),
          ),
        );
    // پیت د ناڤ پەیڤێ دا ب رەنگێ زێڕی
    final spans = <TextSpan>[];
    for (final ch in l.word.split('')) {
      final hit = ch.toLowerCase() == l.upper.toLowerCase();
      spans.add(TextSpan(text: ch, style: TextStyle(color: hit ? AppColors.gold : Colors.white, decoration: hit ? TextDecoration.underline : null)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(children: [
        GestureDetector(
          onTap: _say,
          child: Container(
            width: 150,
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color, width: 4),
            ),
            child: Text('${l.upper} ${l.lower}',
                textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'LeagueGothic', fontSize: 78, height: 1)),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          chip(tr(_ui, 'ناڤێ پیتێ', 'Name', 'Name'), l.name),
          const SizedBox(width: 10),
          chip(tr(_ui, 'دەنگ د پەیڤێ دا', 'Laut', 'Sound'), l.sound),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            Text(c.pic, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 6),
            RichText(
              textDirection: TextDirection.ltr,
              text: TextSpan(style: const TextStyle(fontFamily: 'LeagueGothic', fontSize: 40, letterSpacing: 1), children: spans),
            ),
            const SizedBox(height: 6),
            Text('${tr(_ui, 'خواندن', 'Aussprache', 'Say')}: ${l.read}', style: const TextStyle(fontSize: 17, color: Colors.white70)),
            Text('${tr(_ui, 'رامان', 'Bedeutung', 'Meaning')}: ${c.text(_ui).split('·').last.trim()}',
                style: const TextStyle(fontSize: 16, color: Colors.white60)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.blue, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
            onPressed: _say,
            icon: const Icon(Icons.volume_up_rounded),
            label: Text(c.text(target), textDirection: TextDirection.ltr),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(onPressed: () => _say(0.7), icon: const Text('🐢', style: TextStyle(fontSize: 20))),
        ]),
      ]),
    );
  }
}
