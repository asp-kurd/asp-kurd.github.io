import 'dart:math';

import 'package:flutter/material.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/sfx.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'widgets/mascot.dart';
import 'widgets/record_button.dart';

/// شاشەیا وانەیێ: ٤ جۆرێن ڕاهێنانان
/// - وەرگێڕان (دایک ➔ فێربوون)
/// - وەرگێڕانا بەروڤاژی (فێربوون ➔ دایک)
/// - گوهداری (دەنگێ تە یان TTS)
/// - ئاخفتن (ب دەنگێ خۆ بێژە و بەراورد بکە)
/// - جووتکرن (٤ جووت)
/// - ئاڤاکرنا رستێ ژ پارچەیان
class InteractiveLessonScreen extends StatefulWidget {
  /// ئەگەر null بیت، ئەڤە وانەیا دووبارەکرنا خەلەتیانە
  final LessonUnit? unit;
  final List<WordConcept> concepts;
  const InteractiveLessonScreen({super.key, required this.unit, required this.concepts});

  @override
  State<InteractiveLessonScreen> createState() => _InteractiveLessonScreenState();
}

class _InteractiveLessonScreenState extends State<InteractiveLessonScreen> {
  final progress = ProgressService.instance;
  final voice = VoiceService.instance;
  final _rng = Random();
  final _watch = Stopwatch()..start();

  late final AppLanguage native = progress.nativeLang;
  late final AppLanguage target = progress.targetLang;

  late List<Exercise> queue;
  final Set<String> _requeued = {};
  int index = 0;
  int correctCount = 0;
  int totalInitial = 0;

  String? selected;
  bool checked = false;
  bool isCorrect = false;
  bool hasPracticeRecording = false;
  late List<String> options;

  // wordBank
  List<String> bankTiles = [];
  List<int> bankPicked = [];

  // match
  List<WordConcept> matchLeft = [], matchRight = [];
  String? matchSelLeft, matchSelRight;
  final Set<String> matched = {};
  String? matchWrong;
  bool matchHadMistake = false;

  // trueFalse
  WordConcept? tfCandidate;

  Exercise get current => queue[index];

  @override
  void initState() {
    super.initState();
    queue = _buildQueue();
    totalInitial = queue.length;
    _prepare();
  }

  @override
  void dispose() {
    voice.stopPlayback();
    progress.addStudyTime(_watch.elapsed);
    super.dispose();
  }

  static List<String> _words(String s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  List<Exercise> _buildQueue() {
    // جۆرێن جودا دا هەمی پرسیار وەکی ئێک نەبن
    const cycle = [
      ExerciseType.pickPicture,
      ExerciseType.translate,
      ExerciseType.listen,
      ExerciseType.trueFalse,
      ExerciseType.reverse,
      ExerciseType.pickPicture,
      ExerciseType.speak,
    ];
    final list = <Exercise>[];
    final concepts = [...widget.concepts]..shuffle(_rng);
    // دەستپێک ب یاریا جووتکرنێ
    if (concepts.length >= 4) {
      list.add(Exercise(concepts.first, ExerciseType.match, group: concepts.take(4).toList()));
    }
    for (var i = 0; i < concepts.length; i++) {
      final c = concepts[i];
      var type = cycle[i % cycle.length];
      if (type == ExerciseType.listen && (!voice.canSpeak(c, target) || progress.listenPaused)) type = ExerciseType.translate;
      if (type == ExerciseType.speak && progress.speakPaused) type = ExerciseType.reverse;
      if (type == ExerciseType.pickPicture && c.emoji.isEmpty) type = ExerciseType.reverse;
      // رستەیێن ٣+ پەیڤی ➔ ئاڤاکرنا رستێ
      if (type == ExerciseType.translate && _words(c.text(target)).length >= 3) type = ExerciseType.wordBank;
      list.add(Exercise(c, type));
    }
    return list;
  }

  void _prepare() {
    selected = null;
    checked = false;
    isCorrect = false;
    hasPracticeRecording = false;
    final ex = current;
    if (ex.type == ExerciseType.match) {
      matchLeft = [...ex.group]..shuffle(_rng);
      matchRight = [...ex.group]..shuffle(_rng);
      matchSelLeft = matchSelRight = matchWrong = null;
      matched.clear();
      matchHadMistake = false;
      options = [];
      return;
    }
    if (ex.type == ExerciseType.wordBank) {
      final correctWords = _words(ex.concept.text(target));
      final distractors = allConcepts
          .where((c) => c.id != ex.concept.id)
          .expand((c) => _words(c.text(target)))
          .where((w) => !correctWords.contains(w))
          .toSet()
          .toList()
        ..shuffle(_rng);
      bankTiles = [...correctWords, ...distractors.take(3)]..shuffle(_rng);
      bankPicked = [];
      options = [];
      return;
    }
    if (ex.type == ExerciseType.pickPicture) {
      // ٢، ٣، ٤ یان ٦ وێنە — نە هەردەم ٤
      const counts = [2, 3, 4, 4, 6];
      final n = counts[_rng.nextInt(counts.length)];
      final pics = <String>{ex.concept.pic};
      final others = [...allConcepts]..shuffle(_rng);
      // پێشی ژ هەمان قۆناغێ (زەحمەتتر)، پاشان ژ هەمییان
      final same = widget.concepts.where((c) => c.id != ex.concept.id).toList()..shuffle(_rng);
      for (final d in [...same, ...others]) {
        if (pics.length >= n) break;
        if (d.emoji.isNotEmpty) pics.add(d.pic);
      }
      options = pics.toList()..shuffle(_rng);
      return;
    }
    if (ex.type == ExerciseType.trueFalse) {
      // نیڤا جاران دروستە، نیڤا جاران پەیڤەکا دی
      final others = widget.concepts.length > 1 ? widget.concepts : allConcepts;
      final wrong = (others.where((c) => c.id != ex.concept.id).toList()..shuffle(_rng)).firstOrNull;
      tfCandidate = (_rng.nextBool() || wrong == null) ? ex.concept : wrong;
      options = ['yes', 'no'];
      return;
    }
    // زمانێ بەرسڤان
    final answerLang = ex.type == ExerciseType.translate ? target : native;
    final correct = ex.concept.text(answerLang);
    final pool = allConcepts.where((c) => c.id != ex.concept.id).map((c) => c.text(answerLang)).toSet().toList()
      ..shuffle(_rng);
    // ژمارا هەلبژارتنان دگوهۆڕیت: ٢–٤
    final n = 2 + _rng.nextInt(3);
    options = [correct, ...pool.take(n - 1)]..shuffle(_rng);

    if (ex.type == ExerciseType.listen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => voice.speak(ex.concept, target));
    }
  }

  /// 🙊 / 🔇 — ئەڤ پرسیارە و یێن وەکی وێ بۆ ٥ خولەکان ب جۆرەکێ دی دهێنە گوهۆڕین
  void _skipVoice(ExerciseType kind) {
    if (kind == ExerciseType.speak) {
      progress.pauseSpeak();
    } else {
      progress.pauseListen();
    }
    voice.stopPlayback();
    final replacement = kind == ExerciseType.speak ? ExerciseType.reverse : ExerciseType.translate;
    for (var k = index; k < queue.length; k++) {
      if (queue[k].type == kind) queue[k] = Exercise(queue[k].concept, replacement);
    }
    setState(_prepare);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr(
          native,
          kind == ExerciseType.speak ? 'باشە 👍 بۆ ٥ خولەکان پرسیارێن ئاخفتنێ نائێن.' : 'باشە 👍 بۆ ٥ خولەکان پرسیارێن گوهداریێ نائێن.',
          'Okay 👍 5 Minuten lang keine ${kind == ExerciseType.speak ? 'Sprech' : 'Hör'}übungen.',
          'Okay 👍 no ${kind == ExerciseType.speak ? 'speaking' : 'listening'} exercises for 5 minutes.')),
    ));
  }

  Widget _skipButton(ExerciseType kind) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            onPressed: checked ? null : () => _skipVoice(kind),
            icon: Text(kind == ExerciseType.speak ? '🙊' : '🔇', style: const TextStyle(fontSize: 18)),
            label: Text(kind == ExerciseType.speak
                ? tr(native, 'نوکە نەشێم باخڤم', 'Kann gerade nicht sprechen', "Can't speak now")
                : tr(native, 'نوکە نەشێم گوهداریێ بکەم', 'Kann gerade nicht hören', "Can't listen now")),
          ),
        ),
      );

  String get _correctAnswer => switch (current.type) {
        ExerciseType.pickPicture => current.concept.pic,
        ExerciseType.trueFalse => tfCandidate?.id == current.concept.id ? 'yes' : 'no',
        _ => current.concept
            .text(current.type == ExerciseType.translate || current.type == ExerciseType.wordBank ? target : native),
      };

  String _praiseText = '', _comfortText = '';

  Future<void> _check() async {
    final ex = current;
    _praiseText = native == AppLanguage.badini ? randomPraise() : tr(native, '', 'Super! 🎉', 'Great! 🎉');
    _comfortText = native == AppLanguage.badini ? randomComfort() : tr(native, '', 'Fast! 💪', 'Almost! 💪');
    final ok = switch (ex.type) {
      ExerciseType.speak => true,
      ExerciseType.match => !matchHadMistake,
      ExerciseType.wordBank => bankPicked.map((i) => bankTiles[i]).join(' ') == ex.concept.text(target),
      _ => selected == _correctAnswer,
    };
    setState(() {
      checked = true;
      isCorrect = ok;
    });
    if (ok) {
      Sfx.correct();
    } else {
      Sfx.wrong();
    }
    // پشتی پشکنینێ دەنگێ دروست لێدە
    if (ex.type != ExerciseType.listen && ex.type != ExerciseType.match) {
      Future.delayed(const Duration(milliseconds: 450), () => voice.speak(ex.concept, target));
    }

    if (ex.type == ExerciseType.match) {
      // جووتکرن: تنێ XP، بێ دووبارەکرن
      if (ok) correctCount++;
      return;
    }
    if (ex.type != ExerciseType.speak) await progress.recordAnswer(ex.concept.id, ok);
    if (ok) {
      correctCount++;
      await progress.clearMistake(ex.concept.id);
    } else {
      await progress.loseHeart();
      await progress.recordMistake(ex.concept.id);
      if (!_requeued.contains(ex.concept.id)) {
        _requeued.add(ex.concept.id);
        queue.add(Exercise(ex.concept, ExerciseType.translate));
      }
    }
  }

  Future<void> _continue() async {
    if (progress.hearts <= 0) {
      await _outOfHearts();
      return;
    }
    if (index + 1 < queue.length) {
      setState(() {
        index++;
        _prepare();
      });
    } else {
      await _finish();
    }
  }

  Future<void> _outOfHearts() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(native, 'دلێن تە نەمان 💔', 'Keine Herzen mehr 💔', 'Out of hearts 💔')),
        content: Text(tr(native, 'هەر خولەکەکێ دلەک ب خۆ دزڤڕیت ❤️ هندەکێ بێهنا خۆ ڤەدە و بزڤڕە!',
            'Jede Minute kommt ein Herz zurück ❤️', 'A heart comes back every minute ❤️')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _finish() async {
    final xp = 10 + correctCount * 2;
    final perfect = correctCount >= totalInitial;
    await progress.completeLesson(unitId: widget.unit?.id, earnedXp: xp, perfect: perfect);
    Sfx.done();
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _ResultScreen(xp: xp, perfect: perfect, lang: native)),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final ex = current;
    final canContinue = switch (ex.type) {
      ExerciseType.speak => hasPracticeRecording,
      ExerciseType.match => matched.length == ex.group.length,
      ExerciseType.wordBank => bankPicked.isNotEmpty,
      _ => selected != null,
    };

    return Directionality(
      textDirection: native.direction,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
          title: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (index + (checked ? 1 : 0)) / queue.length,
              minHeight: 12,
              backgroundColor: AppColors.card,
              valueColor: const AlwaysStoppedAnimation(AppColors.green),
            ),
          ),
          actions: [
            const Icon(Icons.favorite, color: AppColors.red),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListenableBuilder(
                listenable: progress,
                builder: (_, __) => Text('${progress.hearts}',
                    style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MascotSays(
                  mood: !checked
                      ? switch (ex.type) {
                          ExerciseType.listen => MascotMood.listen,
                          ExerciseType.speak => MascotMood.speak,
                          _ => MascotMood.ask,
                        }
                      : (isCorrect ? MascotMood.happy : MascotMood.sad),
                  text: !checked ? _instruction(ex.type) : (isCorrect ? _praiseText : _comfortText),
                  height: 104,
                  textDirection: native.direction,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (ex.type == ExerciseType.match)
                          _matchArea(ex)
                        else ...[
                          _promptCard(ex),
                          const SizedBox(height: 24),
                          if (ex.type == ExerciseType.speak) ...[
                            _speakArea(ex),
                            _skipButton(ExerciseType.speak),
                          ]
                          else if (ex.type == ExerciseType.pickPicture)
                            _pictureGrid()
                          else if (ex.type == ExerciseType.trueFalse)
                            _trueFalseButtons()
                          else if (ex.type == ExerciseType.wordBank)
                            _wordBankArea(ex)
                          else
                            ..._optionTiles(),
                          if (ex.type == ExerciseType.listen) _skipButton(ExerciseType.listen),
                        ],
                      ],
                    ),
                  ),
                ),
                if (checked) _feedback(ex),
                BigButton(
                  label: !checked
                      ? tr(native, 'پشکنین', 'Prüfen', 'CHECK')
                      : tr(native, 'بەردەوام بە', 'Weiter', 'CONTINUE'),
                  color: !checked ? AppColors.blue : (isCorrect ? AppColors.green : AppColors.red),
                  onPressed: !canContinue ? null : (checked ? _continue : _check),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _instruction(ExerciseType t) => switch (t) {
        ExerciseType.translate => tr(native, 'ئەڤێ وەرگێڕە بۆ ${target.title}:', 'Übersetze:', 'Translate this:'),
        ExerciseType.reverse => tr(native, 'رامانا ڤێ چییە؟', 'Was bedeutet das?', 'What does this mean?'),
        ExerciseType.listen => tr(native, 'گوهداری بکە و رامانێ هەلبژێرە 🎧', 'Hör zu und wähle die Bedeutung 🎧', 'Listen and pick the meaning 🎧'),
        ExerciseType.speak => tr(native, 'ب دەنگێ خۆ بێژە 🎤', 'Sprich es laut aus 🎤', 'Say it out loud 🎤'),
        ExerciseType.match => tr(native, 'جووتان پێکڤە گرێبدە 🔗', 'Finde die Paare 🔗', 'Match the pairs 🔗'),
        ExerciseType.wordBank => tr(native, 'رستێ ئاڤا بکە 🧩', 'Bilde den Satz 🧩', 'Build the sentence 🧩'),
        ExerciseType.pickPicture => tr(native, 'وێنەیێ دروست هەلبژێرە 🖼️', 'Wähle das richtige Bild 🖼️', 'Pick the right picture 🖼️'),
        ExerciseType.trueFalse => tr(native, 'ئەڤە دروستە یان خەلەتە؟', 'Richtig oder falsch?', 'True or false?'),
      };

  Widget _promptCard(Exercise ex) {
    final c = ex.concept;
    if (ex.type == ExerciseType.pickPicture || ex.type == ExerciseType.trueFalse) {
      final shown = ex.type == ExerciseType.trueFalse ? (tfCandidate ?? c) : c;
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12, width: 2),
        ),
        child: Column(children: [
          if (ex.type == ExerciseType.trueFalse) ...[
            Text(c.text(native), textDirection: native.direction, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: Colors.white70)),
            const SizedBox(height: 6),
            const Text('=', style: TextStyle(fontSize: 26, color: AppColors.gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
          ],
          Text(shown.text(target), textDirection: target.direction, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
          if (checked && ex.type == ExerciseType.pickPicture) ...[
            const SizedBox(height: 6),
            Text(c.text(native), textDirection: native.direction, style: const TextStyle(color: Colors.white60)),
          ],
          const SizedBox(height: 10),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => voice.speak(shown, target),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
            ),
          ),
        ]),
      );
    }
    final showNative = ex.type == ExerciseType.translate || ex.type == ExerciseType.wordBank;
    final isListen = ex.type == ExerciseType.listen;
    final mainLang = showNative ? native : target;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12, width: 2),
      ),
      child: Column(
        children: [
          if (isListen) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _soundButton(c, Icons.volume_up_rounded, 1.0, 72),
                const SizedBox(width: 16),
                _soundButton(c, Icons.slow_motion_video_rounded, 0.7, 52), // هێدی
              ],
            ),
            if (checked) ...[
              const SizedBox(height: 12),
              Text('${c.pic}  ${c.text(target)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ] else ...[
            if (c.emoji.isNotEmpty) ...[
              Text(c.pic, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 8),
            ],
            Text(
              c.text(mainLang),
              textDirection: mainLang.direction,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            if (ex.type == ExerciseType.speak) ...[
              Text(c.text(native), textDirection: native.direction, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 6),
            ],
            if (ex.type != ExerciseType.wordBank || checked)
              Text('💡 ${c.hint(target)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.blue)),
            if (!showNative && voice.canSpeak(c, target)) ...[
              const SizedBox(height: 10),
              _soundButton(c, Icons.volume_up_rounded, 1.0, 44),
            ],
          ],
        ],
      ),
    );
  }

  Widget _soundButton(WordConcept c, IconData icon, double rate, double size) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => voice.speak(c, target, rate: rate),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }

  List<Widget> _optionTiles() {
    final answerLang = current.type == ExerciseType.translate ? target : native;
    return options.map((o) {
      Color? state;
      if (checked && o == _correctAnswer) state = AppColors.green;
      if (checked && o == selected && !isCorrect) state = AppColors.red;
      return OptionTile(
        text: o,
        selected: selected == o,
        stateColor: state,
        textDirection: answerLang.direction,
        onTap: checked ? null : () => setState(() => selected = o),
      );
    }).toList();
  }

  /// 🖼️ تۆڕا وێنەیان (٢ / ٣ / ٤ / ٦)
  Widget _pictureGrid() {
    final n = options.length;
    final cols = n == 3 || n == 6 ? 3 : 2;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: n == 2 ? 1.0 : 1.0,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: checked ? null : () => setState(() => selected = o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: _pickColor(o).withValues(alpha: selected == o || (checked && o == _correctAnswer) ? 0.2 : 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _pickColor(o), width: 3),
              ),
              child: Center(child: Text(o, style: TextStyle(fontSize: cols == 3 ? 48 : 64))),
            ),
          ),
      ],
    );
  }

  Color _pickColor(String o) {
    if (checked && o == _correctAnswer) return AppColors.green;
    if (checked && o == selected) return AppColors.red;
    return selected == o ? AppColors.blue : Colors.white24;
  }

  /// ✅ / ❌
  Widget _trueFalseButtons() {
    Widget btn(String v, String emoji, String label) => Expanded(
          child: GestureDetector(
            onTap: checked ? null : () => setState(() => selected = v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: _pickColor(v).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _pickColor(v), width: 3),
              ),
              child: Column(children: [
                Text(emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        );
    return Row(children: [
      btn('yes', '✅', tr(native, 'دروستە', 'Richtig', 'True')),
      const SizedBox(width: 14),
      btn('no', '❌', tr(native, 'خەلەتە', 'Falsch', 'False')),
    ]);
  }

  Widget _speakArea(Exercise ex) {
    final practice = voice.practiceRecording;
    return Column(
      children: [
        RecordButton(
          size: 96,
          onStart: () => voice.startRecording(practice: true),
          onStop: () async {
            final p = await voice.stopRecording();
            if (p != null) {
              setState(() => hasPracticeRecording = true);
              await voice.playFile(p);
            }
          },
          hintText: tr(native, 'دەست ب سەر دا بگرە و باخڤە', 'Gedrückt halten und sprechen', 'Hold and speak'),
        ),
        const SizedBox(height: 16),
        if (hasPracticeRecording && practice != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => voice.playFile(practice),
                icon: const Icon(Icons.person_rounded),
                label: Text(tr(native, 'دەنگێ من', 'Meine', 'Mine')),
              ),
              const SizedBox(width: 12),
              if (voice.canSpeak(ex.concept, target))
                OutlinedButton.icon(
                  onPressed: () => voice.speak(ex.concept, target),
                  icon: const Icon(Icons.record_voice_over_rounded),
                  label: Text(tr(native, 'نموونە', 'Vorlage', 'Model')),
                ),
            ],
          ),
      ],
    );
  }

  // ───────── 🔗 جووتکرن ─────────
  Widget _matchArea(Exercise ex) {
    Widget tile(WordConcept c, AppLanguage lang, bool left) {
      final id = c.id;
      final isMatched = matched.contains(id);
      final isSel = left ? matchSelLeft == id : matchSelRight == id;
      final isWrong = matchWrong == '${left ? 'L' : 'R'}$id';
      return OptionTile(
        text: c.text(lang),
        selected: isSel,
        textDirection: lang.direction,
        stateColor: isMatched ? Colors.white12 : (isWrong ? AppColors.red : null),
        onTap: isMatched || checked
            ? null
            : () {
                if (!left) voice.speak(c, target);
                setState(() {
                  if (left) {
                    matchSelLeft = id;
                  } else {
                    matchSelRight = id;
                  }
                });
                _tryMatch();
              },
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: [for (final c in matchLeft) tile(c, native, true)])),
        const SizedBox(width: 12),
        Expanded(child: Column(children: [for (final c in matchRight) tile(c, target, false)])),
      ],
    );
  }

  Future<void> _tryMatch() async {
    final l = matchSelLeft, r = matchSelRight;
    if (l == null || r == null) return;
    if (l == r) {
      setState(() {
        matched.add(l);
        matchSelLeft = matchSelRight = null;
      });
      if (matched.length == current.group.length) await _check();
    } else {
      setState(() {
        matchWrong = 'R$r';
        matchHadMistake = true;
      });
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() {
        matchWrong = null;
        matchSelLeft = matchSelRight = null;
      });
    }
  }

  // ───────── 🧩 ئاڤاکرنا رستێ ─────────
  Widget _wordBankArea(Exercise ex) {
    Widget chip(int i, {required bool inAnswer}) => Padding(
          padding: const EdgeInsets.all(4),
          child: ActionChip(
            label: Text(bankTiles[i], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.card,
            side: const BorderSide(color: Colors.white24, width: 2),
            onPressed: checked
                ? null
                : () => setState(() {
                      if (inAnswer) {
                        bankPicked.remove(i);
                      } else {
                        bankPicked.add(i);
                      }
                    }),
          ),
        );

    return Directionality(
      textDirection: target.direction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // خەتێ بەرسڤێ
          Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white24, width: 2)),
            ),
            child: Wrap(children: [for (final i in bankPicked) chip(i, inAnswer: true)]),
          ),
          const SizedBox(height: 24),
          // پارچە
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < bankTiles.length; i++)
                if (!bankPicked.contains(i))
                  chip(i, inAnswer: false)
                else
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Opacity(
                      opacity: 0.15,
                      child: Chip(label: Text(bankTiles[i], style: const TextStyle(fontSize: 17))),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feedback(Exercise ex) {
    final color = isCorrect ? AppColors.green : AppColors.red;
    final msg = ex.type == ExerciseType.match
        ? (isCorrect
            ? tr(native, 'هەمی جووت دروستن! 🔗', 'Alle Paare richtig! 🔗', 'All pairs correct! 🔗')
            : tr(native, 'تەمام بوو — جارا بێت بێ خەلەتی 💪', 'Geschafft — nächstes Mal fehlerfrei 💪', 'Done — flawless next time 💪'))
        : isCorrect
        ? (ex.type == ExerciseType.speak
            ? tr(native, 'دەستخۆش! دەنگێ خۆ دگەل نموونەیێ بەراورد بکە.', 'Super! Vergleiche mit der Vorlage.', 'Nice! Compare with the model.')
            : tr(native, 'دەستخۆش! بەرسڤا تە دروستە.', 'Richtig!', 'Great job! Correct.'))
        : '${tr(native, 'بەرسڤا دروست:', 'Richtige Antwort:', 'Correct answer:')} ${switch (ex.type) {
            ExerciseType.trueFalse => '${ex.concept.text(target)} = ${ex.concept.text(native)}',
            ExerciseType.pickPicture => '${ex.concept.pic}  ${ex.concept.text(target)}',
            _ => _correctAnswer,
          }}';
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(isCorrect ? Icons.check_circle : Icons.error, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

/// شاشەیا ئەنجامێ — ئەگەر بێ خەلەتی بیت: وێنەیێ مامۆستای + کۆنفێتی 🎉
class _ResultScreen extends StatefulWidget {
  final int xp;
  final bool perfect;
  final AppLanguage lang;
  const _ResultScreen({required this.xp, required this.perfect, required this.lang});

  @override
  State<_ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<_ResultScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..forward();
  final _rng = Random();
  late final _bits = List.generate(28, (_) => (_rng.nextDouble(), _rng.nextDouble() * 0.6, ['🎉', '⭐', '✨', '🎊', '💯', '❤️'][_rng.nextInt(6)]));

  static const _perfectKu = [
    'تە هەمی بەرسڤ بێ خەلەتی دان! 🏆',
    'نایاب! ئێک خەلەتی ژی نەبوو 🌟',
    'تو قارەمانی! ١٠٠٪ دروست 💯',
    'دەستخۆش! مامۆستا شانازیێ ب تە دبەت 🎓',
    'سەد ژ سەدی! تو دبیە پرۆفیشناڵ 🚀',
  ];
  static const _doneKu = [
    'وانە تەمام بوو! 🎉 هەر وەسا بەردەوام بە',
    'دەستخۆش! هندەک خەلەتی هەبوون — جارا بێت بێ خەلەتی 💪',
    'باشە! ب دووبارەکرنێ دێ بێ خەلەتی بی 🌱',
  ];
  late final String _msg = widget.perfect
      ? (widget.lang == AppLanguage.badini ? _perfectKu[_rng.nextInt(_perfectKu.length)] : tr(widget.lang, '', 'Fehlerfrei! 🏆', 'Perfect — no mistakes! 🏆'))
      : (widget.lang == AppLanguage.badini ? _doneKu[_rng.nextInt(_doneKu.length)] : tr(widget.lang, '', 'Lektion geschafft! 🎉', 'Lesson complete! 🎉'));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Directionality(
      textDirection: lang.direction,
      child: Scaffold(
        body: Stack(children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _c, curve: const Interval(0, 0.25, curve: Curves.elasticOut)),
                    child: widget.perfect
                        ? Container(
                            width: 230,
                            height: 230,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.gold, width: 6),
                              boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 30)],
                              image: const DecorationImage(
                                  image: AssetImage(MascotChar.happyPhoto), fit: BoxFit.cover, alignment: Alignment(0, -0.6)),
                            ),
                          )
                        : Image.asset(MascotChar.forUser().front, height: 230),
                  ),
                  const SizedBox(height: 22),
                  if (widget.perfect)
                    const Text('🏆 ١٠٠٪', style: TextStyle(fontSize: 26, color: AppColors.gold, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    _msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, fontFamily: 'Sarchia', height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, color: AppColors.gold, size: 36),
                      Text('+${widget.xp} XP',
                          style: const TextStyle(fontSize: 28, color: AppColors.gold, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: BigButton(label: tr(lang, 'بەردەوام بە', 'Weiter', 'CONTINUE'), onPressed: () => Navigator.pop(context)),
                  ),
                ],
              ),
            ),
          ),
          if (widget.perfect)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final size = MediaQuery.sizeOf(context);
                  return Stack(children: [
                    for (final (x, delay, e) in _bits)
                      if (_c.value > delay)
                        Positioned(
                          left: x * size.width,
                          top: -40 + (size.height + 80) * ((_c.value - delay) / (1 - delay)),
                          child: Opacity(
                            opacity: (1 - _c.value).clamp(0.0, 1.0) * 0.9 + 0.1,
                            child: Text(e, style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                  ]);
                },
              ),
            ),
        ]),
      ),
    );
  }
}
