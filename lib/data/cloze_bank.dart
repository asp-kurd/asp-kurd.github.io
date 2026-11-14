import 'dart:convert';

import 'package:flutter/services.dart';

import '../models.dart';
import 'cast.dart';

/// 📝 رستەیێن جهێ ڤالا یێن زێدە بۆ هەر قۆناغەکێ (assets/cloze.json)
/// «Ich ___ gern Musik.» ➔ höre — و ژ قۆناغا ~٢٠ ڤە هندەک ب ٢ جهێن ڤالا: «Ich ___ um 7 Uhr ___.» ➔ stehe … auf
class ClozeEntry {
  final ClozeInfo info;
  final String conceptId; // '' = بۆ هەمی قۆناغێ
  const ClozeEntry(this.info, this.conceptId);
  bool get multi => info.answer.contains(' … ');
}

final Map<String, Map<String, List<ClozeEntry>>> _bank = {};

Future<void> loadClozeBank() async {
  try {
    final raw = jsonDecode(CastStore.text(await rootBundle.loadString('assets/cloze.json'))) as Map<String, dynamic>;
    final units = raw['units'] as Map<String, dynamic>;
    for (final u in units.entries) {
      final m = <String, List<ClozeEntry>>{};
      for (final l in (u.value as Map<String, dynamic>).entries) {
        m[l.key] = [
          for (final e in l.value as List)
            ClozeEntry(
              ClozeInfo(e['s'] as String, e['a'] as String, [for (final d in e['d'] as List) '$d'], (e['ku'] as String?) ?? ''),
              (e['c'] as String?) ?? '',
            ),
        ];
      }
      _bank[u.key] = m;
    }
  } catch (_) {}
}

List<ClozeEntry> clozeBankFor(String unitId, AppLanguage target) => _bank[unitId]?[target.code] ?? const [];

/// هەمی رستەیێن ڤی زمانی (بۆ دووبارەکرنا خەلەتیان)
ClozeEntry? clozeForConcept(String conceptId, AppLanguage target) {
  for (final u in _bank.values) {
    for (final e in u[target.code] ?? const <ClozeEntry>[]) {
      if (e.conceptId == conceptId) return e;
    }
  }
  return null;
}

/// رستا تەمام بۆ دەنگی — بێ (8:30) ل دویماهیێ
String clozeSpeech(ClozeInfo z) => z.filled(z.answer).replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
