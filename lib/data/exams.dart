import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// جۆرێن پرسیاران د ئەزموونان دا
enum QType { choice, truefalse, picture, imgchoice, listen, type, order }

class ExamQuestion {
  final QType type;
  final String q; // پرسیار / دەق / ئیمۆجی
  final List<String> options;
  final dynamic answer; // int (index) یان String (type/order)
  final String explain;
  final String? audio; // دەقێ ئەلمانی بۆ گوهداریێ
  final String? pic;
  final int level; // بۆ تاقیکرنا ئاستی

  const ExamQuestion({
    required this.type,
    required this.q,
    required this.options,
    required this.answer,
    this.explain = '',
    this.audio,
    this.pic,
    this.level = 0,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> j) => ExamQuestion(
        type: QType.values.firstWhere((t) => t.name == j['type'], orElse: () => QType.choice),
        q: (j['q'] as String?) ?? '',
        options: ((j['options'] as List?) ?? const []).map((e) => e.toString()).toList(),
        answer: j['answer'],
        explain: (j['explain'] as String?) ?? '',
        audio: j['audio'] as String?,
        pic: j['pic'] as String?,
        level: (j['level'] as num?)?.toInt() ?? 0,
      );
}

class ExamPart {
  final String id, titleKu;
  final List<ExamQuestion> items;
  const ExamPart(this.id, this.titleKu, this.items);
}

class Exams {
  static Map<int, List<ExamQuestion>> lektion = {};
  static String finalTitleKu = '';
  static List<ExamPart> finalParts = [];
  static List<ExamQuestion> placement = [];

  static Future<void> load() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/exams.json')) as Map<String, dynamic>;
      lektion = (j['lektion'] as Map<String, dynamic>).map((k, v) => MapEntry(
          int.parse(k), (v as List).map((e) => ExamQuestion.fromJson(e as Map<String, dynamic>)).toList()));
      final f = j['final'] as Map<String, dynamic>;
      finalTitleKu = f['titleKu'] as String;
      finalParts = (f['parts'] as List).map((p) {
        final m = p as Map<String, dynamic>;
        return ExamPart(m['id'] as String, m['titleKu'] as String,
            (m['items'] as List).map((e) => ExamQuestion.fromJson(e as Map<String, dynamic>)).toList());
      }).toList();
      placement = (j['placement'] as List).map((e) => ExamQuestion.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // ئەگەر فایل نەبیت، ئەپ هەر کار دکەت
    }
  }
}
