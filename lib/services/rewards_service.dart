import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../ui.dart' show tr;

/// 🪙 خەلات: دینار، بووست (XP ×٢/×٣)، و پاراستنا Streak (قەشا)
/// - ١٠٠ دینار دیاریا دەستپێکێ
/// - دەستکەفت ➔ ٥ / ١٠ / ١٥ دینار (یان بووست/قەشا) — بۆ هەر کەسەکی یا جودایە
/// - دووکان: ×٢ بۆ ٥ خولەکان = ٣٥ · ×٢ بۆ ١٠ خولەکان = ٧٠ · قەشا = ٥٠
enum RewardKind { dinar, boost, freeze }

class Reward {
  final RewardKind kind;
  final int amount; // دینار؛ یان ×٢/×٣ بۆ بووستی
  final int minutes; // بۆ بووستی
  const Reward.dinar(this.amount)
      : kind = RewardKind.dinar,
        minutes = 0;
  const Reward.boost(this.amount, this.minutes) : kind = RewardKind.boost;
  const Reward.freeze()
      : kind = RewardKind.freeze,
        amount = 1,
        minutes = 0;

  String label(AppLanguage n) => switch (kind) {
        RewardKind.dinar => amount >= 0
            ? tr(n, '+$amount دینار', '+$amount Dinar', '+$amount dinars')
            : tr(n, '$amount دینار', '$amount Dinar', '$amount dinars'),
        RewardKind.boost => tr(n, 'XP ×$amount بۆ $minutes خولەکان', 'XP ×$amount für $minutes Min.', 'XP ×$amount for $minutes min'),
        RewardKind.freeze => tr(n, '🧊 پاراستنا Streak', '🧊 Serienschutz', '🧊 Streak freeze'),
      };
}

/// رووداوەک بۆ نیشاندانێ (دیالۆگ + فڕینا دیناران / ئەنیمەیشن)
enum FxKind { reward, freezeBought, streakSaved, streakLost }

class RewardEvent {
  final FxKind fx;
  final String emoji, ku, de, en;
  final List<Reward> rewards;
  RewardEvent(this.fx, this.emoji, this.ku, this.de, this.en, [this.rewards = const []]);
  String title(AppLanguage n) => tr(n, ku, de, en);
}

class RewardsService extends ChangeNotifier {
  RewardsService._();
  static final RewardsService instance = RewardsService._();

  static const welcomeGift = 100;
  static const priceBoost5 = 35, priceBoost10 = 70, priceFreeze = 50;
  static const maxFreezes = 3;
  static const xpGoals = [250, 400, 500, 750];

  late SharedPreferences _p;
  bool _ready = false;
  int dinar = 0;
  int freezes = 0;
  int xpGoal = 0; // 0 = نینە
  int _boostUntil = 0, _boostMult = 1;
  final List<RewardEvent> pending = [];

  /// تۆمارا دویماهیێ (بۆ دووکانێ)
  List<String> log = [];

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _ready = true;
    dinar = _p.getInt('dinar') ?? 0;
    freezes = _p.getInt('freezes') ?? 0;
    xpGoal = _p.getInt('xp_goal') ?? 0;
    _boostUntil = _p.getInt('boost_until') ?? 0;
    _boostMult = _p.getInt('boost_mult') ?? 1;
    log = _p.getStringList('dinar_log') ?? [];
    if (!(_p.getBool('dinar_init') ?? false)) {
      await _p.setBool('dinar_init', true);
      await _addDinar(welcomeGift, '🎁 دیاریا دەستپێکێ');
      pending.add(RewardEvent(FxKind.reward, '🎁', 'بخێر بێی! ئەڤە دیاریا تەیە', 'Willkommen! Dein Geschenk', 'Welcome! Your gift',
          const [Reward.dinar(welcomeGift)]));
    }
  }

  /// پشتی هاتنا پێشکەفتنێ ژ سێرڤەری (مۆبایلەکا دی)
  Future<void> reload() async {
    if (!_ready) return;
    dinar = _p.getInt('dinar') ?? dinar;
    freezes = _p.getInt('freezes') ?? freezes;
    xpGoal = _p.getInt('xp_goal') ?? xpGoal;
    _boostUntil = _p.getInt('boost_until') ?? _boostUntil;
    _boostMult = _p.getInt('boost_mult') ?? _boostMult;
    notifyListeners();
  }

  // ───────── ⚡ بووست ─────────
  bool get boostActive => DateTime.now().millisecondsSinceEpoch < _boostUntil;
  int get xpMultiplier => boostActive ? _boostMult : 1;
  Duration get boostLeft =>
      boostActive ? Duration(milliseconds: _boostUntil - DateTime.now().millisecondsSinceEpoch) : Duration.zero;

  Future<void> _startBoost(int mult, int minutes) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // ئەگەر بووستەک هەبیت: دەم زێدە دبیت و مەزنترین ژمارە دمینیت
    final base = boostActive ? _boostUntil : now;
    _boostUntil = base + minutes * 60000;
    _boostMult = boostActive && _boostMult > mult ? _boostMult : mult;
    await _p.setInt('boost_until', _boostUntil);
    await _p.setInt('boost_mult', _boostMult);
    notifyListeners();
  }

  // ───────── 🪙 دینار ─────────
  Future<void> _addDinar(int n, String why) async {
    dinar = (dinar + n).clamp(0, 999999);
    await _p.setInt('dinar', dinar);
    final d = DateTime.now();
    log = ['${d.month}/${d.day} ${n >= 0 ? '+' : ''}$n · $why', ...log].take(30).toList();
    await _p.setStringList('dinar_log', log);
    notifyListeners();
  }

  Future<void> grant(List<Reward> rewards, String why) async {
    for (final r in rewards) {
      switch (r.kind) {
        case RewardKind.dinar:
          await _addDinar(r.amount, why);
        case RewardKind.boost:
          await _startBoost(r.amount, r.minutes);
        case RewardKind.freeze:
          freezes = (freezes + 1).clamp(0, maxFreezes);
          await _p.setInt('freezes', freezes);
          notifyListeners();
      }
    }
  }

  /// null = سەرکەفت؛ یان ئەگەرێ نەشیانێ
  Future<String?> buyBoost(int minutes, AppLanguage n) async {
    final price = minutes >= 10 ? priceBoost10 : priceBoost5;
    if (dinar < price) return tr(n, 'دینارێن تە بەس نینن', 'Nicht genug Dinar', 'Not enough dinars');
    await _addDinar(-price, '⚡ ×2 $minutes min');
    await _startBoost(2, minutes);
    return null;
  }

  Future<String?> buyFreeze(AppLanguage n) async {
    if (freezes >= maxFreezes) return tr(n, 'تە $maxFreezes قەشا هەنە (پتر نابیت)', 'Maximal $maxFreezes', 'Max $maxFreezes');
    if (dinar < priceFreeze) return tr(n, 'دینارێن تە بەس نینن', 'Nicht genug Dinar', 'Not enough dinars');
    await _addDinar(-priceFreeze, '🧊 freeze');
    freezes++;
    await _p.setInt('freezes', freezes);
    pending.add(RewardEvent(FxKind.freezeBought, '🧊', 'ئاگرێ تە هاتە پاراستن! ئەگەر رۆژەکێ نەخوینی، Streak نائێتە بڕین',
        'Deine Serie ist geschützt!', 'Your streak is protected!'));
    notifyListeners();
    return null;
  }

  /// ب کار ئینانا قەشایان بۆ رۆژێن نەخواندی (ژ ProgressService)
  bool useFreezes(int days) {
    if (days <= 0 || freezes < days) return false;
    freezes -= days;
    _p.setInt('freezes', freezes);
    pending.add(RewardEvent(FxKind.streakSaved, '🧊', 'قەشا شکەست — Streak ـا تە هاتە پاراستن! 🔥', 'Serie gerettet! 🔥',
        'Streak saved! 🔥'));
    notifyListeners();
    return true;
  }

  void streakLost(int old) {
    if (old < 2) return;
    pending.add(RewardEvent(FxKind.streakLost, '💨', 'ئاگرێ $old رۆژان ڤەمری… ئەڤرۆ ژ نوو هەلکە!', 'Serie verloren… starte heute neu!',
        'Streak lost… light it again today!'));
    notifyListeners();
  }

  Future<void> setXpGoal(int g) async {
    xpGoal = g;
    await _p.setInt('xp_goal', g);
    notifyListeners();
  }

  // ───────── 🏅 دەستکەفت (هەر کەسەک خەلاتەکا جودا) ─────────
  String get _today {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  int get _seed {
    var s = _p.getInt('rw_seed');
    if (s == null) {
      s = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
      _p.setInt('rw_seed', s);
    }
    return s;
  }

  /// هەلبژارتنەکا «هەڕەمەکی» بەلێ نەگۆڕ بۆ ڤی کەسی و ڤێ رۆژێ
  T _pick<T>(String id, List<T> opts) {
    var h = _seed ^ 0x9e3779b9;
    for (final c in '$id|$_today'.codeUnits) {
      h = ((h ^ c) * 16777619) & 0x7fffffff;
    }
    return opts[h % opts.length];
  }

  bool _claimed(String key) => (_p.getStringList('rw_claimed') ?? const []).contains(key);
  Future<void> _claim(String key) async {
    final l = (_p.getStringList('rw_claimed') ?? <String>[]).where((k) => !k.contains('|') || k.endsWith('|$_today')).toList();
    l.add(key);
    await _p.setStringList('rw_claimed', l);
  }

  Future<void> _achieve(String id, String emoji, String ku, String de, String en, List<Reward> opts,
      {bool daily = true}) async {
    final key = daily ? '$id|$_today' : id;
    if (_claimed(key)) return;
    await _claim(key);
    final r = _pick(id, opts);
    await grant([r], '$emoji $ku');
    pending.add(RewardEvent(FxKind.reward, emoji, ku, de, en, [r]));
    notifyListeners();
  }

  // ───────── 🔔 رووداو ژ ProgressService / وانەیان ─────────
  Future<void> onCombo(int combo) async {
    if (combo == 10) {
      await _achieve('combo10', '⚡', '١٠ بەرسڤێن دروست ل دویف ئێک!', '10 richtige Antworten am Stück!', '10 correct in a row!',
          const [Reward.dinar(5), Reward.dinar(10)]);
    } else if (combo == 15) {
      await _achieve('combo15', '🔥', '١٥ بەرسڤێن دروست ل دویف ئێک!', '15 richtige Antworten am Stück!', '15 correct in a row!',
          const [Reward.dinar(10), Reward.dinar(15), Reward.boost(2, 5)]);
    }
  }

  Future<void> onLesson(int percent) async {
    final day = _today;
    final lastDay = _p.getString('rw_lday');
    var today = lastDay == day ? (_p.getInt('rw_lcount') ?? 0) : 0;
    today++;
    await _p.setString('rw_lday', day);
    await _p.setInt('rw_lcount', today);
    final pcts = [...(_p.getStringList('rw_pcts') ?? <String>[]).map(int.parse), percent];
    while (pcts.length > 3) {
      pcts.removeAt(0);
    }
    await _p.setStringList('rw_pcts', pcts.map((e) => '$e').toList());
    final perfects = lastDay == day ? (_p.getInt('rw_perfect') ?? 0) + (percent >= 100 ? 1 : 0) : (percent >= 100 ? 1 : 0);
    await _p.setInt('rw_perfect', perfects);

    if (today == 3) {
      await _achieve('lessons3', '📚', '٣ وانە ئەڤرۆ!', '3 Lektionen heute!', '3 lessons today!',
          const [Reward.dinar(10), Reward.dinar(15), Reward.boost(2, 5)]);
    }
    final last2 = pcts.length >= 2 && pcts.sublist(pcts.length - 2).every((p) => p >= 85);
    if (last2) {
      await _achieve('acc85', '🎯', '٨٥٪+ د وانەیێن ل دویف ئێک دا!', '85 %+ in mehreren Lektionen!', '85%+ in a row!',
          const [Reward.dinar(5), Reward.dinar(10), Reward.dinar(15)]);
    }
    if (perfects == 3) {
      await _achieve('perfect3', '💎', '٣ وانە ب ١٠٠٪!', '3 Lektionen mit 100 %!', '3 lessons at 100%!',
          const [Reward.dinar(15), Reward.boost(3, 5), Reward.freeze()]);
    }
  }

  Future<void> onStudySeconds(int todaySeconds) async {
    if (todaySeconds >= 600) {
      await _achieve('study10', '⏱️', '١٠ خولەک خواندن ئەڤرۆ!', '10 Minuten gelernt!', '10 minutes of study!',
          const [Reward.dinar(5), Reward.dinar(10)]);
    }
  }

  Future<void> onXp({required int todayXp, required int oldTotal, required int newTotal, required List<int> treeXp}) async {
    // 🌳 دار مەزن بوو (ئێک جار بۆ هەر قۆناغەکێ)
    for (var i = 1; i < treeXp.length; i++) {
      if (oldTotal < treeXp[i] && newTotal >= treeXp[i]) {
        await _achieve('tree$i', '🌳', 'دارا تە مەزن بوو! (قۆناغ ${i + 1})', 'Dein Baum ist gewachsen!', 'Your tree grew!',
            const [Reward.dinar(10), Reward.dinar(15)], daily: false);
      }
    }
    // 🎯 ئارمانجا XP یا رۆژانە یا هەلبژارتی
    if (xpGoal > 0 && todayXp >= xpGoal) {
      final rw = switch (xpGoal) {
        >= 750 => const [Reward.dinar(50), Reward.boost(3, 10)],
        >= 500 => const [Reward.dinar(35), Reward.boost(2, 10)],
        >= 400 => const [Reward.dinar(25), Reward.boost(2, 5)],
        _ => const [Reward.dinar(15)],
      };
      final key = 'goal|$_today';
      if (!_claimed(key)) {
        await _claim(key);
        await grant(rw, '🎯 $xpGoal XP');
        pending.add(RewardEvent(FxKind.reward, '🎯', 'ئارمانجا $xpGoal XP یا ئەڤرۆ ب جهـ ئینا!', 'Tagesziel $xpGoal XP geschafft!',
            'Daily goal of $xpGoal XP reached!', rw));
        notifyListeners();
      }
    }
  }

  // ───────── 📬 کارێن ئەدمینی (د نامەیان دا) ─────────
  bool msgDone(int id) => (_p.getStringList('msg_done') ?? const []).contains('$id');
  Future<void> markMsgDone(int id) async {
    final l = _p.getStringList('msg_done') ?? <String>[];
    if (!l.contains('$id')) {
      l.add('$id');
      await _p.setStringList('msg_done', l);
      notifyListeners();
    }
  }

  /// دیاری/برینا دیناران ژ ئەدمینی
  Future<void> applyAdminDinar(int msgId, int n, String title) async {
    if (msgDone(msgId)) return;
    await markMsgDone(msgId);
    await _addDinar(n, '🛡️ ASP');
    pending.add(RewardEvent(FxKind.reward, n >= 0 ? '🎁' : '🪙', title, title, title, [Reward.dinar(n)]));
    notifyListeners();
  }

  Future<void> rewardTask(int msgId, int n, String title) async {
    if (msgDone(msgId)) return;
    await markMsgDone(msgId);
    if (n != 0) {
      await _addDinar(n, '📌 $title');
      pending.add(RewardEvent(FxKind.reward, '🏅', title, title, title, [Reward.dinar(n)]));
    }
    notifyListeners();
  }

  RewardEvent? takeEvent() => pending.isEmpty ? null : pending.removeAt(0);
}

/// 📬 کارێ ئەدمینی د ناڤ نامەیێ دا: «…⟦asp:{json}⟧»
class AdminTask {
  final String type; // dinar | quiz | assign
  final Map<String, dynamic> data;
  AdminTask(this.type, this.data);

  static final _re = RegExp(r'⟦asp:(\{.*\})⟧', dotAll: true);

  static AdminTask? parse(String body) {
    final m = _re.firstMatch(body);
    if (m == null) return null;
    try {
      final j = jsonDecode(m.group(1)!) as Map<String, dynamic>;
      return AdminTask(j['t'] as String, j);
    } catch (_) {
      return null;
    }
  }

  static String strip(String body) => body.replaceAll(_re, '').trim();
  static String encode(Map<String, dynamic> j) => '⟦asp:${jsonEncode(j)}⟧';

  int get reward => (data['r'] as num?)?.toInt() ?? 0;
  int get amount => (data['n'] as num?)?.toInt() ?? 0;
  List<String> get ids => [for (final e in (data['ids'] as List? ?? const [])) '$e'];
  String? get unit => data['unit'] as String?;
}
