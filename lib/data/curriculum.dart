import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';

/// هەمی وانە ژ assets/curriculum.json دهێنە خواندن.
/// هەمان فایل د voice_lab/ دا ژی بۆ دروستکرنا دەنگێ کلۆنکری ب کار دهێت.
/// بۆ زێدەکرنا پەیڤان: تنێ JSON بگوهۆڕە (id دڤێت یێ تایبەت بیت).
late List<LessonUnit> appCurriculum;
late List<WordConcept> allConcepts;

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
};

Color _hex(String s) => Color(int.parse('FF${s.replaceAll('#', '')}', radix: 16));

Future<void> loadCurriculum() async {
  final raw = await rootBundle.loadString('assets/curriculum.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  appSections = ((data['sections'] as List?) ?? [])
      .map((s) => CurriculumSection(s['ku'] as String, s['de'] as String, s['en'] as String))
      .toList();
  appCurriculum = (data['units'] as List).map((u) {
    final m = u as Map<String, dynamic>;
    return LessonUnit(
      id: m['id'] as String,
      titleKu: m['titleKu'] as String,
      titleDe: m['titleDe'] as String,
      titleEn: m['titleEn'] as String,
      icon: _icons[m['icon']] ?? Icons.star_rounded,
      color: _hex(m['color'] as String),
      section: (m['section'] as num?)?.toInt() ?? 1,
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
        );
      }).toList(),
    );
  }).toList();
  allConcepts = appCurriculum.expand((u) => u.concepts).toList();
}
