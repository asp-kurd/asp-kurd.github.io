import '../models.dart';
import '../ui.dart';

/// ✅ پشکنینا بەرسڤێ ب نەرمی:
/// - هەمان رامان ب شێوازەکێ دی (Tschüss ⇄ Auf Wiedersehen) ➔ دروستە، دگەل تێبینیەکێ
/// - پەیڤێن نێزیک (Hut ⇄ Mütze) ➔ دروستە، دگەل ئامۆژگاریەکێ کا جوداهی چییە
/// - ئارتیکل ژ بیر چوو / خەلەتیەکا بچووک یا نڤیسینێ ➔ دروستە، دگەل تێبینیێ
/// - ئارتیکلێ خەلەت ➔ خەلەتە، بەلێ دبێژیت کا ئارتیکلێ دروست چییە
enum Verdict { exact, close, near, wrong }

class AnswerResult {
  final Verdict verdict;
  final String note;
  const AnswerResult(this.verdict, [this.note = '']);
  bool get accepted => verdict != Verdict.wrong;
  bool get soft => verdict == Verdict.close || verdict == Verdict.near; // دروستە بەلێ تێبینی هەیە
}

/// کۆمەکا شێوازان: [near] = نێزیکن بەلێ نە ئێک تشت
class _Group {
  final Map<String, String> forms; // شێواز ➔ تێبینیا وی (هەڤالینی / فەرمی …)
  final bool near;
  final String explain;
  const _Group(this.forms, {this.near = false, this.explain = ''});
}

const _de = <_Group>[
  _Group({
    'auf wiedersehen': 'ب رێز (فەرمی)',
    'tschüss': 'هەڤالینی',
    'tschüs': 'هەڤالینی',
    'auf wiederschauen': 'فەرمی (ل باشوورێ ئەلمانیا و نەمسا)',
    'bis bald': 'هەڤالینی — «هەتا زوو»',
    'bis später': 'هەڤالینی — «هەتا پاشتر»',
    'ciao': 'هەڤالینی',
    'tschüs bis später': 'هەڤالینی',
  }),
  _Group({
    'hallo': 'هەڤالینی',
    'guten tag': 'ب رێز (فەرمی)',
    'hi': 'گەلەک هەڤالینی',
    'servus': 'هەڤالینی (باشوورێ ئەلمانیا و نەمسا)',
    'grüß gott': 'ل باشوورێ ئەلمانیا و نەمسا',
    'moin': 'ل باکوورێ ئەلمانیا',
  }),
  _Group({
    "wie geht's": 'هەڤالینی',
    'wie gehts': 'هەڤالینی',
    'wie geht es dir': 'هەڤالینی (بۆ du)',
    'wie geht es ihnen': 'ب رێز (بۆ Sie)',
  }),
  _Group({'danke': '', 'danke schön': '', 'vielen dank': 'گەلەک سوپاس', 'danke sehr': '', 'dankeschön': ''}),
  _Group({'bitte': '', 'bitte schön': '', 'bitte sehr': '', 'gern geschehen': '«ب کەیفا خۆ» (بەرسڤا سوپاسیێ)'}),
  _Group({'super': '', 'toll': '', 'klasse': '', 'prima': '', 'spitze': ''}),
  _Group({'großvater': 'فەرمیتر', 'opa': 'ب خۆشەویستی'}),
  _Group({'großmutter': 'فەرمیتر', 'oma': 'ب خۆشەویستی'}),
  _Group({'vater': '', 'papa': 'ب خۆشەویستی'}),
  _Group({'mutter': '', 'mama': 'ب خۆشەویستی'}),
  _Group({'fahrrad': '', 'rad': 'کورتکری'}),
  _Group({'auto': '', 'wagen': ''}),
  _Group({'handy': '', 'smartphone': '', 'mobiltelefon': 'فەرمی'}),
  _Group({'samstag': '', 'sonnabend': 'ل باکوورێ ئەلمانیا'}),
  _Group({'sofa': '', 'couch': ''}),
  _Group({'straßenbahn': '', 'tram': ''}),
  _Group({'arzt': '', 'doktor': 'ب ئاخفتنێ'}),
  _Group({'ärztin': '', 'doktorin': 'ب ئاخفتنێ'}),
  _Group({'krankenschwester': 'ناڤێ کەڤن', 'pflegerin': '', 'pflegefachfrau': 'ناڤێ نوو یێ فەرمی'}),
  _Group({'krankenpfleger': '', 'pfleger': '', 'pflegefachmann': 'ناڤێ نوو یێ فەرمی'}),
  _Group({'pullover': '', 'pulli': 'کورتکری'}),
  _Group({'geschäft': '', 'laden': ''}),
  _Group({'kartoffel': '', 'erdapfel': 'ل نەمسا'}),
  _Group({'junge': '', 'bub': 'ل باشوورێ ئەلمانیا و نەمسا'}),
  _Group({'januar': '', 'jänner': 'ل نەمسا'}),
  _Group({'abendessen': '', 'abendbrot': ''}),
  _Group({'brötchen': '', 'semmel': 'ل باشوور و نەمسا'}),
  _Group({'zimmer': '', 'raum': ''}),
  _Group({'schön': '', 'hübsch': ''}),
  _Group({'prüfung': '', 'test': '', 'klausur': 'ل قوتابخانێ/زانکۆیێ'}),
  _Group({'fernseher': '', 'tv': ''}),
  _Group({'kühlschrank': ''}),
  // ───── نێزیک بەلێ نە ئێک تشت ➔ ئامۆژگاری ─────
  _Group({'mütze': '', 'hut': ''},
      near: true, explain: '«Hut» کولاڤەکا ڕەقە ب لێڤ (شەپقە)؛ «Mütze» کولاڤەکا نەرمە (یا هریێ یان یا وەرزشێ).'),
  _Group({'jacke': '', 'mantel': ''}, near: true, explain: '«Jacke» چاکێتە (کورتە)؛ «Mantel» قاپووتە (درێژە).'),
  _Group({'tasse': '', 'glas': '', 'becher': ''},
      near: true, explain: '«Tasse» کوپە (فنجان، بۆ چا و قەهوێ)؛ «Glas» پەرداخا شووشەیێ یە؛ «Becher» کوپا مەزنە بێ دەستک.'),
  _Group({'stuhl': '', 'sessel': ''}, near: true, explain: '«Stuhl» کورسیەکا سادەیە؛ «Sessel» کورسیەکا نەرمە (قەنەفا ئێک کەسی).'),
  _Group({'schrank': '', 'regal': ''}, near: true, explain: '«Schrank» دۆلابە (دەرگەهـ هەنە)؛ «Regal» رەفە (ڤەکرییە).'),
  _Group({'gewitter': '', 'sturm': ''}, near: true, explain: '«Gewitter» باران و برووسکە؛ «Sturm» بایێ دژوارە.'),
  _Group({'urlaub': '', 'ferien': ''},
      near: true, explain: '«Urlaub» مۆلەتا کاری یە؛ «Ferien» بێهنڤەدانا قوتابخانێ یان زانکۆیێ یە.'),
  _Group({'moped': '', 'roller': '', 'motorroller': ''},
      near: true, explain: '«Moped» ماتۆرەکا بچووکە ب پێدالان؛ «Roller» ڤێسپایە (ماتۆرا ب جهێ پێیان).'),
  _Group({'kuchen': '', 'torte': ''}, near: true, explain: '«Kuchen» کێکە (سادە)؛ «Torte» کێکا ب کرێم و چەند قاتە (یا جەژنان).'),
  _Group({'brot': '', 'brötchen': ''}, near: true, explain: '«Brot» نانە (مەزن)؛ «Brötchen» نانێ بچووکە (سەموون).'),
  _Group({'lampe': '', 'licht': ''}, near: true, explain: '«Lampe» ئامیرێ چرایێ یە؛ «Licht» رۆناهی یە.'),
  _Group({'wohnung': '', 'haus': ''}, near: true, explain: '«Wohnung» شوقەیە (د ئاڤاهیەکێ دا)؛ «Haus» خانیەکێ ب تنێ یە.'),
  _Group({'straße': '', 'weg': ''}, near: true, explain: '«Straße» جادەیە؛ «Weg» رێکە (هەر رێکەک، یان رێکا پیادان).'),
  _Group({'termin': '', 'verabredung': ''},
      near: true, explain: '«Termin» ژڤانێ فەرمی یە (نۆژدار، کار)؛ «Verabredung» ژڤانە دگەل هەڤالان.'),
  _Group({'anrufen': '', 'telefonieren': ''},
      near: true, explain: '«anrufen» = تەلەفۆنێ بۆ کەسەکی کرن؛ «telefonieren» = ب تەلەفۆنێ ئاخفتن.'),
  _Group({'kaufen': '', 'einkaufen': ''}, near: true, explain: '«kaufen» = تشتەکی کڕین؛ «einkaufen» = بازارکرن (چەند تشت).'),
  _Group({'entschuldigung': '', 'verzeihung': 'فەرمیتر', 'tut mir leid': ''},
      near: true, explain: '«Entschuldigung» = ببوورە (بۆ داخوازێ یان خەلەتیەکا بچووک)؛ «Tut mir leid» = مخابن / دلێ من پێڤە دمینیت.'),
  _Group({'ladegerät': '', 'ladekabel': ''}, near: true, explain: '«Ladegerät» شەحنکەرە؛ «Ladekabel» تنێ کێبلا شەحنێ یە.'),
];

const _en = <_Group>[
  _Group({'goodbye': 'فەرمیتر', 'bye': 'هەڤالینی', 'bye-bye': 'هەڤالینی', 'see you': 'هەڤالینی', 'see you later': 'هەڤالینی'}),
  _Group({'hello': '', 'hi': 'هەڤالینی', 'hey': 'گەلەک هەڤالینی'}),
  _Group({'thanks': 'هەڤالینی', 'thank you': '', 'thanks a lot': '', 'thank you very much': 'ب رێز'}),
  _Group({'mobile': 'بریتانی', 'mobile phone': 'بریتانی', 'cell phone': 'ئەمریکی', 'phone': '', 'smartphone': ''}),
  _Group({'holiday': 'بریتانی', 'holidays': 'بریتانی', 'vacation': 'ئەمریکی'}),
  _Group({'flat': 'بریتانی', 'apartment': 'ئەمریکی'}),
  _Group({'lift': 'بریتانی', 'elevator': 'ئەمریکی'}),
  _Group({'underground': 'بریتانی', 'tube': 'ل لەندەنێ', 'subway': 'ئەمریکی', 'metro': ''}),
  _Group({'petrol': 'بریتانی', 'gas': 'ئەمریکی'}),
  _Group({'trousers': 'بریتانی', 'pants': 'ئەمریکی'}),
  _Group({'football': 'بریتانی', 'soccer': 'ئەمریکی'}),
  _Group({'autumn': 'بریتانی', 'fall': 'ئەمریکی'}),
  _Group({'shop': 'بریتانی', 'store': 'ئەمریکی'}),
  _Group({'film': 'بریتانی', 'movie': 'ئەمریکی'}),
  _Group({'grandma': 'ب خۆشەویستی', 'grandmother': '', 'granny': 'ب خۆشەویستی'}),
  _Group({'grandpa': 'ب خۆشەویستی', 'grandfather': '', 'granddad': 'ب خۆشەویستی'}),
  _Group({'mum': 'بریتانی', 'mom': 'ئەمریکی', 'mother': ''}),
  _Group({'dad': '', 'father': ''}),
  _Group({'bike': '', 'bicycle': ''}),
  _Group({'tv': '', 'television': ''}),
  _Group({'great': '', 'super': '', 'awesome': '', 'cool': 'هەڤالینی'}),
  _Group({'hat': '', 'cap': ''}, near: true, explain: '«hat» کولاڤا ب لێڤ (شەپقە)؛ «cap» کولاڤا ب سیبەرێ (کاسکێت).'),
  _Group({'jacket': '', 'coat': ''}, near: true, explain: '«jacket» چاکێتە (کورتە)؛ «coat» قاپووتە (درێژە).'),
  _Group({'cup': '', 'glass': '', 'mug': ''}, near: true, explain: '«cup» کوپە (فنجان)؛ «glass» پەرداخا شووشەیێ؛ «mug» کوپا مەزن.'),
  _Group({'chair': '', 'armchair': ''}, near: true, explain: '«chair» کورسیە؛ «armchair» کورسیا نەرمە (قەنەفا ئێک کەسی).'),
  _Group({'sorry': '', 'excuse me': ''},
      near: true, explain: '«excuse me» = ببوورە (بۆ داخوازێ)؛ «sorry» = ببوورە (بۆ خەلەتیێ / مخابن).'),
  _Group({'call': '', 'phone': ''}, near: true, explain: 'هەردوو = تەلەفۆن کرن؛ «call» بەربەلاڤترە.'),
];

const _articles = {'der', 'die', 'das', 'den', 'dem', 'des', 'ein', 'eine', 'einen', 'einem', 'einer', 'the', 'a', 'an', 'to'};

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'[.,!?;:„“”"«»¿¡…–—()]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// ß/ss · ae/ä … وەکی ئێک
String _deep(String s) => _norm(s)
    .replaceAll('ß', 'ss')
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ss', 's')
    .replaceAll("'", '');

(String?, String) _split(String n) {
  final p = n.split(' ');
  if (p.length >= 2 && _articles.contains(p.first)) return (p.first, p.sublist(1).join(' '));
  return (null, n);
}

_Group? _groupOf(String n, List<_Group> gs) {
  final core = _split(n).$2;
  for (final g in gs) {
    if (g.forms.containsKey(n) || g.forms.containsKey(core)) return g;
  }
  final dc = _deep(core);
  for (final g in gs) {
    if (g.forms.keys.any((k) => _deep(k) == dc)) return g;
  }
  return null;
}

String _labelOf(_Group g, String n) {
  final core = _split(n).$2;
  return g.forms[n] ?? g.forms[core] ?? g.forms.entries.where((e) => _deep(e.key) == _deep(core)).map((e) => e.value).firstOrNull ?? '';
}

int _lev(String a, String b) {
  if ((a.length - b.length).abs() > 2) return 3;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

String _gender(String a) => switch (a) { 'der' => 'نێر', 'die' => 'مێ', 'das' => 'بێلایەن', _ => '' };

/// [typed] = بەرسڤ هاتە نڤیسین (نە هەلبژارتن) ➔ ئارتیکل و خەلەتیێن بچووک ژی دهێنە پشکنین
AnswerResult judgeAnswer(String given, String expected, AppLanguage lang, {bool typed = false, AppLanguage ui = AppLanguage.badini}) {
  final g = _norm(given);
  if (g.isEmpty) return const AnswerResult(Verdict.wrong);
  final alts = expected.split(RegExp(r'\s+/\s+|\s+–\s+')).map(_norm).where((e) => e.isNotEmpty).toList();
  final best = expected.split(RegExp(r'\s+/\s+')).first.trim();
  if (alts.contains(g) || _norm(expected) == g) return const AnswerResult(Verdict.exact);

  // ١) نڤیسینا ب شێوەیەکێ دی: ß ⇄ ss · ä ⇄ ae
  if (alts.any((e) => _deep(e) == _deep(g))) {
    final umlaut = RegExp(r'ae|oe|ue').hasMatch(g) && RegExp('[äöü]').hasMatch(alts.join());
    return AnswerResult(
        Verdict.close,
        umlaut
            ? tr(ui, 'دروستە ✅ — بەلێ ب ئەلمانی «ä ö ü» بنڤیسە: «$best»', 'Richtig ✅ — schreib aber mit Umlaut: „$best“',
                'Correct ✅ — spelled: “$best”')
            : tr(ui, 'دروستە ✅ — ب هەردوو شێوەیان دهێتە نڤیسین. نڤیسینا مە: «$best»', 'Richtig ✅ — beide Schreibweisen gehen: „$best“',
                'Correct ✅ — both spellings work: “$best”'));
  }

  // ٢) هەمان رامان / پەیڤا نێزیک
  final gs = lang == AppLanguage.german ? _de : (lang == AppLanguage.english ? _en : const <_Group>[]);
  final gg = _groupOf(g, gs);
  if (gg != null) {
    for (final e in alts) {
      if (_groupOf(e, gs) != gg) continue;
      // ئارتیکلێ خەلەت ب پەیڤەکا هەمان کۆمێ؟ (die Opa) ➔ ئارتیکل
      final (ag, _) = _split(g);
      final (ae, _) = _split(e);
      final lg = _labelOf(gg, g), le = _labelOf(gg, e);
      if (!gg.near) {
        final diff = lg.isNotEmpty || le.isNotEmpty
            ? '\n«${given.trim()}»${lg.isNotEmpty ? ' = $lg' : ''}  ·  «$best»${le.isNotEmpty ? ' = $le' : ''}'
            : '';
        if (typed && lang == AppLanguage.german && ag != null && ae != null && ag != ae && _split(g).$2 == _split(e).$2) break;
        return AnswerResult(Verdict.close,
            '${tr(ui, 'دروستە ✅ — بەلێ ل ڤێرێ یا دروستتر «$best» ە.', 'Richtig ✅ — hier passt aber besser „$best“.', 'Correct ✅ — but “$best” fits better here.')}$diff');
      }
      return AnswerResult(Verdict.near,
          '${tr(ui, 'نێزیکە 👍 — بەلێ یا دروست «$best» ە.', 'Fast 👍 — richtig ist „$best“.', 'Close 👍 — the right word is “$best”.')}\n💡 ${gg.explain}');
    }
  }

  if (typed) {
    for (final e in alts) {
      final (ae, ne) = _split(e);
      final (ag, ng) = _split(g);
      final sameNoun = ne == ng || _deep(ne) == _deep(ng);
      // ٣) ئارتیکل (تنێ ئەلمانی)
      if (lang == AppLanguage.german && sameNoun && ae != null && const {'der', 'die', 'das'}.contains(ae)) {
        if (ag == null) {
          return AnswerResult(Verdict.close,
              tr(ui, 'دروستە ✅ — بەلێ ئارتیکل ژ بیر نەکە: «$best» (${_gender(ae)})', 'Richtig ✅ — vergiss den Artikel nicht: „$best“',
                  'Correct ✅ — don’t forget the article: “$best”'));
        }
        if (ag != ae) {
          return AnswerResult(Verdict.wrong,
              tr(ui, 'پەیڤ دروستە 👍 بەلێ ئارتیکلێ وێ «$ae» ە (${_gender(ae)}): «$best»', 'Wort richtig 👍 aber der Artikel ist „$ae“: „$best“',
                  'Right word 👍 but the article is “$ae”: “$best”'));
        }
      }
      // ٤) خەلەتیەکا بچووک یا نڤیسینێ
      final a = _deep(g), b = _deep(e);
      if (b.length >= 4 && _lev(a, b) <= (b.length >= 9 ? 2 : 1)) {
        return AnswerResult(Verdict.close,
            tr(ui, 'دروستە ✅ — خەلەتیەکا بچووک یا نڤیسینێ هەبوو. دروست: «$best»', 'Richtig ✅ — kleiner Tippfehler. Richtig: „$best“',
                'Correct ✅ — small typo. Spelled: “$best”'));
      }
    }
  }
  return const AnswerResult(Verdict.wrong);
}
