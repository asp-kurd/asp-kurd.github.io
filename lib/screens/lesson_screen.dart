import 'dart:math';

import 'package:flutter/material.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/voice_service.dart';
import '../ui.dart';
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
    super.dispose();
  }

  static List<String> _words(String s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  List<Exercise> _buildQueue() {
    const cycle = [ExerciseType.translate, ExerciseType.listen, ExerciseType.reverse, ExerciseType.speak];
    final list = <Exercise>[];
    final concepts = [...widget.concepts]..shuffle(_rng);
    // دەستپێک ب یاریا جووتکرنێ
    if (concepts.length >= 4) {
      list.add(Exercise(concepts.first, ExerciseType.match, group: concepts.take(4).toList()));
    }
    for (var i = 0; i < concepts.length; i++) {
      final c = concepts[i];
      var type = cycle[i % cycle.length];
      if (type == ExerciseType.listen && !voice.canSpeak(c, target)) type = ExerciseType.translate;
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
    // زمانێ بەرسڤان
    final answerLang = ex.type == ExerciseType.translate ? target : native;
    final correct = ex.concept.text(answerLang);
    final pool = allConcepts.where((c) => c.id != ex.concept.id).map((c) => c.text(answerLang)).toSet().toList()
      ..shuffle(_rng);
    options = [correct, ...pool.take(3)]..shuffle(_rng);

    if (ex.type == ExerciseType.listen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => voice.speak(ex.concept, target));
    }
  }

  String get _correctAnswer => current.concept
      .text(current.type == ExerciseType.translate || current.type == ExerciseType.wordBank ? target : native);

  Future<void> _check() async {
    final ex = current;
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
    // پشتی پشکنینێ دەنگێ دروست لێدە
    if (ex.type != ExerciseType.listen && ex.type != ExerciseType.match) voice.speak(ex.concept, target);

    if (ex.type == ExerciseType.match) {
      // جووتکرن: تنێ XP، بێ دووبارەکرن
      if (ok) correctCount++;
      return;
    }
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
        content: Text(tr(native, 'پشکا «دەنگێ من» پەیڤان تۆمار بکە دا دلان وەرگری.',
            'Nimm in „Meine Stimme“ Wörter auf, um Herzen zu bekommen.', 'Record words in My Voice to earn hearts.')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _finish() async {
    final xp = 10 + correctCount * 2;
    final perfect = correctCount >= totalInitial;
    await progress.completeLesson(unitId: widget.unit?.id, earnedXp: xp, perfect: perfect);
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
                Text(_instruction(ex.type),
                    style: const TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 18),
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
                          if (ex.type == ExerciseType.speak)
                            _speakArea(ex)
                          else if (ex.type == ExerciseType.wordBank)
                            _wordBankArea(ex)
                          else
                            ..._optionTiles(),
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
      };

  Widget _promptCard(Exercise ex) {
    final c = ex.concept;
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
              Text(c.text(target), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ] else ...[
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
        : '${tr(native, 'بەرسڤا دروست:', 'Richtige Antwort:', 'Correct answer:')} $_correctAnswer';
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

/// شاشەیا ئەنجامێ
class _ResultScreen extends StatelessWidget {
  final int xp;
  final bool perfect;
  final AppLanguage lang;
  const _ResultScreen({required this.xp, required this.perfect, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: lang.direction,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Text(perfect ? '🏆' : '🎉', style: const TextStyle(fontSize: 90)),
                const SizedBox(height: 16),
                Text(
                  perfect
                      ? tr(lang, 'بێ خەلەتی! تو قارەمانی', 'Fehlerfrei!', 'Perfect lesson!')
                      : tr(lang, 'وانە تەمام بوو!', 'Lektion geschafft!', 'Lesson complete!'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt, color: AppColors.gold, size: 36),
                    Text('+$xp XP', style: const TextStyle(fontSize: 28, color: AppColors.gold, fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}
