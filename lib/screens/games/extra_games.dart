import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/curriculum.dart';
import '../../models.dart';
import '../../services/backend.dart';
import '../../services/progress_service.dart';
import '../../services/sfx.dart';
import '../../services/voice_service.dart';
import '../../ui.dart';
import '../widgets/combo.dart' show showXpPop;
import '../widgets/mascot.dart';
import 'game_session.dart';

String _ku(int n) => n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();

/// پەردەیا دوماهیێ یا یاریان
class _GameDone extends StatelessWidget {
  final int correct, total, xp;
  final VoidCallback onAgain;
  const _GameDone({required this.correct, required this.total, required this.xp, required this.onAgain});

  @override
  Widget build(BuildContext context) {
    final good = correct >= total * 0.8;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          MascotView(char: MascotChar.forUser(), mood: good ? MascotMood.happy : MascotMood.think, height: 170),
          const SizedBox(height: 14),
          Text('${_ku(correct)} ژ ${_ku(total)} دروست', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          if (xp > 0) Text('+$xp XP', style: TextStyle(fontSize: 20, color: AppColors.goldText, fontWeight: FontWeight.bold)),
          const SizedBox(height: 22),
          BigButton(label: 'دیسا یاری بکە 🔁', onPressed: onAgain),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('زڤڕین')),
        ]),
      ),
    );
  }
}

// ═════════════════════════ 🎨 der / die / das ═════════════════════════
class ArticleGameScreen extends StatefulWidget {
  const ArticleGameScreen({super.key});
  @override
  State<ArticleGameScreen> createState() => _ArticleGameScreenState();
}

class _ArticleGameScreenState extends State<ArticleGameScreen> {
  static final _re = RegExp(r'^(der|die|das) ([A-ZÄÖÜ][^\s,.;·]*)$');
  static const _colors = {'der': AppColors.blue, 'die': AppColors.red, 'das': AppColors.green};
  final _rng = Random();
  late List<WordConcept> round;
  int i = 0, correct = 0, xp = 0, streak = 0;
  String? picked;
  bool done = false;

  static List<WordConcept> get nouns => allConcepts.where((c) => _re.hasMatch(c.de.trim())).toList();

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final all = nouns..shuffle(_rng);
    // پێشی ئەو ناڤێن تە خەلەت کرین
    final weak = all.where((c) => (ProgressService.instance.mistakes[c.id] ?? 0) > 0).toList();
    round = {...weak.take(6), ...all}.take(20).toList()..shuffle(_rng);
    setState(() {
      i = correct = xp = streak = 0;
      picked = null;
      done = false;
    });
  }

  (String, String) _split(WordConcept c) {
    final m = _re.firstMatch(c.de.trim())!;
    return (m.group(1)!, m.group(2)!);
  }

  Future<void> _pick(String a) async {
    if (picked != null) return;
    final (art, _) = _split(round[i]);
    final ok = a == art;
    setState(() => picked = a);
    if (ok) {
      Sfx.correct();
      correct++;
      streak++;
      final g = streak >= 5 ? 3 : 2;
      xp += g;
      showXpPop(context, g);
    } else {
      Sfx.wrong();
      streak = 0;
    }
    await ProgressService.instance.recordAnswer(round[i].id, ok);
    if (!ok) await ProgressService.instance.recordMistake(round[i].id);
    VoiceService.instance.speak(round[i], AppLanguage.german);
    await Future.delayed(Duration(milliseconds: ok ? 900 : 1700));
    if (!mounted) return;
    if (i + 1 < round.length) {
      setState(() {
        i++;
        picked = null;
      });
    } else {
      if (xp > 0) await ProgressService.instance.earn(xp);
      setState(() => done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🎨 der · die · das'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(value: done ? 1 : i / round.length, minHeight: 6, backgroundColor: AppColors.card),
          ),
        ),
        body: SafeArea(child: done ? _GameDone(correct: correct, total: round.length, xp: xp, onAgain: _start) : _play()),
      ),
    );
  }

  Widget _play() {
    final c = round[i];
    final (art, noun) = _split(c);
    final col = picked == null ? AppColors.fg : _colors[art]!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Text('ئارتیکلێ دروست هەلبژێرە', style: TextStyle(color: AppColors.fg60, fontSize: 16)),
        if (streak >= 3) Text('🔥 ${_ku(streak)} ل دویف ئێک', style: TextStyle(color: AppColors.goldText, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (c.emoji.isNotEmpty) Text(c.pic, style: const TextStyle(fontSize: 80)),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: picked == null ? '___ ' : '$art ', style: TextStyle(color: col)),
              TextSpan(text: noun),
            ]),
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 6),
        Text(c.ku.replaceFirst(RegExp(r'^.*·\s*'), ''), style: TextStyle(fontSize: 18, color: AppColors.fg60)),
        if (picked != null && picked != art)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('❌ دروست: $art $noun', textDirection: TextDirection.rtl, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        const Spacer(),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            for (final a in ['der', 'die', 'das']) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => _pick(a),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 86,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _colors[a]!.withValues(alpha: picked == null ? 0.9 : (a == art ? 1 : (a == picked ? 0.35 : 0.2))),
                      borderRadius: BorderRadius.circular(20),
                      border: picked != null && a == art ? Border.all(color: Colors.white, width: 3) : null,
                    ),
                    child: Text(a, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
              if (a != 'das') const SizedBox(width: 10),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        Text('🔵 der = نێر   🔴 die = مێ   🟢 das = بێلایەن', style: TextStyle(color: AppColors.fg54, fontSize: 13)),
      ]),
    );
  }
}

// ═════════════════════════ 🔤 Konjugation ═════════════════════════
class _Verb {
  final String inf, ku;
  final List<String> forms; // ich, du, er/sie/es, wir, ihr, sie/Sie
  const _Verb(this.inf, this.ku, this.forms);
}

const _persons = ['ich', 'du', 'er/sie/es', 'wir', 'ihr', 'sie/Sie'];
const _verbs = [
  _Verb('sein', 'بوون', ['bin', 'bist', 'ist', 'sind', 'seid', 'sind']),
  _Verb('haben', 'هەبوون', ['habe', 'hast', 'hat', 'haben', 'habt', 'haben']),
  _Verb('heißen', 'ناڤ بوون', ['heiße', 'heißt', 'heißt', 'heißen', 'heißt', 'heißen']),
  _Verb('kommen', 'هاتن', ['komme', 'kommst', 'kommt', 'kommen', 'kommt', 'kommen']),
  _Verb('wohnen', 'ژیان (ل جهەکی)', ['wohne', 'wohnst', 'wohnt', 'wohnen', 'wohnt', 'wohnen']),
  _Verb('sprechen', 'ئاخفتن', ['spreche', 'sprichst', 'spricht', 'sprechen', 'sprecht', 'sprechen']),
  _Verb('essen', 'خوارن', ['esse', 'isst', 'isst', 'essen', 'esst', 'essen']),
  _Verb('nehmen', 'برن / وەرگرتن', ['nehme', 'nimmst', 'nimmt', 'nehmen', 'nehmt', 'nehmen']),
  _Verb('lesen', 'خواندن', ['lese', 'liest', 'liest', 'lesen', 'lest', 'lesen']),
  _Verb('fahren', 'چوون (ب ترومبێلێ)', ['fahre', 'fährst', 'fährt', 'fahren', 'fahrt', 'fahren']),
  _Verb('schlafen', 'نڤستن', ['schlafe', 'schläfst', 'schläft', 'schlafen', 'schlaft', 'schlafen']),
  _Verb('arbeiten', 'کارکرن', ['arbeite', 'arbeitest', 'arbeitet', 'arbeiten', 'arbeitet', 'arbeiten']),
  _Verb('treffen', 'دیتن (کەسەکی)', ['treffe', 'triffst', 'trifft', 'treffen', 'trefft', 'treffen']),
  _Verb('sehen', 'دیتن', ['sehe', 'siehst', 'sieht', 'sehen', 'seht', 'sehen']),
  _Verb('helfen', 'هاریکاری کرن', ['helfe', 'hilfst', 'hilft', 'helfen', 'helft', 'helfen']),
  _Verb('werden', 'بوون (گوهۆڕین)', ['werde', 'wirst', 'wird', 'werden', 'werdet', 'werden']),
  _Verb('können', 'شیان', ['kann', 'kannst', 'kann', 'können', 'könnt', 'können']),
  _Verb('wollen', 'ڤیان', ['will', 'willst', 'will', 'wollen', 'wollt', 'wollen']),
  _Verb('müssen', 'دڤێت', ['muss', 'musst', 'muss', 'müssen', 'müsst', 'müssen']),
  _Verb('dürfen', 'دەستوور هەبوون', ['darf', 'darfst', 'darf', 'dürfen', 'dürft', 'dürfen']),
  _Verb('sollen', 'پێدڤی بوون', ['soll', 'sollst', 'soll', 'sollen', 'sollt', 'sollen']),
  _Verb('möchten', 'خواستن (ب ڕێز)', ['möchte', 'möchtest', 'möchte', 'möchten', 'möchtet', 'möchten']),
  _Verb('mögen', 'حەز ژێ کرن', ['mag', 'magst', 'mag', 'mögen', 'mögt', 'mögen']),
  _Verb('lernen', 'فێربوون', ['lerne', 'lernst', 'lernt', 'lernen', 'lernt', 'lernen']),
];

// 🇬🇧 ئینگلیزی: (کەس، کارێ سەرەکی، بەرسڤ، هەلبژارتنێن دی، کوردی)
class _EnQ {
  final String subject, verb, answer, ku;
  final List<String> others;
  final String rest;
  const _EnQ(this.subject, this.verb, this.answer, this.others, this.rest, this.ku);
}

const _enQs = [
  _EnQ('I', 'be', 'am', ['is', 'are', 'be'], 'a student.', 'ئەز قوتابیمە.'),
  _EnQ('She', 'be', 'is', ['am', 'are', 'be'], 'my sister.', 'ئەو خویشکا منە.'),
  _EnQ('They', 'be', 'are', ['is', 'am', 'be'], 'from Duhok.', 'ئەو ژ دهۆکێ نە.'),
  _EnQ('We', 'be', 'are', ['is', 'am', 'were'], 'happy today.', 'ئەم ئەڤرۆ دلخۆشین.'),
  _EnQ('He', 'have', 'has', ['have', 'having', 'had'], 'two brothers.', 'دوو برا وی هەنە.'),
  _EnQ('I', 'have', 'have', ['has', 'having', 'haves'], 'a car.', 'ترومبێلەک من هەیە.'),
  _EnQ('She', 'go', 'goes', ['go', 'going', 'gos'], 'to school every day.', 'ئەو هەر رۆژ دچیتە قوتابخانێ.'),
  _EnQ('He', 'work', 'works', ['work', 'working', 'worken'], 'in a bank.', 'ئەو ل بانکێ کار دکەت.'),
  _EnQ('They', 'live', 'live', ['lives', 'living', 'lived'], 'in Erbil.', 'ئەو ل هەولێرێ دژین.'),
  _EnQ('My mother', 'cook', 'cooks', ['cook', 'cooking', 'cookes'], 'every evening.', 'دایکا من هەر ئێڤار خوارنێ چێدکەت.'),
  _EnQ('He', 'watch', 'watches', ['watchs', 'watch', 'watching'], 'TV at night.', 'ئەو ب شەڤ تەلەڤزیۆنێ دبینیت.'),
  _EnQ('She', 'study', 'studies', ['studys', 'study', 'studying'], 'English.', 'ئەو ئینگلیزی دخوینیت.'),
  _EnQ('We', 'play', 'play', ['plays', 'playing', 'plaies'], 'football on Friday.', 'ئەم رۆژا ئەینیێ تەپا پێ یاری دکەین.'),
  _EnQ('She', 'not / like', "doesn't like", ["don't like", "doesn't likes", 'not like'], 'coffee.', 'ئەو حەز ژ قەهوێ ناکەت.'),
  _EnQ('I', 'not / eat', "don't eat", ["doesn't eat", 'not eat', "don't eats"], 'meat.', 'ئەز گۆشتی ناخۆم.'),
  _EnQ('I', 'be (now)', 'am reading', ['reading', 'is reading', 'are read'], 'a book now.', 'ئەز نوکە پەرتووکەکێ دخوینم.'),
  _EnQ('They', 'play (now)', 'are playing', ['is playing', 'playing', 'are play'], 'outside now.', 'ئەو نوکە ل دەرڤە یاری دکەن.'),
  _EnQ('I', 'be (yesterday)', 'was', ['were', 'am', 'be'], 'at home yesterday.', 'دوهی ئەز ل مال بووم.'),
  _EnQ('They', 'be (yesterday)', 'were', ['was', 'are', 'been'], 'tired yesterday.', 'دوهی ئەو یێن وەستیایی بوون.'),
  _EnQ('We', 'go (yesterday)', 'went', ['goed', 'go', 'gone'], 'to the market yesterday.', 'دوهی ئەم چووینە بازاڕێ.'),
  _EnQ('She', 'watch (yesterday)', 'watched', ['watch', 'watches', 'watching'], 'a film last night.', 'دوهی شەڤێ وێ فیلمەک دیت.'),
  _EnQ('He', 'can / swim', 'can swim', ['cans swim', 'can swims', 'can to swim'], 'very well.', 'ئەو دشێت گەلەک باش مەلەڤانیێ بکەت.'),
  _EnQ('I', 'eat (yesterday)', 'ate', ['eated', 'eat', 'eaten'], 'rice for lunch.', 'من نیڤرۆ برنج خوار.'),
  _EnQ('He', 'have (yesterday)', 'had', ['haved', 'has', 'have'], 'a cold last week.', 'هەفتیا بۆری ئەو هاتبوو سەرما.'),
];

class ConjugationGameScreen extends StatefulWidget {
  const ConjugationGameScreen({super.key});
  @override
  State<ConjugationGameScreen> createState() => _ConjugationGameScreenState();
}

class _ConjugationGameScreenState extends State<ConjugationGameScreen> {
  final _rng = Random();
  late List<(_Verb, int)> round;
  late List<String> options;
  int i = 0, correct = 0, xp = 0;
  String? picked;
  bool done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  bool get _en => ProgressService.instance.targetLang == AppLanguage.english;
  late List<_EnQ> enRound;

  void _start() {
    if (_en) {
      enRound = ([..._enQs]..shuffle(_rng)).take(15).toList();
      setState(() {
        i = correct = xp = 0;
        done = false;
      });
      _prepare();
      return;
    }
    final vs = [..._verbs]..shuffle(_rng);
    round = [for (var k = 0; k < 15; k++) (vs[k % vs.length], _rng.nextInt(6))];
    setState(() {
      i = correct = xp = 0;
      done = false;
    });
    _prepare();
  }

  void _prepare() {
    if (_en) {
      final q = enRound[i];
      options = [q.answer, ...q.others.take(3)]..shuffle(_rng);
      picked = null;
      return;
    }
    final (v, p) = round[i];
    final right = v.forms[p];
    final wrong = v.forms.toSet().where((f) => f != right).toList()..shuffle(_rng);
    options = [right, ...wrong.take(3)]..shuffle(_rng);
    picked = null;
  }

  int get _total => _en ? enRound.length : round.length;

  Future<void> _pick(String f) async {
    if (picked != null) return;
    if (_en) {
      final q = enRound[i];
      final ok = f == q.answer;
      setState(() => picked = f);
      if (ok) {
        Sfx.correct();
        correct++;
        xp += 2;
        showXpPop(context, 2);
      } else {
        Sfx.wrong();
      }
      VoiceService.instance.speakText('${q.subject} ${q.answer} ${q.rest}', AppLanguage.english);
      await Future.delayed(Duration(milliseconds: ok ? 1100 : 1900));
      if (!mounted) return;
      await _advance();
      return;
    }
    final (v, p) = round[i];
    final ok = f == v.forms[p];
    setState(() => picked = f);
    if (ok) {
      Sfx.correct();
      correct++;
      xp += 2;
      showXpPop(context, 2);
    } else {
      Sfx.wrong();
    }
    final pr = _persons[p].split('/').first;
    VoiceService.instance.speakText('$pr ${v.forms[p]}', AppLanguage.german);
    await Future.delayed(Duration(milliseconds: ok ? 900 : 1700));
    if (!mounted) return;
    await _advance();
  }

  Future<void> _advance() async {
    if (i + 1 < _total) {
      setState(() {
        i++;
        _prepare();
      });
    } else {
      if (xp > 0) await ProgressService.instance.earn(xp);
      setState(() => done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_en ? '🔤 شێوێن کاران (Verb forms)' : '🔤 گوهۆڕینا کاران (Konjugation)'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(value: done ? 1 : i / _total, minHeight: 6, backgroundColor: AppColors.card),
          ),
        ),
        body: SafeArea(child: done ? _GameDone(correct: correct, total: _total, xp: xp, onAgain: _start) : (_en ? _playEn() : _play())),
      ),
    );
  }

  Widget _playEn() {
    final q = enRound[i];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('شێوێ دروست یێ کاری هەلبژێرە', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Text('(${q.verb})', textDirection: TextDirection.ltr, style: TextStyle(color: AppColors.goldText, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text('${q.subject} ${picked == null ? '_____' : q.answer} ${q.rest}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: picked == null ? AppColors.fg : AppColors.green)),
            ),
            const SizedBox(height: 8),
            Text(q.ku, style: TextStyle(color: AppColors.fg60)),
          ]),
        ),
        const SizedBox(height: 24),
        for (final o in options)
          OptionTile(
            text: o,
            selected: picked == o,
            textDirection: TextDirection.ltr,
            stateColor: picked == null ? null : (o == q.answer ? AppColors.green : (o == picked ? AppColors.red : null)),
            onTap: picked == null ? () => _pick(o) : null,
          ),
      ]),
    );
  }

  Widget _play() {
    final (v, p) = round[i];
    final right = v.forms[p];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('شێوێ دروست یێ کاری هەلبژێرە', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Text('${v.inf}  ·  ${v.ku}', textAlign: TextAlign.center, style: TextStyle(color: AppColors.goldText, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text('${_persons[p]}  ${picked == null ? '_____' : right}',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: picked == null ? AppColors.fg : AppColors.green)),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        for (final o in options)
          OptionTile(
            text: o,
            selected: picked == o,
            textDirection: TextDirection.ltr,
            stateColor: picked == null ? null : (o == right ? AppColors.green : (o == picked ? AppColors.red : null)),
            onTap: picked == null ? () => _pick(o) : null,
          ),
      ]),
    );
  }
}

// ═════════════════════════ 📕 دەفتەرا خەلەتیان ═════════════════════════
class MistakesNotebookScreen extends StatelessWidget {
  const MistakesNotebookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final n = p.nativeLang, t = p.targetLang;
        final weak = p.weakConcepts..sort((a, b) => (p.mistakes[b.id] ?? 0).compareTo(p.mistakes[a.id] ?? 0));
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: const Text('📕 دەفتەرا خەلەتیێن من')),
            body: weak.isEmpty
                ? const Center(child: Text('🎉 چ خەلەتی نینن!', style: TextStyle(fontSize: 20)))
                : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
                    Text('ئەڤ پەیڤ و رستە تە خەلەت کرینە. دەمێ تو دوو جاران دروست بێژی، ژ ڤێرێ دچن.',
                        style: TextStyle(color: AppColors.fg60)),
                    const SizedBox(height: 12),
                    for (final c in weak)
                      Card(
                        color: AppColors.card,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: Text(c.pic.isEmpty ? '📝' : c.pic, style: const TextStyle(fontSize: 30)),
                          title: Text(c.text(t), textDirection: t.direction, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.germanText)),
                          subtitle: Text(c.text(n), textDirection: n.direction),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                              child: Text('×${_ku(p.mistakes[c.id] ?? 0)}', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(icon: Icon(Icons.volume_up_rounded, color: AppColors.accent), onPressed: () => VoiceService.instance.speak(c, t)),
                          ]),
                        ),
                      ),
                  ]),
            floatingActionButton: weak.isEmpty
                ? null
                : FloatingActionButton.extended(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => GameSessionScreen(kind: null, concepts: weak.take(10).toList()))),
                    icon: const Icon(Icons.fitness_center_rounded),
                    label: const Text('راهێنان ل سەر ڤان پەیڤان', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════ 🏆 لیستا باشترینان ═════════════════════════
/// ژ content.leaderboard (هەر دەمژمێرەکێ GitHub Actions ژ نوو حساب دکەت)
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>>? rows;
  String? updated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await Backend.instance.contentOverride('leaderboard');
    if (!mounted) return;
    try {
      final m = jsonDecode(v ?? '{}') as Map<String, dynamic>;
      setState(() {
        rows = ((m['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();
        updated = m['updated'] as String?;
      });
    } catch (_) {
      setState(() => rows = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = (Backend.instance.userId ?? '').padRight(8).substring(0, 8);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('🏆 باشترینێن ڤێ هەفتیێ')),
        body: rows == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
                  Text('XP یێن ژ رۆژا دووشەمبیێ ڤە. هەر دووشەمبی ژ نوو دەستپێدکەت.', style: TextStyle(color: AppColors.fg60)),
                  const SizedBox(height: 12),
                  if (rows!.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('هێشتا کەس نینە — تو ببە ئێکەم! 💪'))),
                  for (var k = 0; k < rows!.length; k++) _row(k, rows![k], rows![k]['k'] == me),
                ]),
              ),
      ),
    );
  }

  Widget _row(int k, Map<String, dynamic> r, bool isMe) {
    const medals = ['🥇', '🥈', '🥉'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.green.withValues(alpha: 0.15) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? AppColors.green : Colors.transparent, width: 2),
      ),
      child: Row(children: [
        SizedBox(width: 40, child: Text(k < 3 ? medals[k] : _ku(k + 1), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(width: 8),
        Expanded(child: Text('${r['name']}${isMe ? ' (تو)' : ''}', style: TextStyle(fontSize: 17, fontWeight: isMe ? FontWeight.w900 : FontWeight.w600))),
        Text('${r['xp']} XP', style: TextStyle(color: AppColors.goldText, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }
}

// ═════════════════════════ 🌈 ڕەنگ: گوهداری بکە و ڕەنگێ دروست هەلبژێرە ═════════════════════════

/// ڕەنگ ب ئەلمانی، ئینگلیزی و کوردی + چەند تشتێن ب وی ڕەنگی
class GameColor {
  final String de, en, ku;
  final Color color;
  final List<(String emoji, String de, String en, String ku)> things;
  const GameColor(this.de, this.en, this.ku, this.color, this.things);
  String word(AppLanguage l) => l == AppLanguage.english ? en : de;
}

const gameColors = <GameColor>[
  GameColor('weiß', 'white', 'سپی', Color(0xFFFFFFFF), [
    ('🥛', 'Die Milch ist weiß.', 'The milk is white.', 'شیر سپیە.'),
    ('☁️', 'Die Wolke ist weiß.', 'The cloud is white.', 'عەور سپیە.'),
  ]),
  GameColor('schwarz', 'black', 'ڕەش', Color(0xFF151515), [
    ('🐈‍⬛', 'Die Katze ist schwarz.', 'The cat is black.', 'پشیک ڕەشە.'),
    ('🎱', 'Der Ball ist schwarz.', 'The ball is black.', 'تۆپ ڕەشە.'),
  ]),
  GameColor('rot', 'red', 'سۆر', Color(0xFFE53935), [
    ('🍅', 'Die Tomate ist rot.', 'The tomato is red.', 'باجانێ سۆر سۆرە.'),
    ('🍓', 'Die Erdbeere ist rot.', 'The strawberry is red.', 'فراولە سۆرە.'),
  ]),
  GameColor('blau', 'blue', 'شین', Color(0xFF1E88E5), [
    ('🌊', 'Das Meer ist blau.', 'The sea is blue.', 'دەریا شینە.'),
    ('💙', 'Das Herz ist blau.', 'The heart is blue.', 'دل شینە.'),
  ]),
  GameColor('grün', 'green', 'سەوز', Color(0xFF43A047), [
    ('🌳', 'Der Baum ist grün.', 'The tree is green.', 'دار سەوزە.'),
    ('🥒', 'Die Gurke ist grün.', 'The cucumber is green.', 'خیار سەوزە.'),
  ]),
  GameColor('gelb', 'yellow', 'زەر', Color(0xFFFDD835), [
    ('🍌', 'Die Banane ist gelb.', 'The banana is yellow.', 'مۆز زەرە.'),
    ('🌞', 'Die Sonne ist gelb.', 'The sun is yellow.', 'رۆژ زەرە.'),
  ]),
  GameColor('orange', 'orange', 'پرتەقالی', Color(0xFFFB8C00), [
    ('🍊', 'Die Orange ist orange.', 'The orange is orange.', 'پرتەقال پرتەقالیە.'),
    ('🥕', 'Die Karotte ist orange.', 'The carrot is orange.', 'گێزەر پرتەقالیە.'),
  ]),
  GameColor('braun', 'brown', 'قاوەیی', Color(0xFF795548), [
    ('🐻', 'Der Bär ist braun.', 'The bear is brown.', 'هرچ قاوەییە.'),
    ('🍫', 'Die Schokolade ist braun.', 'The chocolate is brown.', 'چکلێت قاوەییە.'),
  ]),
  GameColor('grau', 'grey', 'خۆلەمێشی', Color(0xFF9E9E9E), [
    ('🐘', 'Der Elefant ist grau.', 'The elephant is grey.', 'فیل خۆلەمێشیە.'),
    ('🐭', 'Die Maus ist grau.', 'The mouse is grey.', 'مشک خۆلەمێشیە.'),
  ]),
  GameColor('rosa', 'pink', 'پەمەیی', Color(0xFFF48FB1), [
    ('🐷', 'Das Schwein ist rosa.', 'The pig is pink.', 'بەراز پەمەییە.'),
    ('🌸', 'Die Blume ist rosa.', 'The flower is pink.', 'گول پەمەییە.'),
  ]),
  GameColor('lila', 'purple', 'مۆر', Color(0xFF8E24AA), [
    ('🍆', 'Die Aubergine ist lila.', 'The eggplant is purple.', 'باجانێ ڕەش مۆرە.'),
    ('🍇', 'Die Trauben sind lila.', 'The grapes are purple.', 'تری مۆرن.'),
  ]),
];

enum _ColorMode { word, listen, thing, swatch }

class ColorGameScreen extends StatefulWidget {
  const ColorGameScreen({super.key});
  @override
  State<ColorGameScreen> createState() => _ColorGameScreenState();
}

class _ColorGameScreenState extends State<ColorGameScreen> {
  static const _len = 12;
  final _rng = Random();
  final lang = ProgressService.instance.targetLang == AppLanguage.english ? AppLanguage.english : AppLanguage.german;
  late List<(GameColor, _ColorMode, int)> round;
  List<GameColor> options = [];
  final List<String> _recent = [];
  int i = 0, correct = 0, xp = 0, streak = 0;
  GameColor? picked;
  bool done = false;
  int _tok = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    VoiceService.instance.stopPlayback();
    super.dispose();
  }

  void _start() {
    final cs = [...gameColors]..shuffle(_rng);
    final modes = [..._ColorMode.values, ..._ColorMode.values, ..._ColorMode.values]..shuffle(_rng);
    round = [
      for (var k = 0; k < _len; k++) (cs[k % cs.length], modes[k], _rng.nextInt(cs[k % cs.length].things.length)),
    ];
    i = correct = xp = streak = 0;
    done = false;
    _recent.clear();
    _prepare();
    setState(() {});
  }

  void _prepare() {
    _tok++;
    picked = null;
    final c = round[i].$1;
    // ٣–٤ هەلبژارتن، و نە هەمان ڕەنگ د پرسیارا بەری دا (دا جۆراوجۆر بن)
    final n = _rng.nextInt(3) == 0 ? 3 : 4;
    final others = gameColors.where((g) => g != c).toList()..shuffle(_rng);
    others.sort((a, b) => (_recent.contains(a.de) ? 1 : 0) - (_recent.contains(b.de) ? 1 : 0));
    options = [c, ...others.take(n - 1)]..shuffle(_rng);
    _recent
      ..clear()
      ..addAll(options.map((o) => o.de));
    if (round[i].$2 == _ColorMode.listen) {
      final t = _tok;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && t == _tok) _say(c.word(lang));
      });
    }
  }

  void _say(String s) => VoiceService.instance.speakText(s, lang);

  Future<void> _pick(GameColor g) async {
    if (picked != null) return;
    final (c, mode, t) = round[i];
    final ok = g == c;
    setState(() => picked = g);
    if (ok) {
      Sfx.correct();
      correct++;
      streak++;
      final gx = streak >= 5 ? 3 : 2;
      xp += gx;
      showXpPop(context, gx);
    } else {
      Sfx.wrong();
      streak = 0;
    }
    final th = c.things[t];
    _say(mode == _ColorMode.thing ? (lang == AppLanguage.english ? th.$3 : th.$2) : c.word(lang));
    await Future.delayed(Duration(milliseconds: ok ? 1300 : 2200));
    if (!mounted) return;
    if (i + 1 < round.length) {
      setState(() {
        i++;
        _prepare();
      });
    } else {
      if (xp > 0) await ProgressService.instance.earn(xp);
      setState(() => done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(lang == AppLanguage.english ? '🌈 Colours' : '🌈 Farben'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(value: done ? 1 : i / round.length, minHeight: 6, backgroundColor: AppColors.card),
          ),
        ),
        body: SafeArea(child: done ? _GameDone(correct: correct, total: round.length, xp: xp, onAgain: _start) : _play()),
      ),
    );
  }

  Widget _swatch(Color col, double size, {Widget? child}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: col,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: AppColors.fg24, width: 2),
          boxShadow: [BoxShadow(color: col.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        alignment: Alignment.center,
        child: child,
      );

  Widget _play() {
    final (c, mode, t) = round[i];
    final th = c.things[t];
    final word = c.word(lang);
    final question = switch (mode) {
      _ColorMode.word => 'ڕەنگێ «$word» هەلبژێرە',
      _ColorMode.listen => 'گوهداری بکە و ڕەنگی هەلبژێرە',
      _ColorMode.thing => 'ئەڤ تشتە چ ڕەنگە؟',
      _ColorMode.swatch => 'ئەڤ ڕەنگە ب ${lang == AppLanguage.english ? 'ئینگلیزی' : 'ئەلمانی'} چییە؟',
    };
    final blank = (lang == AppLanguage.english ? th.$3 : th.$2).replaceFirst(RegExp(r'\S+\.$'), '___ .');
    Widget prompt = switch (mode) {
      _ColorMode.word => Directionality(
          textDirection: TextDirection.ltr,
          child: InkWell(
            onTap: () => _say(word),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(word, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Icon(Icons.volume_up_rounded, color: AppColors.fg60),
            ]),
          ),
        ),
      _ColorMode.listen => InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _say(word),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 54),
          ),
        ),
      _ColorMode.thing => Column(children: [
          Text(th.$1, style: const TextStyle(fontSize: 86)),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(picked == null ? blank : (lang == AppLanguage.english ? th.$3 : th.$2),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          Text(th.$4, style: TextStyle(color: AppColors.fg60, fontSize: 16)),
        ]),
      _ColorMode.swatch => _swatch(c.color, 130),
    };
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Text(question, textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg70, fontSize: 18, fontWeight: FontWeight.bold)),
        if (streak >= 3) Text('🔥 ${_ku(streak)} ل دویف ئێک', style: TextStyle(color: AppColors.goldText, fontWeight: FontWeight.bold)),
        const Spacer(),
        prompt,
        if (picked != null) ...[
          const SizedBox(height: 12),
          Text(
            picked == c ? '✅ $word = ${c.ku}' : '❌ دروست: $word = ${c.ku}',
            style: TextStyle(color: picked == c ? AppColors.green : AppColors.red, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
        const Spacer(),
        if (mode == _ColorMode.swatch)
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
              for (final o in options) _wordBtn(o, c),
            ]),
          )
        else
          Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: [
            for (final o in options) _swatchBtn(o, c),
          ]),
        const SizedBox(height: 16),
      ]),
    );
  }

  Color _state(GameColor o, GameColor c) =>
      picked == null ? AppColors.fg24 : (o == c ? AppColors.green : (o == picked ? AppColors.red : AppColors.fg24));

  Widget _swatchBtn(GameColor o, GameColor c) {
    final st = _state(o, c);
    final show = picked != null && (o == c || o == picked);
    return GestureDetector(
      onTap: () => _pick(o),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: st, width: picked == null ? 0 : 4),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _swatch(o.color, 96,
              child: show ? Icon(o == c ? Icons.check_rounded : Icons.close_rounded, size: 46, color: o.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white) : null),
          if (picked != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(o.word(lang), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ]),
      ),
    );
  }

  Widget _wordBtn(GameColor o, GameColor c) {
    final st = _state(o, c);
    return GestureDetector(
      onTap: () => _pick(o),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: picked != null && st != AppColors.fg24 ? st.withValues(alpha: 0.18) : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: picked == null ? AppColors.fg24 : st, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Text(o.word(lang), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
