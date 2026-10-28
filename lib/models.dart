import 'package:flutter/material.dart';

/// ١. زمانێن ئەپی
enum AppLanguage {
  badini('کوردی (بادینی)', '☀️', TextDirection.rtl, 'ku', null),
  german('Deutsch (ئەلمانی)', '🇩🇪', TextDirection.ltr, 'de', 'de-DE'),
  english('English (ئینگلیزی)', '🇬🇧', TextDirection.ltr, 'en', 'en-US');

  final String title;
  final String flag;
  final TextDirection direction;
  final String code;

  /// کۆدێ TTS. بۆ بادینی TTS نینە، لەوما دەنگێ تە یێ تۆمارکری سەرەکییە.
  final String? ttsCode;

  const AppLanguage(this.title, this.flag, this.direction, this.code, this.ttsCode);

  static AppLanguage fromCode(String? code, AppLanguage fallback) =>
      AppLanguage.values.firstWhere((l) => l.code == code, orElse: () => fallback);
}

/// ٢. پەیڤ / رستە ب هەرسێ زمانان
class WordConcept {
  final String id;
  final String ku, kuLat; // بادینی + خوێندنا لاتینی
  final String de, deHint; // ئەلمانی + خوێندن ب کوردی / تێبینیا رێزمانێ
  final String en, enHint; // ئینگلیزی + خوێندن ب کوردی

  const WordConcept(
    this.id, {
    required this.ku,
    required this.kuLat,
    required this.de,
    required this.deHint,
    required this.en,
    required this.enHint,
  });

  String text(AppLanguage l) => switch (l) {
        AppLanguage.badini => ku,
        AppLanguage.german => de,
        AppLanguage.english => en,
      };

  String hint(AppLanguage l) => switch (l) {
        AppLanguage.badini => kuLat,
        AppLanguage.german => deHint,
        AppLanguage.english => enHint,
      };
}

/// ٣. پێنگاڤ (Unit)
class LessonUnit {
  final String id;
  final String titleKu, titleDe, titleEn;
  final IconData icon;
  final Color color;
  final List<WordConcept> concepts;
  final int section; // 1, 2, 3 ...

  const LessonUnit({
    this.section = 1,
    required this.id,
    required this.titleKu,
    required this.titleDe,
    required this.titleEn,
    required this.icon,
    required this.color,
    required this.concepts,
  });

  String title(AppLanguage l) => switch (l) {
        AppLanguage.badini => titleKu,
        AppLanguage.german => titleDe,
        AppLanguage.english => titleEn,
      };
}

/// ٤. جۆرێن ڕاهێنانان
enum ExerciseType {
  translate, // زمانێ دایکێ ➔ زمانێ فێربوونێ
  reverse, // زمانێ فێربوونێ ➔ زمانێ دایکێ
  listen, // گوهداری بکە و رامانێ هەلبژێرە
  speak, // ب دەنگێ خۆ بێژە و بەراورد بکە
  match, // جووتکرنا پەیڤان (٤ جووت)
  wordBank, // ئاڤاکرنا رستێ ژ پارچەیان
}

class Exercise {
  final WordConcept concept;
  final ExerciseType type;

  /// بۆ match: هەمی پەیڤێن جووتکرنێ
  final List<WordConcept> group;
  const Exercise(this.concept, this.type, {this.group = const []});
}

/// خەلات / دەستکەفت
class Achievement {
  final String id;
  final String emoji;
  final String ku, de, en;
  final bool unlocked;
  const Achievement(this.id, this.emoji, this.ku, this.de, this.en, this.unlocked);
}
