import 'dart:math';

import 'package:flutter/material.dart';

import '../data/answer_check.dart';
import '../data/curriculum.dart';
import '../data/exams.dart';
import '../models.dart';
import '../services/backend.dart';
import '../services/progress_service.dart';
import '../services/sfx.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'streak_screen.dart';
import 'widgets/combo.dart';

/// 📝 ئەزموون: ئەزموونا وانێ، ئەزموونا A1، و تاقیکرنا ئاستی.
/// جۆرێن جودا: هەلبژارتن، دروست/خەلەت، وێنە (٢–٦)، ئیمۆجی ➔ پەیڤ، گوهداری، نڤیسین، رێزکرنا رستێ.
class QuizScreen extends StatefulWidget {
  final String examId; // e.g. 'lek_3', 'final', 'placement'
  final String title;
  final List<ExamQuestion> questions;
  final List<String> partTitles; // بۆ ئەزموونا A1: ناڤێ پشکێ بۆ هەر پرسیارەکێ
  final void Function(BuildContext context, List<bool> results)? onDone;

  const QuizScreen({
    super.key,
    required this.examId,
    required this.title,
    required this.questions,
    this.partTitles = const [],
    this.onDone,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final voice = VoiceService.instance;
  final progress = ProgressService.instance;
  AppLanguage get ui => progress.nativeLang;

  int i = 0;
  int? picked;
  bool checked = false;
  bool ok = false;
  AnswerResult? verdict; // ✅ دروست بەلێ تێبینی هەیە (Tschüss ⇄ Auf Wiedersehen)
  int hintLevel = 0; // 👁️ چاڤێ هاریکاریێ (٠–٣)
  int quizXp = 0; // XP ل دویف کۆمبۆیێ
  final results = <bool>[];
  final typeCtrl = TextEditingController();
  List<String> tiles = [];
  List<int> order = [];

  ExamQuestion get q => widget.questions[i];

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    typeCtrl.dispose();
    voice.stopPlayback();
    super.dispose();
  }

  void _prepare() {
    voice.stopPlayback(); // دەنگێ پرسیارا بەرێ ڕاوەستینە
    picked = null;
    checked = false;
    ok = false;
    verdict = null;
    hintLevel = 0;
    typeCtrl.clear();
    order = [];
    if (q.type == QType.order) {
      tiles = q.q.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()..shuffle(Random());
    }
    if (q.audio != null && (q.type == QType.listen || q.q == '🎧')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    }
  }

  void _play([double rate = 1.0]) {
    final a = q.audio;
    if (a != null) voice.speakText(a, AppLanguage.german, rate: rate);
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[.,!?;:„“"«»]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  bool get _canCheck => switch (q.type) {
        QType.type => typeCtrl.text.trim().isNotEmpty,
        QType.order => order.length == tiles.length,
        _ => picked != null,
      };

  void _check() {
    final lang = progress.targetLang;
    AnswerResult? v;
    switch (q.type) {
      case QType.type:
        v = judgeAnswer(typeCtrl.text, q.answer.toString(), lang, typed: true, ui: ui);
      case QType.order:
        v = _norm(order.map((k) => tiles[k]).join(' ')) == _norm(q.answer.toString()) ? const AnswerResult(Verdict.exact) : null;
      case QType.choice || QType.imgchoice || QType.listen:
        final a = (q.answer as num).toInt();
        if (picked == a) {
          v = const AnswerResult(Verdict.exact);
        } else if (picked != null) {
          // هەلبژارتنەکا دی کو هەمان رامان هەیە ➔ دروستە دگەل تێبینیێ
          v = judgeAnswer(q.options[picked!], q.options[a], lang, ui: ui);
        }
      default:
        v = picked == (q.answer as num).toInt() ? const AnswerResult(Verdict.exact) : null;
    }
    final good = v?.accepted ?? false;
    setState(() {
      checked = true;
      ok = good;
      verdict = v;
    });
    if (good) {
      Sfx.correct();
    } else {
      Sfx.wrong();
    }
    final gained = progress.registerAnswer(good);
    quizXp += gained;
    if (gained > 0) showXpPop(context, gained, combo: progress.combo);
    if (good && progress.combo % 5 == 0) showComboToast(context, progress.combo, ui);
    if (q.audio != null && q.type != QType.listen) _play();
  }

  Future<void> _next() async {
    results.add(ok);
    if (i + 1 < widget.questions.length) {
      setState(() {
        i++;
        _prepare();
      });
      return;
    }
    final score = results.where((r) => r).length;
    final pct = (score * 100 / results.length).round();
    await progress.saveExam(widget.examId, pct);
    Backend.instance.examResult(widget.examId, score, results.length);
    await progress.earn(5 + quizXp);
    Sfx.done();
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!(context, results);
      return;
    }
    await Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => QuizResultScreen(title: widget.title, score: score, total: results.length)));
  }

  // ─────────────────────────── UI ───────────────────────────
  @override
  Widget build(BuildContext context) {
    final part = i < widget.partTitles.length ? widget.partTitles[i] : '';
    return Directionality(
      textDirection: ui.direction,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            ListenableBuilder(
                listenable: progress,
                builder: (_, __) => Row(children: [
                  Expanded(
                    child: ComboBar(
                        value: (i + (checked ? 1 : 0)) / widget.questions.length, combo: progress.combo, color: AppColors.gold, height: 9),
                  ),
                  ComboBadge(combo: progress.combo),
                ]),
              ),

          ]),
          actions: [
            Center(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('${i + 1}/${widget.questions.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (part.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(part, style: TextStyle(color: AppColors.goldText, fontWeight: FontWeight.bold)),
                ),
              Text(_instruction(), style: TextStyle(color: AppColors.fg70, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Expanded(child: SingleChildScrollView(child: _body())),
              if (checked) _feedback(),
              BigButton(
                label: checked ? tr(ui, 'بەردەوام بە', 'Weiter', 'Continue') : tr(ui, 'پشکنین', 'Prüfen', 'Check'),
                color: checked ? (ok ? ((verdict?.soft ?? false) ? AppColors.orange : AppColors.green) : AppColors.red) : AppColors.accent,
                onPressed: checked ? _next : (_canCheck ? _check : null),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _instruction() => switch (q.type) {
        QType.choice => tr(ui, 'بەرسڤا دروست هەلبژێرە', 'Wähle die richtige Antwort', 'Choose the right answer'),
        QType.truefalse => tr(ui, 'دروستە یان خەلەتە؟', 'Richtig oder falsch?', 'True or false?'),
        QType.picture => tr(ui, 'وێنەیێ دروست هەلبژێرە 🖼️', 'Wähle das richtige Bild 🖼️', 'Pick the right picture 🖼️'),
        QType.imgchoice => _phraseOptions
            ? tr(ui, 'کیژ رستە دگەل ڤی وێنەی دگونجیت؟ 🖼️', 'Welcher Satz passt zum Bild? 🖼️', 'Which sentence fits the picture? 🖼️')
            : tr(ui, 'ئەڤ وێنەیە چییە ب ئەلمانی؟', 'Was ist das auf Deutsch?', 'What is this in German?'),
        QType.listen => tr(ui, 'گوهداری بکە و هەلبژێرە 🎧', 'Hör zu und wähle 🎧', 'Listen and choose 🎧'),
        QType.type => tr(ui, 'ب ئەلمانی بنڤیسە ⌨️', 'Schreib auf Deutsch ⌨️', 'Write in German ⌨️'),
        QType.order => tr(ui, 'رستێ رێک بێخە 🧩', 'Bilde den Satz 🧩', 'Put the sentence in order 🧩'),
      };

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.fg12, width: 2),
        ),
        child: child,
      );

  Widget _speaker({double size = 64}) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _round(Icons.volume_up_rounded, size, () => _play()),
        const SizedBox(width: 14),
        _round(Icons.slow_motion_video_rounded, size * 0.72, () => _play(0.7)),
      ]);

  Widget _round(IconData icon, double size, VoidCallback onTap) => InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: size * 0.55),
        ),
      );

  Color? _state(int k) {
    if (!checked) return null;
    if (k == (q.answer as num).toInt()) return AppColors.green;
    if (k == picked) return ok ? AppColors.orange : AppColors.red;
    return null;
  }

  Widget _body() {
    switch (q.type) {
      case QType.picture:
        // پەیڤ ➔ وێنە: تۆڕا ٢ / ٣ / ٤ / ٦ وێنەیان
        final n = q.options.length;
        final cols = n <= 2 ? 2 : (n == 3 ? 3 : (n == 4 ? 2 : 3));
        return Column(children: [
          _card(Column(children: [
            if (q.q == '🎧')
              _speaker()
            else ...[
              Text(q.q, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              if (q.audio != null) ...[const SizedBox(height: 10), _round(Icons.volume_up_rounded, 44, () => _play())],
            ],
          ])),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (var k = 0; k < n; k++)
                GestureDetector(
                  onTap: checked ? null : () => setState(() => picked = k),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: (_state(k) ?? (picked == k ? AppColors.accent : AppColors.fg24)).withValues(alpha: picked == k || _state(k) != null ? 0.2 : 0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _state(k) ?? (picked == k ? AppColors.accent : AppColors.fg24), width: 3),
                    ),
                    child: Center(child: Text(q.options[k], style: TextStyle(fontSize: cols == 3 ? 46 : 60))),
                  ),
                ),
            ],
          ),
        ]);

      case QType.truefalse:
        return Column(children: [
          _card(Text(q.q, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, height: 1.5))),
          const SizedBox(height: 22),
          Row(children: [
            for (var k = 0; k < 2; k++) ...[
              if (k == 1) const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: checked ? null : () => setState(() => picked = k),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    decoration: BoxDecoration(
                      color: (_state(k) ?? (picked == k ? AppColors.accent : AppColors.card)).withValues(alpha: picked == k || _state(k) != null ? 0.25 : 1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _state(k) ?? (picked == k ? AppColors.accent : AppColors.fg24), width: 3),
                    ),
                    child: Column(children: [
                      Text(k == 0 ? '✅' : '❌', style: const TextStyle(fontSize: 34)),
                      const SizedBox(height: 6),
                      Text(k == 0 ? tr(ui, 'دروستە', 'Richtig', 'True') : tr(ui, 'خەلەتە', 'Falsch', 'False'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
        ]);

      case QType.imgchoice:
        return Column(children: [
          _card(Column(children: [
            Center(child: Text(q.q, style: const TextStyle(fontSize: 96))),
            if (!checked && q.explain.isNotEmpty) _hintEye(),
          ])),
          const SizedBox(height: 18),
          ..._textOptions(TextDirection.ltr, meanings: hintLevel >= 3 || checked),
        ]);

      case QType.listen:
        return Column(children: [
          _card(Column(children: [
            _speaker(size: 78),
            if (checked && q.audio != null) ...[
              const SizedBox(height: 12),
              Text(q.audio!, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ])),
          const SizedBox(height: 18),
          ..._textOptions(null),
        ]);

      case QType.type:
        return Column(children: [
          _card(Column(children: [
            if (q.pic != null) Text(q.pic!, style: const TextStyle(fontSize: 64)),
            Text(q.q, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, height: 1.5, fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(height: 18),
          TextField(
            controller: typeCtrl,
            enabled: !checked,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            style: const TextStyle(fontSize: 20),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Deutsch …',
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [
            for (final ch in ['ä', 'ö', 'ü', 'ß', 'Ä', 'Ö', 'Ü'])
              ActionChip(
                label: Text(ch, style: const TextStyle(fontSize: 18)),
                onPressed: checked
                    ? null
                    : () {
                        typeCtrl.text += ch;
                        setState(() {});
                      },
              ),
          ]),
        ]);

      case QType.order:
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              constraints: const BoxConstraints(minHeight: 70),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.fg24, width: 2))),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in order)
                  ActionChip(
                    label: Text(tiles[k], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    onPressed: checked ? null : () => setState(() => order.remove(k)),
                  ),
              ]),
            ),
            const SizedBox(height: 22),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              for (var k = 0; k < tiles.length; k++)
                Opacity(
                  opacity: order.contains(k) ? 0.2 : 1,
                  child: ActionChip(
                    backgroundColor: AppColors.card,
                    label: Text(tiles[k], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    onPressed: checked || order.contains(k) ? null : () => setState(() => order.add(k)),
                  ),
                ),
            ]),
          ]),
        );

      case QType.choice:
        return Column(children: [
          _card(Text(q.q, textAlign: TextAlign.center, textDirection: _dir(q.q),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4))),
          const SizedBox(height: 18),
          ..._textOptions(null),
        ]);
    }
  }

  static final _arabic = RegExp(r'[؀-ۿ]');
  TextDirection _dir(String s) => _arabic.hasMatch(s) ? TextDirection.rtl : TextDirection.ltr;

  List<Widget> _textOptions(TextDirection? dir, {bool meanings = false}) => [
        for (var k = 0; k < q.options.length; k++)
          OptionTile(
            text: q.options[k],
            selected: picked == k,
            stateColor: _state(k),
            textDirection: dir ?? _dir(q.options[k]),
            subtitle: meanings ? _kuOf(q.options[k]) : null,
            onTap: checked ? null : () => setState(() => picked = k),
          ),
      ];

  /// هەلبژارتن رستە نە (نە ئێک پەیڤ) ➔ پرسیار ب «کیژ رستە …؟»
  bool get _phraseOptions => q.options.any((o) => o.trim().split(RegExp(r'\s+')).length >= 3);

  static Map<String, String>? _kuIndex;

  /// رامانا کوردی یا دەقەکێ ئەلمانی (ژ وانەیان)
  String _kuOf(String de) {
    _kuIndex ??= {for (final c in allConcepts) _norm(c.de): c.ku};
    return _kuIndex![_norm(de)] ?? '';
  }

  /// 👁️ چاڤێ هاریکاریێ: ٣ جاران — هەر جار پتر دیار دکەت
  /// ١) پشکەک ژ رامانێ · ٢) هەمی رامانا رستێ · ٣) رامانا هەمی هەلبژارتنان
  Widget _hintEye() {
    final ex = q.explain.trim();
    final words = ex.split(RegExp(r'\s+'));
    final half = words.length <= 2 ? ex : '${words.take((words.length / 2).ceil()).join(' ')} …';
    final text = switch (hintLevel) {
      1 => half,
      2 || 3 => ex,
      _ => '',
    };
    final left = 3 - hintLevel;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: left == 0 ? null : () => setState(() => hintLevel++),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: hintLevel > 0 ? AppColors.accent.withValues(alpha: 0.16) : AppColors.cardAlt,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: hintLevel > 0 ? AppColors.accent : AppColors.fg24, width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(hintLevel > 0 ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: hintLevel > 0 ? AppColors.accent : AppColors.fg60, size: 22),
              const SizedBox(width: 8),
              Text(
                left == 0
                    ? tr(ui, 'هەمی هاریکاری هاتنە دیتن', 'Alle Hilfen genutzt', 'All hints used')
                    : tr(ui, 'هاریکاری · ${'●' * left}${'○' * hintLevel}', 'Hilfe · ${'●' * left}', 'Hint · ${'●' * left}'),
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.fg70, fontSize: 14),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: text.isEmpty
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.cardAlt, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text('💬 $text',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.fg, height: 1.5)),
                    if (hintLevel == 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(tr(ui, '👇 رامانا هەر رستەکێ ل بن وێ یە', '👇 Bedeutung unter jeder Antwort', '👇 Meaning under each option'),
                            style: TextStyle(fontSize: 12.5, color: AppColors.fg54)),
                      ),
                  ]),
                ),
        ),
      ]),
    );
  }

  Widget _feedback() {
    final soft = ok && (verdict?.soft ?? false);
    final c = soft ? AppColors.orange : (ok ? AppColors.green : AppColors.red);
    String correct = '';
    if (!ok) {
      correct = switch (q.type) {
        QType.type || QType.order => q.answer.toString(),
        QType.truefalse => (q.answer as num).toInt() == 0 ? tr(ui, 'دروستە', 'Richtig', 'True') : tr(ui, 'خەلەتە', 'Falsch', 'False'),
        _ => q.options[(q.answer as num).toInt()],
      };
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14), border: Border.all(color: c)),
      child: Row(children: [
        Icon(soft ? Icons.lightbulb_rounded : (ok ? Icons.check_circle : Icons.error), color: c, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (soft)
              Text(verdict!.note, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, height: 1.5))
            else
              Text(ok ? tr(ui, 'دەستخۆش! 🎉', 'Super! 🎉', 'Great! 🎉') : '${tr(ui, 'بەرسڤا دروست:', 'Richtig:', 'Answer:')} $correct',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (!ok && (verdict?.note.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(verdict!.note, style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, height: 1.5)),
              ),
            if (q.explain.isNotEmpty)
              Text(q.type == QType.type ? '🔊 ${q.explain}' : '💬 ${q.explain}', style: TextStyle(color: AppColors.fg70, height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

/// ئەنجاما ئەزموونێ
class QuizResultScreen extends StatelessWidget {
  final String title;
  final int score, total;
  final String? extra;
  const QuizResultScreen({super.key, required this.title, required this.score, required this.total, this.extra});

  @override
  Widget build(BuildContext context) {
    final ui = ProgressService.instance.nativeLang;
    final pct = total == 0 ? 0 : (score * 100 / total).round();
    final pass = pct >= 60;
    return Directionality(
      textDirection: ui.direction,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              Text(pct >= 90 ? '🏆' : (pass ? '🎉' : '💪'), style: const TextStyle(fontSize: 90)),
              const SizedBox(height: 10),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: AppColors.fg70)),
              const SizedBox(height: 16),
              Text('$pct%', style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: pass ? AppColors.green : AppColors.orange)),
              Text('$score / $total', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 14),
              Text(
                pass
                    ? tr(ui, 'تو سەرکەفتی! 👏', 'Bestanden! 👏', 'Passed! 👏')
                    : tr(ui, 'هێشتا نە. وانێ دووبارە بکە و جارەکا دی تاقی بکە.', 'Noch nicht. Wiederhole und versuch es nochmal.',
                        'Not yet. Review and try again.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (extra != null) ...[
                const SizedBox(height: 12),
                Text(extra!, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.goldText)),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: BigButton(
                  label: tr(ui, 'باشە', 'OK', 'OK'),
                  onPressed: () async {
                    if (!await maybeShowStreak(context, replace: true) && context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
