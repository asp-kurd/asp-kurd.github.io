import 'dart:math';

import 'package:flutter/material.dart';

import '../data/exams.dart';
import '../models.dart';
import '../services/backend.dart';
import '../services/progress_service.dart';
import '../services/sfx.dart';
import '../services/voice_service.dart';
import '../ui.dart';

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
    picked = null;
    checked = false;
    ok = false;
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
    final good = switch (q.type) {
      QType.type => _norm(typeCtrl.text) == _norm(q.answer.toString()),
      QType.order => _norm(order.map((k) => tiles[k]).join(' ')) == _norm(q.answer.toString()),
      _ => picked == (q.answer as num).toInt(),
    };
    setState(() {
      checked = true;
      ok = good;
    });
    if (good) {
      Sfx.correct();
    } else {
      Sfx.wrong();
    }
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
    await progress.earn(5 + score);
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (i + (checked ? 1 : 0)) / widget.questions.length,
                minHeight: 8,
                backgroundColor: AppColors.card,
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              ),
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
                  child: Text(part, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                ),
              Text(_instruction(), style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Expanded(child: SingleChildScrollView(child: _body())),
              if (checked) _feedback(),
              BigButton(
                label: checked ? tr(ui, 'بەردەوام بە', 'Weiter', 'Continue') : tr(ui, 'پشکنین', 'Prüfen', 'Check'),
                color: checked ? (ok ? AppColors.green : AppColors.red) : AppColors.blue,
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
        QType.imgchoice => tr(ui, 'ئەڤ وێنەیە چییە ب ئەلمانی؟', 'Was ist das auf Deutsch?', 'What is this in German?'),
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
          border: Border.all(color: Colors.white12, width: 2),
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
          decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: size * 0.55),
        ),
      );

  Color? _state(int k) {
    if (!checked) return null;
    if (k == (q.answer as num).toInt()) return AppColors.green;
    if (k == picked) return AppColors.red;
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
                      color: (_state(k) ?? (picked == k ? AppColors.blue : Colors.white24)).withValues(alpha: picked == k || _state(k) != null ? 0.2 : 0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _state(k) ?? (picked == k ? AppColors.blue : Colors.white24), width: 3),
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
                      color: (_state(k) ?? (picked == k ? AppColors.blue : AppColors.card)).withValues(alpha: picked == k || _state(k) != null ? 0.25 : 1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _state(k) ?? (picked == k ? AppColors.blue : Colors.white24), width: 3),
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
          _card(Center(child: Text(q.q, style: const TextStyle(fontSize: 96)))),
          const SizedBox(height: 18),
          ..._textOptions(TextDirection.ltr),
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
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24, width: 2))),
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

  List<Widget> _textOptions(TextDirection? dir) => [
        for (var k = 0; k < q.options.length; k++)
          OptionTile(
            text: q.options[k],
            selected: picked == k,
            stateColor: _state(k),
            textDirection: dir ?? _dir(q.options[k]),
            onTap: checked ? null : () => setState(() => picked = k),
          ),
      ];

  Widget _feedback() {
    final c = ok ? AppColors.green : AppColors.red;
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
        Icon(ok ? Icons.check_circle : Icons.error, color: c, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ok ? tr(ui, 'دەستخۆش! 🎉', 'Super! 🎉', 'Great! 🎉') : '${tr(ui, 'بەرسڤا دروست:', 'Richtig:', 'Answer:')} $correct',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (q.explain.isNotEmpty)
              Text(q.explain, style: const TextStyle(color: Colors.white70)),
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
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colors.white70)),
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
                Text(extra!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppColors.gold)),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: BigButton(label: tr(ui, 'باشە', 'OK', 'OK'), onPressed: () => Navigator.pop(context)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
