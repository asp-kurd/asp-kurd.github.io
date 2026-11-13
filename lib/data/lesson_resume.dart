import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'curriculum.dart';

/// ⏯️ بەردەوامی د وانێ دا: پشتی هەر پرسیارەکێ جهـ دهێتە پاراستن.
/// ئەگەر فێرخواز ژ ئەپێ دەرکەفت (یان ئەپ هاتە گرتن)، دەمێ دزڤڕیت دشێت ژ هەمان جهی بەردەوام بیت.
class LessonResume {
  static const _ttl = Duration(days: 14);
  static SharedPreferences? _sp;
  static Future<SharedPreferences> get _p async => _sp ??= await SharedPreferences.getInstance();

  static String _k(String key) => 'resume_$key';

  /// یا هاتییە هەلبژارتن بۆ بەردەوامیێ (وانە دێ ڤێ وەرگریت دەمێ ڤەدبیت)
  static Map<String, dynamic>? pending;

  /// (پرسیارا نوکە، هەمی) یان null
  static Future<(int, int)?> peek(String key) async {
    final m = await load(key);
    if (m == null) return null;
    return ((m['i'] as num).toInt(), (m['q'] as List).length);
  }

  static Future<Map<String, dynamic>?> load(String key) async {
    try {
      final raw = (await _p).getString(_k(key));
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final ts = DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt());
      final i = (m['i'] as num).toInt(), n = (m['q'] as List).length;
      if (DateTime.now().difference(ts) > _ttl || i <= 0 || i >= n) {
        await clear(key);
        return null;
      }
      return m;
    } catch (_) {
      await clear(key);
      return null;
    }
  }

  static Future<void> save(String key, Map<String, dynamic> state) async {
    try {
      (await _p).setString(_k(key), jsonEncode({...state, 'ts': DateTime.now().millisecondsSinceEpoch}));
    } catch (_) {}
  }

  static Future<void> clear(String key) async {
    try {
      (await _p).remove(_k(key));
    } catch (_) {}
  }

  // ───────── پرسیار ⇄ JSON ─────────
  static Map<String, dynamic>? _cz(ClozeInfo? z) => z == null ? null : {'s': z.sentence, 'a': z.answer, 'd': z.distractors, 'k': z.ku};

  static ClozeInfo? _czOf(dynamic j) {
    if (j is! Map) return null;
    return ClozeInfo('${j['s']}', '${j['a']}', [for (final x in (j['d'] as List? ?? const [])) '$x'], '${j['k'] ?? ''}');
  }

  static Map<String, dynamic> _c(WordConcept c) => conceptById(c.id) != null
      ? {'i': c.id}
      // پەیڤا دەستکرد (پرسیارێن جهێناڤان)
      : {'i': c.id, 'ku': c.ku, 'de': c.de, 'en': c.en, 'e': c.emoji, 'z': _cz(c.cloze)};

  static WordConcept? _cOf(dynamic j) {
    if (j is! Map) return null;
    final id = '${j['i']}';
    final known = conceptById(id);
    if (known != null) return known;
    if (j['de'] == null) return null;
    return WordConcept(id,
        ku: '${j['ku']}', kuLat: '', de: '${j['de']}', deHint: '', en: '${j['en']}', enHint: '', emoji: '${j['e'] ?? ''}', cloze: _czOf(j['z']));
  }

  static Map<String, dynamic> exToJson(Exercise e) => {
        'c': _c(e.concept),
        't': e.type.name,
        if (e.group.isNotEmpty) 'g': [for (final g in e.group) _c(g)],
        if (e.cloze != null) 'z': _cz(e.cloze),
      };

  static Exercise? exFromJson(dynamic j) {
    if (j is! Map) return null;
    final c = _cOf(j['c']);
    final t = ExerciseType.values.where((x) => x.name == j['t']).firstOrNull;
    if (c == null || t == null) return null;
    final g = [for (final x in (j['g'] as List? ?? const [])) _cOf(x)].whereType<WordConcept>().toList();
    return Exercise(c, t, group: g, cloze: _czOf(j['z']));
  }
}
