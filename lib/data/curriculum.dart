import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';
import '../services/progress_service.dart';

/// هەمی وانە ژ assets/curriculum.json دهێنە خواندن.
/// هەمان فایل د voice_lab/ دا ژی بۆ دروستکرنا دەنگێ کلۆنکری ب کار دهێت.
/// بۆ زێدەکرنا پەیڤان: تنێ JSON بگوهۆڕە (id دڤێت یێ تایبەت بیت).
List<LessonUnit> _allUnits = [];
int _bundledVersion = 0;

/// قۆناغێن زمانێ هەلبژارتی (ئەلفوبێیا کوردی بۆ فێربوونا ئەلمانی نائێت، و هوسا)
List<LessonUnit> get appCurriculum => _visible();
List<WordConcept> get allConcepts => _visibleConcepts;

String? _cacheKey;
List<LessonUnit> _cacheUnits = [];
List<WordConcept> _visibleConcepts = [];
List<LessonUnit> _visible() {
  final t = ProgressService.instance.targetLang.code;
  final key = '$t#${identityHashCode(_allUnits)}';
  if (key != _cacheKey) {
    final units = _allUnits.where((u) => u.only == null || u.only == t).toList();
    _cacheUnits = [for (var i = 0; i < units.length; i++) units[i].numbered(i + 1)];
    _visibleConcepts = _cacheUnits.expand((u) => u.concepts).toList();
    _cacheKey = key;
  }
  return _cacheUnits;
}

/// ناڤێن بەشان (A1 / A2 ...)
class CurriculumSection {
  final String ku, de, en;
  const CurriculumSection(this.ku, this.de, this.en);
  String title(AppLanguage l) => switch (l) {
        AppLanguage.badini => ku,
        AppLanguage.german => de,
        AppLanguage.english => en,
      };
}

late List<CurriculumSection> appSections;

/// وانەیێن پەرتووکێ (Lektion 1–14): دیالۆگ و ناڤ
List<LektionInfo> appLektionen = [];

LektionInfo? lektionForSection(int section) {
  for (final l in appLektionen) {
    if (l.section == section) return l;
  }
  return null;
}

const _icons = <String, IconData>{
  'waving_hand': Icons.waving_hand_rounded,
  'pin': Icons.pin_rounded,
  'family': Icons.family_restroom_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'city': Icons.location_city_rounded,
  'schedule': Icons.schedule_rounded,
  'palette': Icons.palette_rounded,
  'body': Icons.accessibility_new_rounded,
  'run': Icons.directions_run_rounded,
  'chat': Icons.forum_rounded,
  'calendar': Icons.calendar_month_rounded,
  'sun': Icons.wb_sunny_rounded,
  'weather': Icons.cloud_rounded,
  'home': Icons.home_rounded,
  'clothes': Icons.checkroom_rounded,
  'food': Icons.restaurant_menu_rounded,
  'restaurant': Icons.local_dining_rounded,
  'transport': Icons.directions_bus_rounded,
  'directions': Icons.signpost_rounded,
  'work': Icons.work_rounded,
  'health': Icons.local_hospital_rounded,
  'mood': Icons.mood_rounded,
  'tune': Icons.tune_rounded,
  'sports': Icons.sports_soccer_rounded,
  'help': Icons.help_rounded,
  'badge': Icons.badge_rounded,
  'history': Icons.history_rounded,
  'flag': Icons.flag_rounded,
  'abc': Icons.abc_rounded,
  'people': Icons.groups_rounded,
  'person': Icons.person_rounded,
  'backpack': Icons.backpack_rounded,
};

Color _hex(String s) => Color(int.parse('FF${s.replaceAll('#', '')}', radix: 16));

/// [override] = ناڤەرۆکا گوهۆڕی ژ لایێ ئەدمینی (ژ سێرڤەری)
Future<void> loadCurriculum([String? override]) async {
  final bundled = await rootBundle.loadString('assets/curriculum.json');
  _bundledVersion = ((jsonDecode(bundled) as Map)['version'] as num?)?.toInt() ?? 0;
  if (override != null) {
    try {
      // ناڤەرۆکا ئەدمینی یا کەڤن (بەری نوویکرنا ئەپێ) نابیت یا نوو بشێلیت
      _parse(override, minVersion: _bundledVersion);
      return;
    } catch (_) {
      // ئەگەر ناڤەرۆکا سێرڤەری خراب یان کەڤن بیت، یا ئەسلی ب کار بینە
    }
  }
  _parse(bundled);
}

void _parse(String raw, {int minVersion = 0}) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  if (((data['version'] as num?)?.toInt() ?? 0) < minVersion) throw StateError('old content');
  appSections = ((data['sections'] as List?) ?? [])
      .map((s) => CurriculumSection(s['ku'] as String, s['de'] as String, s['en'] as String))
      .toList();
  final strip = RegExp(r'^(قۆناغا [٠-٩]+: |Einheit \d+: |Unit \d+: )');
  _allUnits = (data['units'] as List).map((u) {
    final m = u as Map<String, dynamic>;
    return LessonUnit(
      id: m['id'] as String,
      only: m['only'] as String?,
      titleKu: (m['titleKu'] as String).replaceFirst(strip, ''),
      titleDe: (m['titleDe'] as String).replaceFirst(strip, ''),
      titleEn: (m['titleEn'] as String).replaceFirst(strip, ''),
      icon: _icons[m['icon']] ?? Icons.star_rounded,
      color: _hex(m['color'] as String),
      section: (m['section'] as num?)?.toInt() ?? 1,
      grammar: _grammar(m['grammar']),
      concepts: (m['concepts'] as List).map((c) {
        final x = c as Map<String, dynamic>;
        return WordConcept(
          x['id'] as String,
          ku: x['ku'] as String,
          kuLat: x['kuLat'] as String,
          de: x['de'] as String,
          deHint: x['deHint'] as String,
          en: x['en'] as String,
          enHint: x['enHint'] as String,
          emoji: (x['emoji'] as String?) ?? '',
          letter: _letter(x['letter']),
        );
      }).toList(),
    );
  }).toList();
  _cacheKey = null;
  appLektionen = ((data['lektionen'] as List?) ?? []).map((l) {
    final m = l as Map<String, dynamic>;
    final d = m['dialog'] as Map<String, dynamic>;
    return LektionInfo(
      n: (m['n'] as num).toInt(),
      titleKu: m['titleKu'] as String,
      titleDe: m['titleDe'] as String,
      titleEn: m['titleEn'] as String,
      color: _hex(m['color'] as String),
      dialogTitleKu: d['titleKu'] as String,
      dialog: (d['lines'] as List)
          .map((x) => DialogLine(x['id'] as String, x['who'] as String, x['de'] as String, x['ku'] as String))
          .toList(),
    );
  }).toList();
}

LetterInfo? _letter(dynamic l) {
  if (l is! Map) return null;
  return LetterInfo(
    upper: l['L'] as String,
    lower: (l['lower'] as String?) ?? '',
    name: (l['name'] as String?) ?? '',
    sound: (l['sound'] as String?) ?? '',
    word: (l['word'] as String?) ?? '',
    read: (l['read'] as String?) ?? '',
  );
}

GrammarCard? _grammar(dynamic g) {
  if (g is! Map<String, dynamic>) return null;
  final t = g['table'];
  return GrammarCard(
    titleKu: g['titleKu'] as String,
    titleDe: (g['titleDe'] as String?) ?? '',
    lines: (g['lines'] as List).map((e) => e as String).toList(),
    table: t is List ? t.map((r) => (r as List).map((c) => c.toString()).toList()).toList() : null,
  );
}
