import 'dart:convert';

import 'package:flutter/services.dart';

import '../models.dart';

/// 📖 رامانا پەیڤەکێ: «der Tisch ➔ مێز · ئارتیکل: der»
class Gloss {
  final String word; // وەکی د فەرهەنگێ دا (Tisch)
  final String ku; // رامان ب کوردی
  final String article; // der / die / das / '' (pl ➔ die)
  final bool plural;
  final bool name; // ناڤێ کەسەکی / جهەکی
  final String base; // فۆرما بنەڕەت (bin ➔ sein)
  const Gloss(this.word, this.ku, {this.article = '', this.plural = false, this.name = false, this.base = ''});
}

/// 📖 فەرهەنگا پەیڤان (assets/glossary.json — ژ content/glossary/*.tsv دهێتە ئاڤاکرن)
class Glossary {
  static final Map<String, Map<String, List<String>>> _g = {};
  static final Map<String, Map<String, String>> _lower = {}; // بچووک ➔ کلیلا راست

  /// پەیڤ (دگەل - و ' : «E-Mail»، «geht's»)
  static final wordRe = RegExp(r"[A-Za-zÄÖÜäöüß]+(?:[-'’][A-Za-zÄÖÜäöüß]+)*");

  static Future<void> load() async {
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/glossary.json')) as Map<String, dynamic>;
      for (final l in raw.entries) {
        final m = <String, List<String>>{};
        final low = <String, String>{};
        for (final e in (l.value as Map<String, dynamic>).entries) {
          m[e.key] = [for (final x in e.value as List) '$x'];
          low.putIfAbsent(e.key.toLowerCase(), () => e.key);
        }
        _g[l.key] = m;
        _lower[l.key] = low;
      }
    } catch (_) {}
  }

  static Gloss? lookup(String word, AppLanguage lang) {
    final m = _g[lang.code];
    if (m == null) return null;
    final w = word.replaceAll('’', "'");
    var key = m.containsKey(w) ? w : null;
    key ??= _lower[lang.code]?[w.toLowerCase()];
    if (key == null) return null;
    final v = m[key]!;
    final note = v.length > 1 ? v[1] : '';
    final parts = note.split('>');
    final a = parts.first;
    return Gloss(
      key,
      v.first,
      article: a == 'pl' ? 'die' : (a == 'der' || a == 'die' || a == 'das' ? a : ''),
      plural: a == 'pl',
      name: a == 'N',
      base: parts.length > 1 ? parts[1] : '',
    );
  }
}
