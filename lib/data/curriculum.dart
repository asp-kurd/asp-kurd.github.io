import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';

/// هەمی وانە ژ assets/curriculum.json دهێنە خواندن.
/// هەمان فایل د voice_lab/ دا ژی بۆ دروستکرنا دەنگێ کلۆنکری ب کار دهێت.
/// بۆ زێدەکرنا پەیڤان: تنێ JSON بگوهۆڕە (id دڤێت یێ تایبەت بیت).
late List<LessonUnit> appCurriculum;
late List<WordConcept> allConcepts;

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
};

Color _hex(String s) => Color(int.parse('FF${s.replaceAll('#', '')}', radix: 16));

Future<void> loadCurriculum() async {
  final raw = await rootBundle.loadString('assets/curriculum.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  appCurriculum = (data['units'] as List).map((u) {
    final m = u as Map<String, dynamic>;
    return LessonUnit(
      id: m['id'] as String,
      titleKu: m['titleKu'] as String,
      titleDe: m['titleDe'] as String,
      titleEn: m['titleEn'] as String,
      icon: _icons[m['icon']] ?? Icons.star_rounded,
      color: _hex(m['color'] as String),
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
