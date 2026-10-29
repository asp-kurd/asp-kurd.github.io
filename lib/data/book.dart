import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';

/// 📖 پەرتووکا رێزمانێ «A1.1 mit Poya» ژ assets/book.json
/// ئەو فایل ب voice_lab/build_book.py ژ book/A1_mit_Poya.md دهێتە دروستکرن.

class BookPart {
  final int id;
  final String ku, de, en;
  const BookPart(this.id, this.ku, this.de, this.en);
  String title(AppLanguage l) => switch (l) {
        AppLanguage.badini => ku,
        AppLanguage.german => de,
        AppLanguage.english => en,
      };
}

class QuizItem {
  final String q, a;
  const QuizItem(this.q, this.a);
}

/// ئێک بلۆک د ناڤ بەشەکێ دا (سەرناڤ، پاراگراف، لیست، خشتە، فەرهەنگۆک، راهێنان)
class BookBlock {
  final String type; // h, p, ul, ol, table, vocab, quiz
  final String text;
  final List<String> items;
  final List<String> head;
  final List<List<String>> rows;
  final String gender; // بۆ vocab: der / die / das
  final List<QuizItem> quiz;

  const BookBlock({
    required this.type,
    this.text = '',
    this.items = const [],
    this.head = const [],
    this.rows = const [],
    this.gender = '',
    this.quiz = const [],
  });

  factory BookBlock.fromJson(Map<String, dynamic> m) {
    List<String> strs(dynamic v) => ((v as List?) ?? []).map((e) => e as String).toList();
    final t = m['t'] as String;
    return BookBlock(
      type: t,
      text: (m['text'] ?? m['why'] ?? '') as String,
      items: t == 'vocab' ? const [] : strs(m['items']),
      head: strs(m['head']),
      rows: t == 'vocab'
          ? ((m['items'] as List).map((r) => strs(r)).toList())
          : ((m['rows'] as List?) ?? []).map((r) => strs(r)).toList(),
      gender: (m['gender'] ?? '') as String,
      quiz: t == 'quiz'
          ? (m['items'] as List).map((e) => QuizItem(e['q'] as String, e['a'] as String)).toList()
          : const [],
    );
  }
}

class BookChapter {
  final String id;
  final int part;
  final String title;
  final IconData icon;
  final Color color;
  final List<BookBlock> blocks;
  const BookChapter(this.id, this.part, this.title, this.icon, this.color, this.blocks);

  /// «بەشێ ٥: جێناڤ ...» ➔ («بەشێ ٥»، «جێناڤ ...»)
  (String, String) get split {
    final i = title.indexOf(':');
    if (i < 0) return ('', title);
    return (title.substring(0, i).trim(), title.substring(i + 1).trim());
  }
}

const _bookIcons = <String, IconData>{
  'flag': Icons.flag_rounded,
  'abc': Icons.abc_rounded,
  'waving_hand': Icons.waving_hand_rounded,
  'badge': Icons.badge_rounded,
  'pin': Icons.pin_rounded,
  'person': Icons.person_rounded,
  'help': Icons.help_rounded,
  'article': Icons.article_rounded,
  'family': Icons.family_restroom_rounded,
  'looks_one': Icons.looks_one_rounded,
  'looks_two': Icons.looks_two_rounded,
  'looks_3': Icons.looks_3_rounded,
  'swap': Icons.swap_vert_rounded,
  'call_split': Icons.call_split_rounded,
  'schedule': Icons.schedule_rounded,
  'history': Icons.history_rounded,
  'update': Icons.update_rounded,
  'chat': Icons.forum_rounded,
  'menu_book': Icons.menu_book_rounded,
  'quiz': Icons.quiz_rounded,
};

Color _hex(String s) => Color(int.parse('FF${s.replaceAll('#', '')}', radix: 16));

late List<BookPart> bookParts;
late List<BookChapter> bookChapters;

Future<void> loadBook() async {
  try {
    final data = jsonDecode(await rootBundle.loadString('assets/book.json')) as Map<String, dynamic>;
    bookParts = (data['parts'] as List)
        .map((p) => BookPart((p['id'] as num).toInt(), p['ku'] as String, p['de'] as String, p['en'] as String))
        .toList();
    bookChapters = (data['chapters'] as List).map((c) {
      final m = c as Map<String, dynamic>;
      return BookChapter(
        m['id'] as String,
        (m['part'] as num).toInt(),
        m['title'] as String,
        _bookIcons[m['icon']] ?? Icons.menu_book_rounded,
        _hex(m['color'] as String),
        (m['blocks'] as List).map((b) => BookBlock.fromJson(b as Map<String, dynamic>)).toList(),
      );
    }).toList();
  } catch (_) {
    // ئەگەر فایل نەبیت، ئەپ هەر کار دکەت
    bookParts = const [];
    bookChapters = const [];
  }
}
