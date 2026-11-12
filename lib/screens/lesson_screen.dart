import 'dart:math';

import 'package:flutter/material.dart';

import '../data/cloze_bank.dart';
import '../data/curriculum.dart';
import '../data/pics.dart';
import '../data/pronouns.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/sfx.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'streak_screen.dart';
import 'widgets/combo.dart';
import 'widgets/reward_fx.dart';
import 'widgets/mascot.dart';
import 'widgets/record_button.dart';
import 'widgets/speak_check.dart';

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

  /// بۆ تاقیکرنێ: هەمی پرسیار ژ ئێک جۆری
  final ExerciseType? onlyType;

  /// 📌 بۆ کارێن مامۆستای (ئەزموونا دیاری / دووبارەکرن): ڕێژا ٪ پشتی تەمامبوونێ
  final void Function(int percent)? onDone;

  /// 🛤️ رێکا نوو: false ➔ قۆناغا کەڤن ب خۆ تەمام نابیت (وانە ب کۆرسان دهێتە هەژمارتن)
  final bool countUnit;

  /// 🏅 دووبارەکرنا زێڕ: پرسیارێن ب زەحمەتتر و تێکەل
  final bool hard;

  /// 🔁 وانەیەکا تەمامکری دووبارە دبیت ➔ XP ١ بۆ هەر بەرسڤەکا دروست
  final bool redo;

  /// 👤 پرسیارێن جهێناڤان (ئاست ٠–٥) و چەند پرسیار
  final int pronounTier, pronounCount;
  const InteractiveLessonScreen({
    super.key,
    required this.unit,
    required this.concepts,
    this.onlyType,
    this.onDone,
    this.countUnit = true,
    this.hard = false,
    this.redo = false,
    this.pronounTier = -1,
    this.pronounCount = 0,
  });

  @override
  State<InteractiveLessonScreen> createState() => _InteractiveLessonScreenState();
}

class _InteractiveLessonScreenState extends State<InteractiveLessonScreen> {
  final progress = ProgressService.instance;
  final voice = VoiceService.instance;
  final _rng = Random();
  final Set<String> _recentPics = <String>{}; // وێنەیێن پرسیارێن داوی — دا دووبارە نەبن
  final Map<String, WordConcept> _picConcepts = {};
  final _watch = Stopwatch()..start();

  late final AppLanguage native = progress.nativeLang;
  late final AppLanguage target = progress.targetLang;

  late List<Exercise> queue;
  final Set<String> _requeued = {};
  int index = 0;
  int correctCount = 0;
  int firstCorrect = 0;
  int answerXp = 0; // XP ژ بەرسڤان (ل دویف کۆمبۆیێ) // بەرسڤێن دروست ژ جارا ئێکێ (بۆ ڕێژا ٪)
  int totalInitial = 0;
  ClozeInfo? cz; // 📝 بۆ پرسیارا جهێ ڤالا

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
  final Set<String> matchWrong = {}; // 'L<id>' / 'R<id>' ➔ سۆر
  final Set<String> matchGreen = {}; // جووتێن دروست ➔ جارەکێ کەسک
  int matchMistakes = 0; // ٣ خەلەتی ➔ پرسیار دبۆریت
  final Set<String> matchMissed = {}; // پەیڤێن خەلەت ➔ ل دویماهیێ دزڤڕن
  bool get matchHadMistake => matchMistakes > 0;

  // trueFalse
  WordConcept? tfCandidate;

  Exercise get current => queue[index];

  @override
  void initState() {
    super.initState();
    queue = _buildQueue();
    // 👤 جهێناڤ: د ناڤ کۆرسێ دا بەلاڤ دبن (نە هەمی ل دوماهیێ)
    if (widget.pronounTier >= 0 && widget.pronounCount > 0 && widget.onlyType == null) {
      for (final q in pronounQuestions(target, widget.pronounTier, widget.pronounCount)) {
        queue.insert(1 + _rng.nextInt(queue.length), Exercise(q.concept, ExerciseType.cloze, cloze: q.cloze));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MascotChar.precache(context, MascotChar.forUser());
    });
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

  /// ریزبەندیا قۆناغێ د لیستێ دا (بۆ «ژ قۆناغا ٢٠ ڤە ٢ جهێن ڤالا»)
  int get _unitNo => widget.unit == null ? 99 : appCurriculum.indexWhere((u) => u.id == widget.unit!.id) + 1;

  List<Exercise> _buildQueue() {
    // جۆرێن جودا دا هەمی پرسیار وەکی ئێک نەبن
    const cycle = [
      ExerciseType.pickPicture,
      ExerciseType.translate,
      ExerciseType.cloze,
      ExerciseType.listen,
      ExerciseType.trueFalse,
      ExerciseType.reverse,
      ExerciseType.cloze,
      ExerciseType.speak,
    ];
    final list = <Exercise>[];
    // 🎲 ریزبەندی بۆ هەر فێرخوازەکی و هەر جارەکێ یا جودایە (هەمان ناڤەرۆک، جهێن جودا)
    final concepts = [...widget.concepts]..shuffle(_rng);
    if (widget.onlyType == ExerciseType.match && concepts.length >= 2) {
      return [Exercise(concepts.first, ExerciseType.match, group: concepts.take(4).toList())];
    }
    if (widget.onlyType == ExerciseType.cloze && widget.unit != null && clozeBankFor(widget.unit!.id, target).isNotEmpty) {
      return [
        for (final e in clozeBankFor(widget.unit!.id, target))
          Exercise(concepts.firstWhere((x) => x.id == e.conceptId, orElse: () => concepts.first), ExerciseType.cloze, cloze: e.info),
      ];
    }
    if (widget.onlyType != null) return [for (final c in concepts) Exercise(c, widget.onlyType!)];
    if (widget.hard) return _hardQueue(concepts);
    final offset = _rng.nextInt(cycle.length);
    for (var i = 0; i < concepts.length; i++) {
      final c = concepts[i];
      var type = cycle[(i + offset) % cycle.length];
      if (type == ExerciseType.listen && (!voice.canSpeak(c, target) || progress.listenPaused)) type = ExerciseType.translate;
      if (type == ExerciseType.speak && progress.speakPaused) type = ExerciseType.reverse;
      // 🖼️ پرسیارا وێنەیی تنێ بۆ پەیڤێن بەرچاڤ کو وێنەیێ وان هەیە
      if (type == ExerciseType.pickPicture && !hasPic(c)) type = ExerciseType.reverse;
      if (type == ExerciseType.cloze && _clozeFor(c) == null) type = ExerciseType.translate;
      // رستەیێن ٣+ پەیڤی ➔ ئاڤاکرنا رستێ
      if (type == ExerciseType.translate && _words(c.text(target)).length >= 3) type = ExerciseType.wordBank;
      list.add(Exercise(c, type));
    }
    // ئەگەر وێنە هەبن و چ پرسیارا وێنەیی نەبیت، ئێکێ زێدە بکە
    final withPic = concepts.where(hasPic).toList();
    if (withPic.isNotEmpty && !list.any((e) => e.type == ExerciseType.pickPicture)) {
      list.insert(_rng.nextInt(list.length + 1), Exercise(withPic[_rng.nextInt(withPic.length)], ExerciseType.pickPicture));
    }
    // 📝 رستەیێن جهێ ڤالا یێن زێدە ژ بانکێ — ژ قۆناغا ٢٠ ڤە ب ٢+ جهێن ڤالا ژی
    if (widget.unit != null) {
      final multiOk = _unitNo >= 20;
      final bank = clozeBankFor(widget.unit!.id, target).where((e) => multiOk || !e.multi).toList()..shuffle(_rng);
      if (multiOk) bank.sort((a, b) => (b.multi ? 1 : 0) - (a.multi ? 1 : 0)); // ئێک ب ٢ جهان ل پێشیێ
      final take = bank.take(3).toList()..shuffle(_rng);
      for (final e in take) {
        final c = concepts.firstWhere((x) => x.id == e.conceptId, orElse: () => concepts[_rng.nextInt(concepts.length)]);
        list.insert(1 + _rng.nextInt(list.length), Exercise(c, ExerciseType.cloze, cloze: e.info));
      }
    }
    // 🔗 جووتکرن: نە هەردەم ل دەستپێکێ
    if (concepts.length >= 4) {
      final pos = _rng.nextInt((list.length / 2).ceil() + 1);
      list.insert(pos, Exercise(concepts.first, ExerciseType.match, group: (concepts.toList()..shuffle(_rng)).take(4).toList()));
    }
    return list;
  }

  /// 🏅 زێڕ: هەر پەیڤەک دوو جاران ب شێوازێن ب زەحمەت (ئاڤاکرنا رستێ، گوهداری، جهێ ڤالا، ئاخفتن)
  List<Exercise> _hardQueue(List<WordConcept> concepts) {
    const hardCycle = [
      ExerciseType.translate,
      ExerciseType.listen,
      ExerciseType.cloze,
      ExerciseType.reverse,
      ExerciseType.translate,
      ExerciseType.speak,
      ExerciseType.cloze,
    ];
    final list = <Exercise>[];
    final off = _rng.nextInt(hardCycle.length);
    for (var pass = 0; pass < 2; pass++) {
      final cs = [...concepts]..shuffle(_rng);
      for (var i = 0; i < cs.length; i++) {
        final c = cs[i];
        var type = hardCycle[(i + off + pass * 3) % hardCycle.length];
        if (type == ExerciseType.listen && (!voice.canSpeak(c, target) || progress.listenPaused)) type = ExerciseType.translate;
        if (type == ExerciseType.speak && progress.speakPaused) type = ExerciseType.translate;
        if (type == ExerciseType.cloze && _clozeFor(c) == null) type = ExerciseType.translate;
        if (type == ExerciseType.translate && _words(c.text(target)).length >= 3) type = ExerciseType.wordBank;
        list.add(Exercise(c, type));
      }
    }
    if (widget.unit != null) {
      final bank = clozeBankFor(widget.unit!.id, target).toList()..shuffle(_rng);
      bank.sort((a, b) => (b.multi ? 1 : 0) - (a.multi ? 1 : 0)); // ٢ جهێن ڤالا ل پێشیێ
      for (final e in bank.take(3)) {
        final c = concepts.firstWhere((x) => x.id == e.conceptId, orElse: () => concepts[_rng.nextInt(concepts.length)]);
        list.insert(1 + _rng.nextInt(list.length), Exercise(c, ExerciseType.cloze, cloze: e.info));
      }
    }
    if (concepts.length >= 4) {
      list.insert(list.length ~/ 2, Exercise(concepts.first, ExerciseType.match, group: (concepts.toList()..shuffle(_rng)).take(5).toList()));
    }
    return list;
  }

  /// 📝 رستەکا ب جهێ ڤالا: ژ داتایێ (ئەلمانی)، یان ب خۆ ژ رستەیێن ٣+ پەیڤی
  ClozeInfo? _clozeFor(WordConcept c) {
    if (target == AppLanguage.german && c.cloze != null) return c.cloze;
    final fromBank = clozeForConcept(c.id, target);
    if (fromBank != null && (!fromBank.multi || _unitNo >= 20)) return fromBank.info;
    final text = c.text(target);
    final words = _words(text);
    if (words.length < 3) return null;
    String strip(String w) => w.replaceAll(RegExp(r'[^\p{L}\-]', unicode: true), '');
    final cands = words.map(strip).where((w) => w.length >= 3).toList()..sort((a, b) => b.length.compareTo(a.length));
    if (cands.isEmpty) return null;
    final answer = cands.first;
    final cap = answer[0] == answer[0].toUpperCase();
    final pool = <String>{
      for (final o in [...widget.concepts, ...allConcepts])
        if (o.id != c.id)
          for (final w in _words(o.text(target)).map(strip))
            if (w.length >= 3 && w != answer && !words.map(strip).contains(w) && (w[0] == w[0].toUpperCase()) == cap) w,
    }.toList();
    if (pool.length < 2) return null;
    // پێشی پەیڤێن نێزیکی درێژیێ (زەحمەتتر)
    pool.sort((a, b) => (a.length - answer.length).abs().compareTo((b.length - answer.length).abs()));
    final ds = pool.take(6).toList()..shuffle(_rng);
    final idx = text.indexOf(answer);
    final sentence = text.replaceRange(idx, idx + answer.length, '___');
    return ClozeInfo(sentence, answer, ds.take(2).toList(), c.text(native));
  }

  /// 🔇 هەر پرسیارەکا نوو ژمارەکا نوو: دەنگێ پرسیارا بەرێ ل سەر یا نوو لێنادەت
  int _qToken = 0;

  void _prepare() {
    _qToken++;
    voice.stopPlayback();
    selected = null;
    cz = null;
    checked = false;
    isCorrect = false;
    hasPracticeRecording = false;
    _speechPct = null;
    final ex = current;
    if (ex.type == ExerciseType.match) {
      matchLeft = [...ex.group]..shuffle(_rng);
      matchRight = [...ex.group]..shuffle(_rng);
      matchSelLeft = matchSelRight = null;
      matchWrong.clear();
      matchGreen.clear();
      matched.clear();
      matchMistakes = 0;
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
      // ٢، ٣، ٤ یان ٦ وێنەیێن 3D — تنێ پەیڤێن بەرچاڤ؛ هەلبژارتن = id یێن پەیڤان
      const counts = [2, 3, 4, 4, 6];
      final n = counts[_rng.nextInt(counts.length)];
      final usedPics = <String>{picName(ex.concept) ?? ''};
      final ids = <String>[ex.concept.id];
      final pool = <WordConcept>{
        ...widget.concepts.where(hasPic).toList()..shuffle(_rng),
        ...allConcepts.where(hasPic).toList()..shuffle(_rng),
        ...allUnitsRaw.expand((u) => u.concepts).where(hasPic).toList()..shuffle(_rng),
      };
      for (final pass in [0, 1]) {
        for (final d in pool) {
          if (ids.length >= n) break;
          final pn = picName(d)!;
          if (usedPics.contains(pn) || (pass == 0 && _recentPics.contains(pn))) continue;
          usedPics.add(pn);
          ids.add(d.id);
          _picConcepts[d.id] = d;
        }
      }
      _picConcepts[ex.concept.id] = ex.concept;
      options = ids..shuffle(_rng);
      _recentPics.addAll(usedPics.where((p) => p != picName(ex.concept)));
      while (_recentPics.length > 14) {
        _recentPics.remove(_recentPics.first);
      }
      return;
    }
    if (ex.type == ExerciseType.cloze) {
      final z = ex.cloze ?? _clozeFor(ex.concept) ?? ex.concept.cloze;
      if (z == null) {
        // نابیت ئەڤ پرسیارە ب جهێ ڤالا بیت ➔ وەرگێڕان
        queue[index] = Exercise(ex.concept, ExerciseType.translate);
        _prepare();
        return;
      }
      cz = z;
      options = [z.answer, ...z.distractors]..shuffle(_rng);
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
      final tok = _qToken;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && tok == _qToken) voice.speak(ex.concept, target);
      });
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
            style: TextButton.styleFrom(foregroundColor: AppColors.fg70, side: BorderSide(color: AppColors.fg24),
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
        ExerciseType.pickPicture => current.concept.id,
        ExerciseType.trueFalse => tfCandidate?.id == current.concept.id ? 'yes' : 'no',
        ExerciseType.cloze => cz?.answer ?? '',
        _ => current.concept
            .text(current.type == ExerciseType.translate || current.type == ExerciseType.wordBank ? target : native),
      };

  String _praiseText = '', _comfortText = '';

  Future<void> _check() async {
    final ex = current;
    _praiseText = native == AppLanguage.badini ? randomPraise() : tr(native, '', 'Super! 🎉', 'Great! 🎉');
    _comfortText = native == AppLanguage.badini ? randomComfort() : tr(native, '', 'Fast! 💪', 'Almost! 💪');
    final ok = switch (ex.type) {
      ExerciseType.speak => true, // 🗣️ ناسینا دەنگی ١٠٠٪ نینە: دل ناچن
      ExerciseType.match => matched.length == ex.group.length,
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
    // ⚡ کۆمبۆ + XP بۆ ڤێ بەرسڤێ
    var gained = ex.type == ExerciseType.speak ? ((_speechPct ?? 100) >= 50 ? 2 : 0) : progress.registerAnswer(ok);
    if (widget.redo && gained > 0) gained = 1; // 🔁 دووبارەکرن: XP ١ بۆ هەر بەرسڤەکێ
    answerXp += gained;
    if (gained > 0) showXpPop(context, gained, combo: progress.combo);
    if (ok && ex.type != ExerciseType.speak && progress.combo > 0 && progress.combo % 5 == 0) {
      Sfx.star();
      showComboToast(context, progress.combo, native);
    }
    if (ok && index < totalInitial && ex.type != ExerciseType.speak) firstCorrect++;
    if (ex.type == ExerciseType.speak && index < totalInitial) firstCorrect++;
    // پشتی پشکنینێ دەنگێ دروست لێدە
    // (تنێ ئەگەر بکارهێنەر هێشتا ل سەر هەمان پرسیارێ بیت)
    final tok = _qToken;
    bool still() => mounted && tok == _qToken;
    if (ex.type == ExerciseType.cloze && cz != null) {
      final full = clozeSpeech(cz!);
      Future.delayed(const Duration(milliseconds: 450), () {
        if (still()) voice.speakText(full, target);
      });
    } else if (ex.type != ExerciseType.listen && ex.type != ExerciseType.match) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (still()) voice.speak(ex.concept, target);
      });
    }

    if (ex.type == ExerciseType.match) {
      // جووتکرن: دل ناچن؛ پەیڤێن خەلەت ل دویماهیا قۆناغێ دزڤڕن (هەلبژارتن + د رستێ دا)
      if (ok) correctCount++;
      for (final id in matchMissed) {
        final c = ex.group.firstWhere((g) => g.id == id);
        await progress.recordMistake(id);
        if (_requeued.add(id)) {
          queue.add(Exercise(c, _rng.nextBool() ? ExerciseType.translate : ExerciseType.reverse));
          if (_clozeFor(c) != null) queue.add(Exercise(c, ExerciseType.cloze));
        }
      }
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
    final xp = (widget.redo ? 0 : 10) + answerXp;
    final percent = totalInitial == 0 ? 100 : (firstCorrect * 100 / totalInitial).round().clamp(0, 100);
    final perfect = percent >= 100;
    await progress.completeLesson(unitId: widget.countUnit ? widget.unit?.id : null, earnedXp: xp, perfect: perfect, percent: percent);
    widget.onDone?.call(percent);
    Sfx.done();
    if (!mounted) return;
    final unit = widget.unit, concepts = widget.concepts;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _ResultScreen(
          xp: xp,
          perfect: perfect,
          lang: native,
          percent: percent,
          correct: firstCorrect.clamp(0, totalInitial),
          total: totalInitial,
          onRetry: (ctx) => Navigator.pushReplacement(
              ctx,
              MaterialPageRoute(
                  builder: (_) => InteractiveLessonScreen(
                      unit: unit,
                      concepts: concepts,
                      countUnit: widget.countUnit,
                      hard: widget.hard,
                      redo: widget.redo || !widget.countUnit, // 🛤️ دووبارەکرنا هەمان کۆرسێ ➔ XP ١
                      pronounTier: widget.pronounTier,
                      pronounCount: widget.pronounCount,
                      onDone: widget.countUnit ? widget.onDone : null))),
        ),
      ),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final ex = current;
    final canContinue = switch (ex.type) {
      ExerciseType.speak => hasPracticeRecording,
      ExerciseType.match => checked,
      ExerciseType.wordBank => bankPicked.isNotEmpty,
      _ => selected != null,
    };

    return Directionality(
      textDirection: native.direction,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: Icon(Icons.close, color: AppColors.fg70), onPressed: () => Navigator.pop(context)),
          title: ListenableBuilder(
            listenable: progress,
            builder: (_, __) => Row(children: [
              Expanded(child: ComboBar(value: (index + (checked ? 1 : 0)) / queue.length, combo: progress.combo)),
              ComboBadge(combo: progress.combo),
            ]),
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
                  height: 140,
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
        ExerciseType.cloze => tr(native, 'جهێ ڤالا پڕ بکە دا رستە تەمام ببیت 📝', 'Ergänze die Lücke 📝', 'Fill in the blank 📝'),
      };

  Widget _promptCard(Exercise ex) {
    final c = ex.concept;
    if (ex.type == ExerciseType.cloze && cz != null) return _clozeCard(c, cz!);
    if (ex.type == ExerciseType.pickPicture || ex.type == ExerciseType.trueFalse) {
      final shown = ex.type == ExerciseType.trueFalse ? (tfCandidate ?? c) : c;
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.fg12, width: 2),
        ),
        child: Column(children: [
          if (ex.type == ExerciseType.trueFalse) ...[
            Text(c.text(native), textDirection: native.direction, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: AppColors.fg70)),
            const SizedBox(height: 6),
            Text('=', style: TextStyle(fontSize: 26, color: AppColors.goldText, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
          ],
          Text(shown.text(target), textDirection: target.direction, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
          if (checked && ex.type == ExerciseType.pickPicture) ...[
            const SizedBox(height: 6),
            Text(c.text(native), textDirection: native.direction, style: TextStyle(color: AppColors.fg60)),
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
        border: Border.all(color: AppColors.fg12, width: 2),
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
            if (c.emoji.isNotEmpty || hasPic(c)) ...[
              ConceptPic(c, size: hasPic(c) ? 96 : 72),
              const SizedBox(height: 8),
            ],
            Text(
              c.text(mainLang),
              textDirection: mainLang.direction,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.fg),
            ),
            const SizedBox(height: 10),
            if (ex.type == ExerciseType.speak) ...[
              Text(c.text(native), textDirection: native.direction, style: TextStyle(color: AppColors.fg60)),
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

  /// 📝 رستە ب جهێ ڤالا: «Ich esse einen [____].» + وەرگێڕان
  Widget _clozeCard(WordConcept c, ClozeInfo z) {
    final fill = checked ? z.answer : selected;
    final parts = z.sentence.split('___');
    final fills = (fill ?? '').split(' … ');
    final spans = <InlineSpan>[];
    for (var k = 0; k < parts.length; k++) {
      spans.add(TextSpan(text: parts[k]));
      if (k < parts.length - 1) {
        final word = fill == null ? null : (k < fills.length ? fills[k] : fills.last);
        final color = !checked ? AppColors.blue : (isCorrect ? AppColors.green : AppColors.red);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            constraints: const BoxConstraints(minWidth: 70),
            decoration: BoxDecoration(
              color: word == null ? Colors.transparent : color.withValues(alpha: 0.18),
              border: Border.all(color: word == null ? AppColors.fg38 : color, width: 2.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(word ?? ' ', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: word == null ? null : color)),
          ),
        ));
      }
    }
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fg12, width: 2),
      ),
      child: Column(children: [
        if (current.cloze == null && (c.emoji.isNotEmpty || hasPic(c))) ConceptPic(c, size: hasPic(c) ? 80 : 60),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: spans),
            textDirection: target.direction,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, height: 1.7, color: AppColors.fg)),
        const SizedBox(height: 10),
        Text('💬 ${z.ku}', textDirection: native.direction, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.fg60)),
      ]),
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
    final answerLang = current.type == ExerciseType.translate || current.type == ExerciseType.cloze ? target : native;
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
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Center(
                  child: _picConcepts[o] == null
                      ? const SizedBox()
                      : ConceptPic(_picConcepts[o]!, size: cols == 3 ? 84 : 120),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _pickColor(String o) {
    if (checked && o == _correctAnswer) return AppColors.green;
    if (checked && o == selected) return AppColors.red;
    return selected == o ? AppColors.blue : AppColors.fg24;
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

  int? _speechPct; // 🗣️ ئەنجاما ناسینا گۆتنێ

  Widget _speakArea(Exercise ex) {
    if (speechSupported && target.ttsCode != null) {
      return SpeakCheck(
        key: ValueKey('speak_$index'),
        target: ex.concept.text(target),
        lang: target,
        onResult: (sc) => setState(() {
          _speechPct = sc.percent;
          hasPracticeRecording = true;
        }),
      );
    }
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
      final isWrong = matchWrong.contains('${left ? 'L' : 'R'}$id');
      final isGreen = matchGreen.contains(id);
      return OptionTile(
        text: c.text(lang),
        selected: isSel,
        textDirection: lang.direction,
        stateColor: isGreen ? AppColors.green : (isMatched ? AppColors.fg12 : (isWrong ? AppColors.red : null)),
        onTap: isMatched || checked || matchWrong.isNotEmpty
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

  /// ✅ جووتێ دروست: جارەکێ کەسک دبیت · ❌ خەلەت: هەردوو سۆر دبن (١ و ٢ چ نابیت)،
  /// جارا ٣ێ پرسیار دبۆریت و پەیڤێن خەلەت ل دویماهیا قۆناغێ دزڤڕن
  Future<void> _tryMatch() async {
    final l = matchSelLeft, r = matchSelRight;
    if (l == null || r == null) return;
    if (l == r) {
      Sfx.correct();
      setState(() {
        matched.add(l);
        matchGreen.add(l);
        matchSelLeft = matchSelRight = null;
      });
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => matchGreen.remove(l));
      });
      if (matched.length == current.group.length) await _check();
    } else {
      Sfx.wrong();
      setState(() {
        matchWrong
          ..add('L$l')
          ..add('R$r');
        matchMistakes++;
        matchMissed
          ..add(l)
          ..add(r);
      });
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        matchWrong.clear();
        matchSelLeft = matchSelRight = null;
      });
      if (matchMistakes >= 3 && !checked) await _check();
    }
  }

  // ───────── 🧩 ئاڤاکرنا رستێ ─────────
  Widget _wordBankArea(Exercise ex) {
    Widget chip(int i, {required bool inAnswer}) => Padding(
          padding: const EdgeInsets.all(4),
          child: ActionChip(
            label: Text(bankTiles[i], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.card,
            side: BorderSide(color: AppColors.fg24, width: 2),
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
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.fg24, width: 2)),
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
            ? (matchHadMistake
                ? tr(native, 'تەمام بوو! ئەو پەیڤێن تە خەلەت کرین ل دویماهیێ دێ زڤڕن 💪', 'Geschafft! Deine Fehler kommen am Ende wieder 💪',
                    'Done! The ones you missed come back at the end 💪')
                : tr(native, 'هەمی جووت دروستن! 🔗', 'Alle Paare richtig! 🔗', 'All pairs correct! 🔗'))
            : tr(native, '٣ خەلەتی — ئەڤ پەیڤە ل دویماهیا قۆناغێ دێ زڤڕن دا باش فێر ببی', '3 Fehler — diese Wörter kommen am Ende wieder',
                '3 mistakes — these words come back at the end'))
        : isCorrect
        ? (ex.type == ExerciseType.speak
            ? tr(native, 'دەستخۆش! دەنگێ خۆ دگەل نموونەیێ بەراورد بکە.', 'Super! Vergleiche mit der Vorlage.', 'Nice! Compare with the model.')
            : tr(native, 'دەستخۆش! بەرسڤا تە دروستە.', 'Richtig!', 'Great job! Correct.'))
        : '${tr(native, 'بەرسڤا دروست:', 'Richtige Antwort:', 'Correct answer:')} ${switch (ex.type) {
            ExerciseType.trueFalse => '${ex.concept.text(target)} = ${ex.concept.text(native)}',
            ExerciseType.pickPicture => '${ex.concept.pic}  ${ex.concept.text(target)}',
            ExerciseType.cloze => cz == null ? _correctAnswer : cz!.filled(cz!.answer),
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
  final int percent, correct, total;
  final void Function(BuildContext context) onRetry;
  const _ResultScreen({
    required this.xp,
    required this.perfect,
    required this.lang,
    required this.percent,
    required this.correct,
    required this.total,
    required this.onRetry,
  });

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
  void initState() {
    super.initState();
    // 🪙 خەلاتێن ڤێ وانێ (پشتی ئەنیمەیشنا ئەنجامێ)
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) showPendingRewards(context);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// ⭕ ڕێژا بەرسڤێن دروست ژ ١٠٠٪
  Widget _scoreRing(AppLanguage lang) {
    final p = widget.percent;
    final color = p >= 100 ? AppColors.gold : (p >= 80 ? AppColors.green : (p >= 50 ? AppColors.orange : AppColors.red));
    String kn(int n) => lang == AppLanguage.badini
        ? n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join()
        : '$n';
    return Column(children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: p / 100),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => SizedBox(
          width: 120,
          height: 120,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 11,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.fg12,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Text('${kn((v * 100).round())}٪', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        tr(lang, '${kn(widget.correct)} ژ ${kn(widget.total)} بەرسڤ دروست بوون', '${widget.correct} von ${widget.total} richtig',
            '${widget.correct} of ${widget.total} correct'),
        style: TextStyle(fontSize: 16, color: AppColors.fg70),
      ),
    ]);
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
                        ? _PerfectHero(char: MascotChar.forUser())
                        : MascotView(char: MascotChar.forUser(), mood: MascotMood.happy, height: 190),
                  ),
                  const SizedBox(height: 18),
                  _scoreRing(lang),
                  const SizedBox(height: 10),
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
                          style: TextStyle(fontSize: 28, color: AppColors.goldText, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: BigButton(
                      label: tr(lang, 'بەردەوام بە', 'Weiter', 'CONTINUE'),
                      onPressed: () async {
                        if (!await maybeShowStreak(context, replace: true) && context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.blue, width: 2),
                        foregroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => widget.onRetry(context),
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(
                        widget.perfect
                            ? tr(lang, 'جارەکا دی بکە 🔁', 'Nochmal üben 🔁', 'Practice again 🔁')
                            : tr(lang, 'دووبارە بکە دا بگەهییە ١٠٠٪ 🔁', 'Wiederholen für 100% 🔁', 'Retry for 100% 🔁'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
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


/// 🏆 وانەیا بێ خەلەتی: کاراکتەر ب کەیف بازددەت (هەمی لەش)
class _PerfectHero extends StatefulWidget {
  final MascotChar char;
  const _PerfectHero({required this.char});
  @override
  State<_PerfectHero> createState() => _PerfectHeroState();
}

class _PerfectHeroState extends State<_PerfectHero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final j = sin(_c.value * pi);
          return Transform.translate(
            offset: Offset(0, -30 * j),
            child: Transform.scale(scaleY: 1 + 0.04 * j, scaleX: 1 - 0.03 * j, alignment: Alignment.bottomCenter, child: child),
          );
        },
        child: Container(
          decoration: BoxDecoration(boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 40)]),
          child: Image.asset(widget.char.happyFull, height: 200),
        ),
      );
}

// ═════════════════════════ 🔤 وانا پیتان ═════════════════════════
/// پرسیارێن تایبەت بۆ فێربوونا پیتان:
/// - پیت + خواندنا وێ (C = «تسێ») سەرەکییە؛ نموونە (Computer) پشتی بەرسڤێ ل بن هەمییان دیار دبیت.
/// - هەلبژارتنا خەلەت ➔ سۆر دبیت و «دیسا هەول بدە» — دل و XP ناچن.
/// - ئەگەر ٣ ژ ٤ هەلبژارتنان خەلەت بن ➔ چ XP نینە و ئەو پیت ل دوماهیا قۆناغێ دووبارە دبیت.
enum _LetterQ { nameToLetter, listenToLetter, letterToName, wordToLetter }

class LetterLessonScreen extends StatefulWidget {
  final LessonUnit unit;
  final bool countUnit;
  final void Function(int percent)? onDone;
  const LetterLessonScreen({super.key, required this.unit, this.countUnit = true, this.onDone});

  @override
  State<LetterLessonScreen> createState() => _LetterLessonScreenState();
}

class _LetterLessonScreenState extends State<LetterLessonScreen> {
  final progress = ProgressService.instance;
  final voice = VoiceService.instance;
  final _rng = Random();
  final _watch = Stopwatch()..start();
  late final AppLanguage native = progress.nativeLang;
  late final AppLanguage target = progress.targetLang;

  late final List<WordConcept> letters = widget.unit.concepts.where((c) => c.letter != null).toList();
  late final List<WordConcept> pool = {
    ...letters,
    ...allConcepts.where((c) => c.letter != null && c.id.startsWith('${letters.first.id.split('_').first}_')),
  }.toList();

  late List<(WordConcept, _LetterQ)> queue;
  int index = 0, firstTry = 0, total = 0, answerXp = 0;
  final Set<String> _requeued = {};
  final Set<String> _recent = <String>{}; // وێنەیێن پرسیارێن داوی

  List<WordConcept> options = [];
  final Set<String> wrong = {};
  bool solved = false;
  int _tok = 0;

  (WordConcept, _LetterQ) get cur => queue[index];

  @override
  void initState() {
    super.initState();
    final ls = [...letters]..shuffle(_rng);
    const types = _LetterQ.values;
    queue = [for (var k = 0; k < ls.length; k++) (ls[k], types[k % types.length])];
    total = queue.length;
    _prepare();
  }

  @override
  void dispose() {
    voice.stopPlayback();
    progress.addStudyTime(_watch.elapsed);
    super.dispose();
  }

  void _prepare() {
    _tok++;
    voice.stopPlayback();
    wrong.clear();
    solved = false;
    final c = cur.$1;
    final others = pool.where((o) => o.id != c.id && o.letter!.upper != c.letter!.upper).toList()..shuffle(_rng);
    // نە هەمان ٤ وێنە د پرسیارێن ل دویف ئێک دا: پێشی ئەوێن نوکە نەهاتین
    others.sort((a, b) => (_recent.contains(a.id) ? 1 : 0) - (_recent.contains(b.id) ? 1 : 0));
    options = [c, ...others.take(3)]..shuffle(_rng);
    _recent.addAll(options.map((o) => o.id));
    while (_recent.length > (pool.length - 4).clamp(4, 12)) {
      _recent.remove(_recent.first);
    }
    if (cur.$2 == _LetterQ.listenToLetter || cur.$2 == _LetterQ.nameToLetter) {
      final t = _tok;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && t == _tok) _sayLetter(c);
      });
    }
  }

  void _sayLetter(WordConcept c, [double rate = 1.0]) => voice.speakText(c.letter!.upper, target, rate: rate);
  void _sayWord(WordConcept c) => voice.speak(c, target);

  Future<void> _pick(WordConcept o) async {
    if (solved || wrong.contains(o.id)) return;
    final c = cur.$1;
    if (o.id != c.id) {
      Sfx.wrong();
      setState(() => wrong.add(o.id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 1400),
          backgroundColor: AppColors.red,
          content: Text(tr(native, '❌ خەلەتە — دیسا هەول بدە', '❌ Falsch – versuch es nochmal', '❌ Wrong – try again'),
              textDirection: native.direction, style: const TextStyle(fontWeight: FontWeight.bold)),
        ));
      if (wrong.length >= 3) {
        // ٣ ژ ٤ خەلەت: چ XP نینە، و ل دوماهیێ دووبارە دبیت
        setState(() => solved = true);
        progress.registerAnswer(false);
        if (!_requeued.contains(c.id)) {
          _requeued.add(c.id);
          final next = _LetterQ.values[(cur.$2.index + 1) % _LetterQ.values.length];
          queue.add((c, next));
        }
        final t = _tok;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && t == _tok) _sayWord(c);
        });
      }
      return;
    }
    Sfx.correct();
    setState(() => solved = true);
    int gained;
    if (wrong.isEmpty) {
      gained = progress.registerAnswer(true);
      if (index < total) firstTry++;
    } else {
      progress.registerAnswer(false); // کۆمبۆ ب دوماهی دهێت، بەلێ XP ناچیت
      gained = 1;
    }
    answerXp += gained;
    if (gained > 0) showXpPop(context, gained, combo: progress.combo);
    final t = _tok;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted && t == _tok) _sayWord(c);
    });
  }

  Future<void> _continue() async {
    if (index + 1 < queue.length) {
      setState(() {
        index++;
        _prepare();
      });
      return;
    }
    final xp = 10 + answerXp;
    final percent = total == 0 ? 100 : (firstTry * 100 / total).round().clamp(0, 100);
    await progress.completeLesson(unitId: widget.countUnit ? widget.unit.id : null, earnedXp: xp, perfect: percent >= 100, percent: percent);
    widget.onDone?.call(percent);
    Sfx.done();
    if (!mounted) return;
    final unit = widget.unit;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _ResultScreen(
          xp: xp,
          perfect: percent >= 100,
          lang: native,
          percent: percent,
          correct: firstTry.clamp(0, total),
          total: total,
          onRetry: (ctx) => Navigator.pushReplacement(
              ctx, MaterialPageRoute(builder: (_) => LetterLessonScreen(unit: unit, countUnit: widget.countUnit))),
        ),
      ),
    );
  }

  String get _instruction => switch (cur.$2) {
        _LetterQ.nameToLetter => tr(native, 'کیژ پیت ب ڤی رەنگی دهێتە خواندن؟', 'Welcher Buchstabe ist das?', 'Which letter is this?'),
        _LetterQ.listenToLetter => tr(native, 'گوهداری بکە 🎧 — کیژ پیتە؟', 'Hör zu 🎧 – welcher Buchstabe?', 'Listen 🎧 – which letter?'),
        _LetterQ.letterToName => tr(native, 'ئەڤ پیتە چەوا دهێتە خواندن؟', 'Wie spricht man den Buchstaben?', 'How do you say this letter?'),
        _LetterQ.wordToLetter => tr(native, 'ئەڤ پەیڤە ب کیژ پیتێ دەستپێدکەت؟', 'Mit welchem Buchstaben beginnt das Wort?', 'Which letter does it start with?'),
      };

  @override
  Widget build(BuildContext context) {
    final c = cur.$1, q = cur.$2;
    final l = c.letter!;
    final color = widget.unit.color;
    return Directionality(
      textDirection: native.direction,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: Icon(Icons.close, color: AppColors.fg70), onPressed: () => Navigator.pop(context)),
          title: ListenableBuilder(
            listenable: progress,
            builder: (_, __) => Row(children: [
              Expanded(child: ComboBar(value: (index + (solved ? 1 : 0)) / queue.length, combo: progress.combo)),
              ComboBadge(combo: progress.combo),
            ]),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              MascotSays(
                mood: !solved ? (wrong.isEmpty ? MascotMood.ask : MascotMood.think) : (wrong.length >= 3 ? MascotMood.sad : MascotMood.happy),
                text: !solved
                    ? (wrong.isEmpty ? _instruction : tr(native, 'نێزیکە! دیسا هەول بدە 💪', 'Fast! Nochmal 💪', 'Close! Try again 💪'))
                    : (wrong.length >= 3
                        ? tr(native, 'ئەڤ پیتە دێ ل دوماهیێ دووبارە بیت 🔁', 'Kommt am Ende nochmal 🔁', 'This one comes back at the end 🔁')
                        : (native == AppLanguage.badini ? randomPraise() : 'Super! 🎉')),
                height: 120,
                textDirection: native.direction,
              ),
              const SizedBox(height: 10),
              // ───── پرسیار ─────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.fg12, width: 2)),
                child: Column(children: [
                  if (q == _LetterQ.nameToLetter) ...[
                    Text('«${l.name}»', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.goldText)),
                    const SizedBox(height: 8),
                    _sound(() => _sayLetter(c), 46),
                  ],
                  if (q == _LetterQ.listenToLetter)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _sound(() => _sayLetter(c), 72),
                      const SizedBox(width: 14),
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _sayLetter(c, 0.7),
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Center(child: Text('🐢', style: TextStyle(fontSize: 24))),
                        ),
                      ),
                    ]),
                  if (q == _LetterQ.letterToName) ...[
                    Text('${l.upper} ${l.lower}', textDirection: TextDirection.ltr,
                        style: const TextStyle(fontFamily: 'Roboto', fontSize: 64, fontWeight: FontWeight.w900, height: 1.1)),
                  ],
                  if (q == _LetterQ.wordToLetter) ...[
                    Text(c.pic, style: const TextStyle(fontSize: 52)),
                    Text(l.word, textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'Roboto', fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _sound(() => _sayWord(c), 44),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              // ───── هەلبژارتن ─────
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: solved ? 1.05 : 1.35,
                  children: [for (final o in options) _option(o, q, color)],
                ),
              ),
              if (solved)
                BigButton(
                  label: tr(native, 'بەردەوام بە', 'Weiter', 'CONTINUE'),
                  color: wrong.length >= 3 ? AppColors.red : AppColors.green,
                  onPressed: _continue,
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sound(VoidCallback onTap, double size) => InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
          child: Icon(Icons.volume_up_rounded, color: Colors.white, size: size * 0.55),
        ),
      );

  Widget _option(WordConcept o, _LetterQ q, Color accent) {
    final l = o.letter!;
    final isAnswer = o.id == cur.$1.id;
    final isWrong = wrong.contains(o.id);
    final Color border = isWrong ? AppColors.red : (solved && isAnswer ? AppColors.green : AppColors.fg24);
    final main = q == _LetterQ.letterToName ? '«${l.name}»' : '${l.upper} ${l.lower}';
    return GestureDetector(
      onTap: () {
        if (solved) {
          _sayWord(o); // پشتی بەرسڤێ: گوهداریا نموونەیا هەر پیتەکێ
        } else {
          _pick(o);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: border.withValues(alpha: isWrong || (solved && isAnswer) ? 0.16 : 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 3),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(main,
              textDirection: q == _LetterQ.letterToName ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                  fontFamily: q == _LetterQ.letterToName ? null : 'Roboto',
                  fontSize: q == _LetterQ.letterToName ? 26 : 38,
                  fontWeight: FontWeight.w900,
                  color: isWrong ? AppColors.red : (solved && isAnswer ? AppColors.green : AppColors.fg))),
          // پشتی بەرسڤێ: نموونە ل بن هەمی هەلبژارتنان
          if (solved) ...[
            const SizedBox(height: 4),
            Text(q == _LetterQ.letterToName ? '${l.upper} ${l.lower}' : '«${l.name}»',
                textDirection: q == _LetterQ.letterToName ? TextDirection.ltr : TextDirection.rtl,
                style: TextStyle(fontSize: 15, color: AppColors.goldText, fontWeight: FontWeight.bold)),
            Text('${o.pic} ${l.word}', textDirection: TextDirection.ltr, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: AppColors.fg70)),
          ],
        ]),
      ),
    );
  }
}
