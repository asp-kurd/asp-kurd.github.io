import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/curriculum.dart';
import '../models.dart';
import 'voice_service.dart';

/// پاشەکەفتکرنا پێشکەفتنێ: XP، Streak، دل، پێنگاڤێن تەمامکری، و زمان.
class ProgressService extends ChangeNotifier {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  static const maxHearts = 5;
  late SharedPreferences _p;

  AppLanguage nativeLang = AppLanguage.badini;
  AppLanguage targetLang = AppLanguage.german;
  bool onboarded = false;
  int xp = 0;
  int streak = 0;
  int hearts = maxHearts;
  Set<String> completedUnits = {};
  Map<String, int> mistakes = {}; // conceptId -> ژمارا خەلەتیان (بۆ دووبارەکرنێ)

  // ئارمانجا رۆژانە و ئامار
  int dailyGoal = 30; // XP
  int todayXp = 0;
  int lessonsDone = 0;
  int perfectLessons = 0;
  int bestStreak = 0;

  double get dailyProgress => (todayXp / dailyGoal).clamp(0.0, 1.0);
  bool get dailyGoalMet => todayXp >= dailyGoal;

  String get _pairKey => '${nativeLang.code}_${targetLang.code}';

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    nativeLang = AppLanguage.fromCode(_p.getString('native'), AppLanguage.badini);
    targetLang = AppLanguage.fromCode(_p.getString('target'), AppLanguage.german);
    onboarded = _p.getBool('onboarded') ?? false;
    xp = _p.getInt('xp') ?? 0;
    streak = _p.getInt('streak') ?? 0;
    dailyGoal = _p.getInt('daily_goal') ?? 30;
    lessonsDone = _p.getInt('lessons_done') ?? 0;
    perfectLessons = _p.getInt('perfect_lessons') ?? 0;
    bestStreak = _p.getInt('best_streak') ?? 0;
    _loadPair();
    _refreshDaily();
  }

  void _loadPair() {
    completedUnits = (_p.getStringList('done_$_pairKey') ?? []).toSet();
    mistakes = {};
    for (final e in _p.getStringList('mist_$_pairKey') ?? <String>[]) {
      final parts = e.split(':');
      if (parts.length == 2) mistakes[parts[0]] = int.tryParse(parts[1]) ?? 0;
    }
  }

  /// دل هەر رۆژ دبنە ٥، و Streak ئەگەر رۆژەک هاتە بەرزەکرن دبیتە ٠
  void _refreshDaily() {
    final today = _day(DateTime.now());
    final lastOpen = _p.getString('last_open');
    if (lastOpen != today) {
      hearts = maxHearts;
      todayXp = 0;
      _p.setString('last_open', today);
      _p.setInt('today_xp', 0);
    } else {
      hearts = _p.getInt('hearts') ?? maxHearts;
      todayXp = _p.getInt('today_xp') ?? 0;
    }
    final lastStudy = _p.getString('last_study');
    if (lastStudy != null) {
      final diff = DateTime.parse(today).difference(DateTime.parse(lastStudy)).inDays;
      if (diff > 1) streak = 0;
    }
  }

  String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> setLanguages(AppLanguage native, AppLanguage target) async {
    nativeLang = native;
    targetLang = target;
    onboarded = true;
    await _p.setString('native', native.code);
    await _p.setString('target', target.code);
    await _p.setBool('onboarded', true);
    _loadPair();
    notifyListeners();
  }

  bool isUnlocked(int unitIndex) =>
      unitIndex == 0 || completedUnits.contains(appCurriculum[unitIndex - 1].id);

  Future<void> loseHeart() async {
    if (hearts > 0) hearts--;
    await _p.setInt('hearts', hearts);
    notifyListeners();
  }

  Future<void> recordMistake(String conceptId) async {
    mistakes[conceptId] = (mistakes[conceptId] ?? 0) + 1;
    await _saveMistakes();
  }

  Future<void> clearMistake(String conceptId) async {
    if (mistakes.remove(conceptId) != null) await _saveMistakes();
  }

  Future<void> _saveMistakes() =>
      _p.setStringList('mist_$_pairKey', mistakes.entries.map((e) => '${e.key}:${e.value}').toList());

  List<WordConcept> get weakConcepts =>
      allConcepts.where((c) => (mistakes[c.id] ?? 0) > 0).toList();

  Future<void> setDailyGoal(int goal) async {
    dailyGoal = goal;
    await _p.setInt('daily_goal', goal);
    notifyListeners();
  }

  Future<void> completeLesson({required String? unitId, required int earnedXp, bool perfect = false}) async {
    _refreshDaily(); // ئەگەر ئەپ ژ دوهی ڤەکری مابیت
    xp += earnedXp;
    todayXp += earnedXp;
    lessonsDone++;
    if (perfect) perfectLessons++;
    if (unitId != null) completedUnits.add(unitId);
    final today = _day(DateTime.now());
    final lastStudy = _p.getString('last_study');
    if (lastStudy != today) {
      final yesterday = _day(DateTime.now().subtract(const Duration(days: 1)));
      streak = (lastStudy == yesterday) ? streak + 1 : 1;
      await _p.setString('last_study', today);
    }
    await _p.setInt('xp', xp);
    await _p.setInt('streak', streak);
    if (streak > bestStreak) bestStreak = streak;
    await _p.setInt('best_streak', bestStreak);
    await _p.setInt('today_xp', todayXp);
    await _p.setInt('lessons_done', lessonsDone);
    await _p.setInt('perfect_lessons', perfectLessons);
    await _p.setStringList('done_$_pairKey', completedUnits.toList());
    notifyListeners();
  }

  /// خەلات بۆ تۆمارکرنا دەنگی: +١ دل
  Future<void> addHeart() async {
    if (hearts >= maxHearts) return;
    hearts++;
    await _p.setInt('hearts', hearts);
    notifyListeners();
  }

  Future<void> refillHearts() async {
    hearts = maxHearts;
    await _p.setInt('hearts', hearts);
    notifyListeners();
  }

  /// دەستکەفت (Badges)
  List<Achievement> get achievements {
    final v = VoiceService.instance;
    final myVoice = AppLanguage.values.fold<int>(0, (s, l) => s + v.countMyVoice(l, allConcepts));
    final recorded = AppLanguage.values.fold<int>(0, (s, l) => s + v.countRecordings(l, allConcepts));
    return [
      Achievement('first', '🌱', 'وانەیا ئێکێ', 'Erste Lektion', 'First lesson', lessonsDone >= 1),
      Achievement('ten', '📚', '١٠ وانە', '10 Lektionen', '10 lessons', lessonsDone >= 10),
      Achievement('perfect', '💎', 'وانەیەکا بێ خەلەتی', 'Fehlerfrei', 'Flawless lesson', perfectLessons >= 1),
      Achievement('streak3', '🔥', '٣ رۆژ ل دویف ئێک', '3-Tage-Serie', '3-day streak', bestStreak >= 3),
      Achievement('streak7', '🏔️', 'حەفتیەکا تەمام', '7-Tage-Serie', '7-day streak', bestStreak >= 7),
      Achievement('xp500', '⚡', '٥٠٠ XP', '500 XP', '500 XP', xp >= 500),
      Achievement('half', '🗺️', 'نیڤا رێکێ', 'Halbzeit', 'Halfway there',
          completedUnits.length * 2 >= appCurriculum.length),
      Achievement('all', '👑', 'هەمی قۆناغ', 'Alle Einheiten', 'All units', completedUnits.length >= appCurriculum.length),
      Achievement('voice10', '🎤', '١٠ تۆمار ب دەنگێ خۆ', '10 Aufnahmen', '10 recordings', recorded >= 10),
      Achievement('clone', '🧬', 'دەنگێ من کلۆن بوو', 'Stimme geklont', 'Voice cloned', myVoice > recorded),
    ];
  }

  Future<void> resetAll() async {
    await _p.clear();
    await init();
    notifyListeners();
  }
}
