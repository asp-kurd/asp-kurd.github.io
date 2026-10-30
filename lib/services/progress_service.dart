import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/curriculum.dart';
import '../models.dart';
import 'backend.dart';
import 'voice_service.dart';

/// پاشەکەفتکرنا پێشکەفتنێ: XP، Streak، دل، پێنگاڤێن تەمامکری، و زمان.
class ProgressService extends ChangeNotifier {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  static const maxHearts = 5;

  /// هەر ٣ خولەکان دلەک ب ئۆتۆماتیکی زێدە دبیت
  static const heartRegen = Duration(minutes: 3);
  Timer? _heartTimer;
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

  // 📊 ئامار: هەر رۆژ ➔ XP و چرکە
  Map<String, int> dayXp = {};
  Map<String, int> daySeconds = {};
  int correctTotal = 0;
  int wrongTotal = 0;

  // 🔁 Spaced Repetition (Leitner): conceptId ➔ (box, dueDay)
  static const srsIntervals = [0, 1, 2, 4, 7, 15, 30]; // رۆژ
  Map<String, (int, int)> srs = {};

  // ⭐ ستێرێن یاریان: 'game|unitId' ➔ 0..3
  Map<String, int> stars = {};

  // ⚙️ ڕێکخستن
  bool gameSounds = true;
  bool funnySounds = true;
  bool paleLetters = true;

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
    correctTotal = _p.getInt('correct_total') ?? 0;
    wrongTotal = _p.getInt('wrong_total') ?? 0;
    dayXp = _intMap(_p.getString('day_xp'));
    daySeconds = _intMap(_p.getString('day_sec'));
    gameSounds = _p.getBool('set_sounds') ?? true;
    funnySounds = _p.getBool('set_funny') ?? true;
    paleLetters = _p.getBool('set_pale') ?? true;
    _loadPair();
    _refreshDaily();
  }

  static Map<String, int> _intMap(String? raw) {
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  void _loadPair() {
    completedUnits = (_p.getStringList('done_$_pairKey') ?? []).toSet();
    srs = {};
    for (final e in _p.getStringList('srs_$_pairKey') ?? <String>[]) {
      final parts = e.split(':');
      if (parts.length == 3) srs[parts[0]] = (int.tryParse(parts[1]) ?? 0, int.tryParse(parts[2]) ?? 0);
    }
    stars = _intMap(_p.getString('stars_$_pairKey'));
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
    _regenHearts();
    if (hearts < maxHearts) _startHeartTimer();
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
    _regenHearts();
    if (hearts >= maxHearts) {
      // دەمژمێر ژ دەمێ ژ دەستدانا ئێکەمین دلی دەستپێدکەت
      await _p.setInt('heart_clock', DateTime.now().millisecondsSinceEpoch);
    }
    if (hearts > 0) hearts--;
    await _p.setInt('hearts', hearts);
    _startHeartTimer();
    notifyListeners();
  }

  /// دلێن بەرزەبووی ل دویف دەمی ڤەدگەڕینە
  bool _regenHearts() {
    if (hearts >= maxHearts) return false;
    final clock = _p.getInt('heart_clock') ?? DateTime.now().millisecondsSinceEpoch;
    final elapsed = DateTime.now().millisecondsSinceEpoch - clock;
    final gained = elapsed ~/ heartRegen.inMilliseconds;
    if (gained <= 0) return false;
    hearts = (hearts + gained).clamp(0, maxHearts);
    _p.setInt('hearts', hearts);
    _p.setInt('heart_clock', clock + gained * heartRegen.inMilliseconds);
    return true;
  }

  /// دەمێ مای هەتا دلێ بهێت (null ئەگەر هەمی دل تژی بن)
  Duration? get nextHeartIn {
    if (hearts >= maxHearts) return null;
    final clock = _p.getInt('heart_clock') ?? DateTime.now().millisecondsSinceEpoch;
    final left = clock + heartRegen.inMilliseconds - DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  void _startHeartTimer() {
    if (_heartTimer != null) return;
    _heartTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final changed = _regenHearts();
      if (hearts >= maxHearts) {
        _heartTimer?.cancel();
        _heartTimer = null;
      }
      // هەر چرکەیەکێ بۆ دەمژمێرا نیشاندانێ
      if (changed || hearts < maxHearts) notifyListeners();
    });
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
    lessonsDone++;
    Backend.instance.track(lessons: 1);
    if (perfect) perfectLessons++;
    if (unitId != null) completedUnits.add(unitId);
    await earn(earnedXp);
  }

  // ───────── 📝 ئەزموون ─────────
  /// باشترین ئەنجام بۆ ئەزموونەکێ (٠–١٠٠)، یان null
  int? examBest(String id) => _p.getInt('exam_${_pairKey}_$id');

  Future<void> saveExam(String id, int percent) async {
    final best = examBest(id) ?? -1;
    if (percent > best) await _p.setInt('exam_${_pairKey}_$id', percent);
    notifyListeners();
  }

  /// پشتی تاقیکرنا ئاستی: قۆناغێن بەری وێ وەکی تەمامکری نیشان بدە
  Future<void> markUnitsDone(Iterable<String> ids) async {
    completedUnits.addAll(ids);
    await _p.setStringList('done_$_pairKey', completedUnits.toList());
    notifyListeners();
  }

  bool get placementDone => _p.getBool('placement_$_pairKey') ?? false;
  Future<void> setPlacementDone() async {
    await _p.setBool('placement_$_pairKey', true);
    notifyListeners();
  }

  /// کارتا رێزمانێ هاتییە دیتن؟
  bool grammarSeen(String unitId) => _p.getBool('gseen_$unitId') ?? false;
  Future<void> setGrammarSeen(String unitId) => _p.setBool('gseen_$unitId', true);

  /// XP بۆ هەر چالاکیەکێ (وانە، یاری، دووبارەکرن) — Streak و ئامارێن رۆژانە ژی نوی دکەت
  Future<void> earn(int earnedXp) async {
    _refreshDaily(); // ئەگەر ئەپ ژ دوهی ڤەکری مابیت
    xp += earnedXp;
    todayXp += earnedXp;
    final today = _day(DateTime.now());
    dayXp[today] = (dayXp[today] ?? 0) + earnedXp;
    await _p.setString('day_xp', jsonEncode(dayXp));
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
    Backend.instance.track(xp: earnedXp);
    Backend.instance.syncStats(
      xp: xp,
      streak: streak,
      completedUnits: completedUnits.length,
      currentUnit: _currentUnit(),
      lastStudy: today,
    );
    notifyListeners();
  }

  String? _currentUnit() {
    for (var i = 0; i < appCurriculum.length; i++) {
      if (!completedUnits.contains(appCurriculum[i].id)) return appCurriculum[i].titleKu;
    }
    return null;
  }

  /// ئێڤار و Streak د مەترسیێ دایە (ئەڤرۆ هێشتا نەخواندییە)
  bool get streakAtRisk {
    final last = _p.getString('last_study');
    return streak > 0 && last != _day(DateTime.now()) && DateTime.now().hour >= 17;
  }

  // ───────── 📊 ئامار ─────────
  int get _todayNum {
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(2024)).inDays;
  }

  /// هەر بەرسڤەک: ئامار + Spaced Repetition
  Future<void> recordAnswer(String conceptId, bool ok) async {
    if (ok) {
      correctTotal++;
    } else {
      wrongTotal++;
    }
    final (box, _) = srs[conceptId] ?? (0, 0);
    final last = srsIntervals.length - 1;
    final nb = ok ? (box + 1 > last ? last : box + 1) : 0;
    srs[conceptId] = (nb, _todayNum + srsIntervals[nb]);
    await _p.setInt('correct_total', correctTotal);
    await _p.setInt('wrong_total', wrongTotal);
    await _p.setStringList('srs_$_pairKey', srs.entries.map((e) => '${e.key}:${e.value.$1}:${e.value.$2}').toList());
  }

  /// ئەو پەیڤێن دەمێ دووبارەکرنا وان هاتی (کەڤنترین ل پێشیێ)
  List<WordConcept> get dueConcepts {
    final today = _todayNum;
    final due = allConcepts.where((c) {
      final s = srs[c.id];
      return s != null && s.$2 <= today;
    }).toList()
      ..sort((a, b) => srs[a.id]!.$2.compareTo(srs[b.id]!.$2));
    return due;
  }

  /// پەیڤێن فێربووی = ٢ جاران ل دویف ئێک دروست
  int get wordsLearned => srs.values.where((v) => v.$1 >= 2).length;

  int get accuracy {
    final t = correctTotal + wrongTotal;
    return t == 0 ? 0 : (correctTotal * 100 / t).round();
  }

  Future<void> addStudyTime(Duration d) async {
    final sec = d.inSeconds > 3600 ? 3600 : d.inSeconds;
    if (sec < 3) return;
    final today = _day(DateTime.now());
    daySeconds[today] = (daySeconds[today] ?? 0) + sec;
    await _p.setString('day_sec', jsonEncode(daySeconds));
    Backend.instance.track(seconds: sec);
    notifyListeners();
  }

  int get totalSeconds => daySeconds.values.fold(0, (a, b) => a + b);
  int get daysPracticed => {...dayXp.keys.where((k) => (dayXp[k] ?? 0) > 0), ...daySeconds.keys}.length;

  int xpOn(DateTime d) => dayXp[_day(d)] ?? 0;
  int secondsOn(DateTime d) => daySeconds[_day(d)] ?? 0;

  // ───────── ⭐ ستێر ─────────
  int starsFor(String game, String unitId) => stars['$game|$unitId'] ?? 0;
  int totalStars(String game) => stars.entries.where((e) => e.key.startsWith('$game|')).fold(0, (a, e) => a + e.value);

  Future<void> setStars(String game, String unitId, int value) async {
    final k = '$game|$unitId';
    if ((stars[k] ?? 0) >= value) return;
    stars[k] = value;
    await _p.setString('stars_$_pairKey', jsonEncode(stars));
    notifyListeners();
  }

  // ───────── ⚙️ ڕێکخستن ─────────
  Future<void> setGameSounds(bool v) async {
    gameSounds = v;
    await _p.setBool('set_sounds', v);
    notifyListeners();
  }

  Future<void> setFunnySounds(bool v) async {
    funnySounds = v;
    await _p.setBool('set_funny', v);
    notifyListeners();
  }

  Future<void> setPaleLetters(bool v) async {
    paleLetters = v;
    await _p.setBool('set_pale', v);
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
