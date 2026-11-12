import 'dart:math';

import '../models.dart';

/// 👤 پرسیارێن جهێناڤان — د هەمی کۆرسان دا، ژ ساناهی بۆ ب زەحمەت:
///   قۆناغ ١–٢: ich · du · Sie        قۆناغ ٣–٤: + er · sie
///   قۆناغ ٥–٧: + wir · ihr · sie     قۆناغ ٨–١٠: mein · dein · sein …
///   قۆناغ ١١–١٥: mich · dich · ihn … (Akkusativ)   قۆناغ ١٦+: mir · dir · ihm … (Dativ)

/// ئاست ژ ژمارا قۆناغێ (١ = قۆناغا ئێکێ یا بەشا ١)
int pronounTier(int stageNo) => switch (stageNo) {
      <= 2 => 0,
      <= 4 => 1,
      <= 7 => 2,
      <= 10 => 3,
      <= 15 => 4,
      _ => 5,
    };

class PronounQ {
  final WordConcept concept;
  final ClozeInfo cloze;
  const PronounQ(this.concept, this.cloze);
}

// ───────── ئەلمانی ─────────
// 0 ich · 1 du · 2 er · 3 sie · 5 wir · 6 ihr · 7 sie (کۆ) · 8 Sie
const _dePron = {0: 'ich', 1: 'du', 2: 'er', 3: 'sie', 5: 'wir', 6: 'ihr', 7: 'sie', 8: 'Sie'};
const _kuSubj = {0: 'ئەز', 1: 'تو', 2: 'ئەو (کوڕ)', 3: 'ئەو (کچ)', 5: 'ئەم', 6: 'هوین', 7: 'ئەو (هەمی)', 8: 'هوین (ب رێز)'};
// جهێ شێوێ کاری: ich, du, er/sie, wir, ihr, sie/Sie
const _formIdx = {0: 0, 1: 1, 2: 2, 3: 2, 5: 3, 6: 4, 7: 5, 8: 5};
// جهێ شێوێ کوردی: ئەز، تو، ئەو، ئەم، هوین، ئەو (کۆ)
const _kuIdx = {0: 0, 1: 1, 2: 2, 3: 2, 5: 3, 6: 4, 7: 5, 8: 4};

class _Verb {
  final String inf, obj;
  final List<String> forms, ku;
  final int minTier;
  const _Verb(this.inf, this.forms, this.obj, this.ku, [this.minTier = 0]);
}

const _verbs = [
  _Verb('wohnen', ['wohne', 'wohnst', 'wohnt', 'wohnen', 'wohnt', 'wohnen'], 'in Duhok',
      ['ل دهۆکێ دژیم', 'ل دهۆکێ دژی', 'ل دهۆکێ دژیت', 'ل دهۆکێ دژین', 'ل دهۆکێ دژین', 'ل دهۆکێ دژین']),
  _Verb('kommen', ['komme', 'kommst', 'kommt', 'kommen', 'kommt', 'kommen'], 'aus Kurdistan',
      ['ژ کوردستانێمە', 'ژ کوردستانێ یی', 'ژ کوردستانێ یە', 'ژ کوردستانێ نە', 'ژ کوردستانێ نە', 'ژ کوردستانێ نە']),
  _Verb('lernen', ['lerne', 'lernst', 'lernt', 'lernen', 'lernt', 'lernen'], 'Deutsch',
      ['ئەلمانی فێر دبم', 'ئەلمانی فێر دبی', 'ئەلمانی فێر دبیت', 'ئەلمانی فێر دبین', 'ئەلمانی فێر دبن', 'ئەلمانی فێر دبن']),
  _Verb('sein', ['bin', 'bist', 'ist', 'sind', 'seid', 'sind'], 'müde',
      ['وەستیایمە', 'وەستیایی', 'وەستیایە', 'وەستیاینە', 'وەستیاینە', 'وەستیاینە']),
  _Verb('trinken', ['trinke', 'trinkst', 'trinkt', 'trinken', 'trinkt', 'trinken'], 'Tee',
      ['چایێ ڤەدخۆم', 'چایێ ڤەدخۆی', 'چایێ ڤەدخوت', 'چایێ ڤەدخۆین', 'چایێ ڤەدخۆن', 'چایێ ڤەدخۆن'], 1),
  _Verb('spielen', ['spiele', 'spielst', 'spielt', 'spielen', 'spielt', 'spielen'], 'Fußball',
      ['تۆپا پێ دکەم', 'تۆپا پێ دکەی', 'تۆپا پێ دکەت', 'تۆپا پێ دکەین', 'تۆپا پێ دکەن', 'تۆپا پێ دکەن'], 1),
  _Verb('kochen', ['koche', 'kochst', 'kocht', 'kochen', 'kocht', 'kochen'], 'Reis',
      ['برنجی چێدکەم', 'برنجی چێدکەی', 'برنجی چێدکەت', 'برنجی چێدکەین', 'برنجی چێدکەن', 'برنجی چێدکەن'], 1),
  _Verb('haben', ['habe', 'hast', 'hat', 'haben', 'habt', 'haben'], 'Hunger',
      ['برسیمە', 'برسیی', 'برسیە', 'برسینە', 'برسینە', 'برسینە'], 1),
  _Verb('gehen', ['gehe', 'gehst', 'geht', 'gehen', 'geht', 'gehen'], 'nach Hause',
      ['دچمە مال', 'دچییە مال', 'دچیتە مال', 'دچینە مال', 'دچنە مال', 'دچنە مال'], 2),
  _Verb('arbeiten', ['arbeite', 'arbeitest', 'arbeitet', 'arbeiten', 'arbeitet', 'arbeiten'], 'heute',
      ['ئەڤرۆ کار دکەم', 'ئەڤرۆ کار دکەی', 'ئەڤرۆ کار دکەت', 'ئەڤرۆ کار دکەین', 'ئەڤرۆ کار دکەن', 'ئەڤرۆ کار دکەن'], 2),
  _Verb('essen', ['esse', 'isst', 'isst', 'essen', 'esst', 'essen'], 'Brot',
      ['نانی دخۆم', 'نانی دخۆی', 'نانی دخوت', 'نانی دخۆین', 'نانی دخۆن', 'نانی دخۆن'], 2),
  _Verb('sprechen', ['spreche', 'sprichst', 'spricht', 'sprechen', 'sprecht', 'sprechen'], 'Kurdisch',
      ['کوردی دئاخڤم', 'کوردی دئاخڤی', 'کوردی دئاخڤیت', 'کوردی دئاخڤین', 'کوردی دئاخڤن', 'کوردی دئاخڤن'], 2),
  _Verb('fahren', ['fahre', 'fährst', 'fährt', 'fahren', 'fahrt', 'fahren'], 'nach Erbil',
      ['دچمە هەولێرێ', 'دچییە هەولێرێ', 'دچیتە هەولێرێ', 'دچینە هەولێرێ', 'دچنە هەولێرێ', 'دچنە هەولێرێ'], 3),
  _Verb('lesen', ['lese', 'liest', 'liest', 'lesen', 'lest', 'lesen'], 'ein Buch',
      ['پەرتووکەکێ دخوینم', 'پەرتووکەکێ دخوینی', 'پەرتووکەکێ دخوینیت', 'پەرتووکەکێ دخوینین', 'پەرتووکەکێ دخوینن', 'پەرتووکەکێ دخوینن'], 3),
  _Verb('können', ['kann', 'kannst', 'kann', 'können', 'könnt', 'können'], 'gut schwimmen',
      ['دشێم باش مەلەڤانیێ بکەم', 'دشێی باش مەلەڤانیێ بکەی', 'دشێت باش مەلەڤانیێ بکەت', 'دشێین باش مەلەڤانیێ بکەین',
          'دشێن باش مەلەڤانیێ بکەن', 'دشێن باش مەلەڤانیێ بکەن'], 3),
];

List<int> _subjects(int tier) => [0, 1, 8, if (tier >= 1) ...[2, 3], if (tier >= 2) ...[5, 6, 7]];

/// «من» ➔ «منە»، «تە» ➔ «تەیە»
String _isIt(String o) => RegExp(r'[ەێاۆ]$').hasMatch(o) ? '$oیە' : '$oە';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

int _seq = 0;
WordConcept _wc(String de, String ku, ClozeInfo cz) =>
    WordConcept('pr_${_seq++}', ku: ku, kuLat: '', de: de, deHint: '', en: de, enHint: '', emoji: '👤', cloze: cz);

PronounQ? _subjectQ(Random r, int tier) {
  final verbs = _verbs.where((v) => v.minTier <= tier).toList();
  final v = verbs[r.nextInt(verbs.length)];
  final subs = _subjects(tier);
  final p = subs[r.nextInt(subs.length)];
  final form = v.forms[_formIdx[p]!];
  final ku = '${_kuSubj[p]} ${v.ku[_kuIdx[p]!]}.';
  final pron = p == 8 ? 'Sie' : _dePron[p]!;
  final full = '${_cap(pron)} $form ${v.obj}.';
  if (r.nextBool()) {
    // 👤 کیژ جهێناڤ؟
    final wrong = <String>{};
    for (final q in [..._dePron.keys]..shuffle(r)) {
      final w = _cap(q == 8 ? 'Sie' : _dePron[q]!);
      if (v.forms[_formIdx[q]!] != form && w != _cap(pron)) wrong.add(w);
      if (wrong.length >= 2) break;
    }
    if (wrong.length < 2) return null;
    final cz = ClozeInfo('___ $form ${v.obj}.', _cap(pron), wrong.toList(), ku);
    return PronounQ(_wc(full, ku, cz), cz);
  }
  // ✍️ کیژ شێوێ کاری؟
  final wrong = (v.forms.toSet()..remove(form)).toList()..shuffle(r);
  if (wrong.length < 2) return null;
  final cz = ClozeInfo('${_cap(pron)} ___ ${v.obj}. (${v.inf})', form, wrong.take(2).toList(), ku);
  return PronounQ(_wc(full, ku, cz), cz);
}

// یێ من، یێ تە … (mein, dein …)
const _possM = {0: 'mein', 1: 'dein', 2: 'sein', 3: 'ihr', 5: 'unser', 6: 'euer', 7: 'ihr', 8: 'Ihr'};
const _possF = {0: 'meine', 1: 'deine', 2: 'seine', 3: 'ihre', 5: 'unsere', 6: 'eure', 7: 'ihre', 8: 'Ihre'};
const _owner = {0: 'من', 1: 'تە', 2: 'وی', 3: 'وێ', 5: 'مە', 6: 'هەوە', 7: 'وان', 8: 'هەوە'};
const _nouns = [
  ('Buch', false, 'پەرتووکا'),
  ('Auto', false, 'ترومبێلا'),
  ('Handy', false, 'مۆبایلا'),
  ('Vater', false, 'بابێ'),
  ('Bruder', false, 'برایێ'),
  ('Schlüssel', false, 'کلیلا'),
  ('Mutter', true, 'دایکا'),
  ('Schwester', true, 'خویشکا'),
  ('Tasche', true, 'جانتایا'),
  ('Wohnung', true, 'خانیێ'),
];

PronounQ _possQ(Random r) {
  final n = _nouns[r.nextInt(_nouns.length)];
  final keys = _possM.keys.toList();
  final p = keys[r.nextInt(keys.length)];
  final ans = n.$2 ? _possF[p]! : _possM[p]!;
  final other = keys.where((k) => k != p && _possM[k] != _possM[p]).toList()..shuffle(r);
  final wrong = <String>{n.$2 ? _possM[p]! : _possF[p]!, n.$2 ? _possF[other.first]! : _possM[other.first]!}.toList();
  final ku = 'ئەڤە ${n.$3} ${_isIt(_owner[p]!)}.';
  final hint = p == 8 ? 'Sie' : _dePron[p]!;
  final cz = ClozeInfo('Das ist ___ ${n.$1}. ($hint)', ans, wrong, ku);
  return PronounQ(_wc('Das ist $ans ${n.$1}.', ku, cz), cz);
}

// Akkusativ: mich, dich, ihn … — Dativ: mir, dir, ihm …
const _acc = [
  ('mich', 'من', ['mir', 'ich']),
  ('dich', 'تە', ['dir', 'du']),
  ('ihn', 'وی', ['ihm', 'er']),
  ('sie', 'وێ', ['ihr', 'ihn']),
  ('uns', 'مە', ['wir', 'unser']),
  ('euch', 'هەوە', ['ihr', 'uns']),
];
const _dat = [
  ('mir', 'من', ['mich', 'ich']),
  ('dir', 'تە', ['dich', 'du']),
  ('ihm', 'وی', ['ihn', 'er']),
  ('ihr', 'وێ', ['sie', 'ihn']),
  ('uns', 'مە', ['wir', 'unser']),
  ('euch', 'هەوە', ['ihr', 'eure']),
  ('ihnen', 'وان', ['sie', 'ihr']),
];
const _accT = [
  ('Lara besucht ___ morgen.', 'لارا سبەی دێ سەرەدانا {o} کەت.'),
  ('Der Lehrer fragt ___.', 'مامۆستا پسیارێ ژ {o} دکەت.'),
  ('Azad sieht ___ im Park.', 'ئازاد {o} ل پارکێ دبینیت.'),
  ('Die Kinder suchen ___.', 'زارۆک ل {o} دگەڕێن.'),
  ('Mama ruft ___ heute an.', 'دایک ئەڤرۆ تەلەفۆنێ بۆ {o} دکەت.'),
];
const _datT = [
  ('Lara hilft ___.', 'لارا هاریکاریا {o} دکەت.'),
  ('Das Buch gehört ___.', 'ئەڤ پەرتووکە یا {o} یە.'),
  ('Der Lehrer gibt ___ ein Heft.', 'مامۆستا دەفتەرەکێ ددەتە {o}.'),
  ('Die Jacke gefällt ___.', 'چاکێت ب دلێ {o} یە.'),
  ('Azad schreibt ___ eine Nachricht.', 'ئازاد پەیامەکێ بۆ {o} دنڤیسیت.'),
];

PronounQ _objQ(Random r, bool dative) {
  final objs = dative ? _dat : _acc;
  final ts = dative ? _datT : _accT;
  final o = objs[r.nextInt(objs.length)];
  final t = ts[r.nextInt(ts.length)];
  final ku = t.$2.replaceAll('{o}', o.$2);
  final cz = ClozeInfo(t.$1, o.$1, o.$3, ku);
  return PronounQ(_wc(t.$1.replaceAll('___', o.$1), ku, cz), cz);
}

/// [count] پرسیار بۆ ئاستێ [tier] — پتر ژ ئاستێ نوکە، و هندەک ژ ئاستێن بەری (دووبارەکرن)
List<PronounQ> germanPronounQuestions(int tier, int count, [Random? rnd]) {
  final r = rnd ?? Random();
  final out = <PronounQ>[];
  var guard = 0;
  while (out.length < count && guard++ < count * 10) {
    // ٦٠٪ ئاستێ نوکە، ٤٠٪ ئاستەکێ بەری
    final t = (tier > 0 && r.nextDouble() < 0.4) ? r.nextInt(tier) : tier;
    final q = switch (t) {
      >= 5 => _objQ(r, true),
      4 => _objQ(r, false),
      3 => _possQ(r),
      _ => _subjectQ(r, t),
    };
    if (q != null && !out.any((x) => x.cloze.sentence == q.cloze.sentence && x.cloze.answer == q.cloze.answer)) out.add(q);
  }
  return out;
}

// ───────── ئینگلیزی ─────────
// I · you · he · she · we · they
const _enPron = ['I', 'you', 'he', 'she', 'we', 'they'];
const _enKu = ['ئەز', 'تو', 'ئەو (کوڕ)', 'ئەو (کچ)', 'ئەم', 'ئەو (هەمی)'];
const _enKuIdx = [0, 1, 2, 2, 3, 5];

class _EnVerb {
  final String inf, obj;
  final List<String> forms; // I, you, he/she, we, they
  final List<String> ku;
  const _EnVerb(this.inf, this.forms, this.obj, this.ku);
}

const _enVerbs = [
  _EnVerb('be', ['am', 'are', 'is', 'are', 'are'], 'tired',
      ['وەستیایمە', 'وەستیایی', 'وەستیایە', 'وەستیاینە', 'وەستیاینە', 'وەستیاینە']),
  _EnVerb('live', ['live', 'live', 'lives', 'live', 'live'], 'in Duhok',
      ['ل دهۆکێ دژیم', 'ل دهۆکێ دژی', 'ل دهۆکێ دژیت', 'ل دهۆکێ دژین', 'ل دهۆکێ دژین', 'ل دهۆکێ دژین']),
  _EnVerb('drink', ['drink', 'drink', 'drinks', 'drink', 'drink'], 'tea',
      ['چایێ ڤەدخۆم', 'چایێ ڤەدخۆی', 'چایێ ڤەدخوت', 'چایێ ڤەدخۆین', 'چایێ ڤەدخۆن', 'چایێ ڤەدخۆن']),
];
const _enFormIdx = [0, 1, 2, 2, 3, 4];

List<PronounQ> englishPronounQuestions(int tier, int count, [Random? rnd]) {
  final r = rnd ?? Random();
  final out = <PronounQ>[];
  final maxP = tier == 0 ? 2 : (tier == 1 ? 4 : 6);
  for (var k = 0; k < count * 6 && out.length < count; k++) {
    final t = (tier > 0 && r.nextDouble() < 0.4) ? r.nextInt(tier) : tier;
    PronounQ q;
    if (t >= 3) {
      // my, your, his … / me, him …
      const poss = ['my', 'your', 'his', 'her', 'our', 'their'];
      const obj = ['me', 'you', 'him', 'her', 'us', 'them'];
      const own = ['من', 'تە', 'وی', 'وێ', 'مە', 'وان'];
      final i = r.nextInt(6);
      if (t == 3) {
        final wrong = <String>{_enPron[i] == 'I' ? 'me' : _enPron[i], poss[(i + 1) % 6]}.toList();
        final ku = 'ئەڤە پەرتووکا ${_isIt(own[i])}.';
        final cz = ClozeInfo('This is ___ book. (${_enPron[i]})', poss[i], wrong, ku);
        q = PronounQ(_wc('This is ${poss[i]} book.', ku, cz), cz);
      } else {
        final wrong = <String>{_enPron[i], poss[i] == obj[i] ? poss[(i + 2) % 6] : poss[i]}.toList();
        final ku = 'لارا {o} دبینیت.'.replaceAll('{o}', own[i]);
        final cz = ClozeInfo('Lara sees ___.', obj[i], wrong, ku);
        q = PronounQ(_wc('Lara sees ${obj[i]}.', ku, cz), cz);
      }
    } else {
      final v = _enVerbs[r.nextInt(_enVerbs.length)];
      final p = r.nextInt(maxP);
      final form = v.forms[_enFormIdx[p]];
      final ku = '${_enKu[p]} ${v.ku[_enKuIdx[p]]}.';
      final wrong = (v.forms.toSet()..remove(form)).toList()..shuffle(r);
      if (wrong.isEmpty) continue;
      if (wrong.length < 2) wrong.add(v.inf == 'be' ? 'be' : '${v.inf}ing');
      final cz = ClozeInfo('${_cap(_enPron[p])} ___ ${v.obj}.', form, wrong.take(2).toList(), ku);
      q = PronounQ(_wc('${_cap(_enPron[p])} $form ${v.obj}.', ku, cz), cz);
    }
    if (!out.any((x) => x.cloze.sentence == q.cloze.sentence)) out.add(q);
  }
  return out;
}

List<PronounQ> pronounQuestions(AppLanguage target, int tier, int count) => switch (target) {
      AppLanguage.german => germanPronounQuestions(tier, count),
      AppLanguage.english => englishPronounQuestions(tier, count),
      _ => const [],
    };
