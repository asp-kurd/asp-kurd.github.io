import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// پەیوەندی دگەل Supabase (REST + Auth) — بێ پاکێجێن زێدە.
/// - فێرخواز: هەژمارا بێناڤ (anonymous) + پرۆفایل (ناڤ، تەمەن، جه)
/// - ئەدمین: ئیمەیل + پاسوۆرد
class Backend extends ChangeNotifier {
  Backend._();
  static final Backend instance = Backend._();

  late SharedPreferences _p;
  String? _access, _refresh, userId;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);
  bool isAdmin = false;

  Map<String, dynamic>? profile; // ردیفا learners
  List<AppMessage> messages = [];
  Set<int> _readBroadcast = {};

  bool get enabled => AppConfig.backendEnabled;
  bool get registered => profile != null;
  String get name => (profile?['name'] as String?) ?? '';
  int get unread => messages.where((m) => !m.read).length;

  String get _base => AppConfig.supabaseUrl;
  // کلیلێن نوو (sb_publishable_...) تنێ د apikey دا دهێن؛ Authorization تنێ دگەل تۆکنا بکارهێنەری
  Map<String, String> get _h => {
        'apikey': AppConfig.supabaseAnonKey,
        if (_access != null && _access!.isNotEmpty) 'Authorization': 'Bearer $_access',
        'Content-Type': 'application/json',
      };

  /// ئالایێن بچووک (بۆ نموونە: ئایا پرسیارا ئاگەهداریان هاتییە کرن)
  bool flag(String k) => _p.getBool('flag_$k') ?? false;
  Future<void> setFlag(String k) => _p.setBool('flag_$k', true);

  // ───────────────────────── Auth ─────────────────────────

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    if (!enabled) return;
    _access = _p.getString('sb_access');
    _refresh = _p.getString('sb_refresh');
    userId = _p.getString('sb_user');
    isAdmin = _p.getBool('sb_admin') ?? false;
    _expires = DateTime.fromMillisecondsSinceEpoch(_p.getInt('sb_exp') ?? 0);
    _readBroadcast = (_p.getStringList('sb_read') ?? []).map(int.parse).toSet();
    final cached = _p.getString('sb_profile');
    if (cached != null) profile = jsonDecode(cached) as Map<String, dynamic>;
    try {
      await _ensureToken().timeout(const Duration(seconds: 6));
      if (userId != null && !isAdmin) {
        await _loadProfile().timeout(const Duration(seconds: 6));
        unawaited(track(open: true));
        unawaited(loadMessages());
      }
    } catch (_) {
      // بێ ئینتەرنێت: ئەپ ب پرۆفایلا پاشەکەفتکری بەردەوام دبیت
    }
  }

  void _saveSession(Map<String, dynamic> j) {
    _access = j['access_token'] as String?;
    _refresh = j['refresh_token'] as String?;
    final user = j['user'] as Map<String, dynamic>?;
    if (user != null) userId = user['id'] as String?;
    _expires = DateTime.now().add(Duration(seconds: ((j['expires_in'] as num?) ?? 3600).toInt() - 60));
    _p.setString('sb_access', _access ?? '');
    _p.setString('sb_refresh', _refresh ?? '');
    if (userId != null) _p.setString('sb_user', userId!);
    _p.setInt('sb_exp', _expires.millisecondsSinceEpoch);
  }

  Future<void> _ensureToken() async {
    if (_refresh == null || _refresh!.isEmpty) return;
    if (DateTime.now().isBefore(_expires)) return;
    final r = await http.post(Uri.parse('$_base/auth/v1/token?grant_type=refresh_token'),
        headers: {'apikey': AppConfig.supabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refresh}));
    if (r.statusCode == 200) {
      _saveSession(jsonDecode(r.body) as Map<String, dynamic>);
    }
  }

  /// تۆمارکرنا فێرخوازەکێ نوو: ناڤ + تەمەن + جهێ ئاکنجیبوونێ
  Future<String?> register({required String name, required int? age, required String city, String native = 'ku', String target = 'de'}) async {
    if (!enabled) return 'offline';
    try {
      if (userId == null || isAdmin) {
        final r = await http.post(Uri.parse('$_base/auth/v1/signup'),
            headers: {'apikey': AppConfig.supabaseAnonKey, 'Content-Type': 'application/json'}, body: jsonEncode({'data': {}}));
        if (r.statusCode >= 300) return 'auth ${r.statusCode}: ${r.body}';
        isAdmin = false;
        await _p.setBool('sb_admin', false);
        _saveSession(jsonDecode(r.body) as Map<String, dynamic>);
      }
      final row = {
        'id': userId,
        'name': name.trim(),
        'age': age,
        'city': city.trim(),
        'native_lang': native,
        'target_lang': target,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      };
      final r = await http.post(Uri.parse('$_base/rest/v1/learners'),
          headers: {..._h, 'Prefer': 'resolution=merge-duplicates,return=representation'}, body: jsonEncode(row));
      if (r.statusCode >= 300) return 'db ${r.statusCode}: ${r.body}';
      final list = jsonDecode(r.body) as List;
      _setProfile(list.first as Map<String, dynamic>);
      unawaited(track(open: true));
      unawaited(loadMessages());
      return null;
    } catch (e) {
      return '$e';
    }
  }

  void _setProfile(Map<String, dynamic> p) {
    profile = p;
    _p.setString('sb_profile', jsonEncode(p));
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final r = await http.get(Uri.parse('$_base/rest/v1/learners?id=eq.$userId&select=*'), headers: _h);
    if (r.statusCode == 200) {
      final list = jsonDecode(r.body) as List;
      if (list.isNotEmpty) _setProfile(list.first as Map<String, dynamic>);
    }
  }

  // ───────────────────────── چالاکی ─────────────────────────

  Future<void> track({bool open = false, int seconds = 0, int lessons = 0, int xp = 0}) async {
    if (!enabled || userId == null || isAdmin) return;
    try {
      await _ensureToken();
      await http.post(Uri.parse('$_base/rest/v1/rpc/track'),
          headers: _h, body: jsonEncode({'p_seconds': seconds, 'p_lessons': lessons, 'p_xp': xp, 'p_open': open}));
    } catch (_) {}
  }

  Timer? _syncTimer;

  /// نویکرنا ئامارێن فێرخوازی (XP، Streak ...) — ب دواخستن دا داخواز کێم بن
  void syncStats({required int xp, required int streak, required int completedUnits, String? currentUnit, String? lastStudy}) {
    if (!enabled || userId == null || isAdmin || profile == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), () async {
      try {
        await _ensureToken();
        await http.patch(Uri.parse('$_base/rest/v1/learners?id=eq.$userId'),
            headers: _h,
            body: jsonEncode({
              'xp': xp,
              'streak': streak,
              'completed_units': completedUnits,
              if (currentUnit != null) 'current_unit': currentUnit,
              if (lastStudy != null) 'last_study_date': lastStudy,
              'last_seen': DateTime.now().toUtc().toIso8601String(),
            }));
      } catch (_) {}
    });
  }

  Future<void> examResult(String examId, int score, int total) async {
    if (!enabled || userId == null || isAdmin) return;
    try {
      await _ensureToken();
      await http.post(Uri.parse('$_base/rest/v1/exam_results'),
          headers: _h, body: jsonEncode({'learner_id': userId, 'exam_id': examId, 'score': score, 'total': total}));
    } catch (_) {}
  }

  Future<void> savePushSubscription(Map<String, dynamic> sub) async {
    if (!enabled || userId == null) return;
    await _ensureToken();
    await http.patch(Uri.parse('$_base/rest/v1/learners?id=eq.$userId'), headers: _h, body: jsonEncode({'push_sub': sub}));
  }

  // ───────────────────────── نامە ─────────────────────────

  Future<void> loadMessages() async {
    if (!enabled || userId == null) return;
    try {
      await _ensureToken();
      final r = await http.get(
          Uri.parse('$_base/rest/v1/messages?or=(learner_id.eq.$userId,learner_id.is.null)&select=*&order=created_at.desc&limit=50'),
          headers: _h);
      if (r.statusCode == 200) {
        messages = (jsonDecode(r.body) as List)
            .map((m) => AppMessage.fromJson(m as Map<String, dynamic>, _readBroadcast))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markRead(AppMessage m) async {
    if (m.read) return;
    m.read = true;
    notifyListeners();
    if (m.broadcast) {
      _readBroadcast.add(m.id);
      await _p.setStringList('sb_read', _readBroadcast.map((e) => '$e').toList());
    } else {
      try {
        await http.patch(Uri.parse('$_base/rest/v1/messages?id=eq.${m.id}'),
            headers: _h, body: jsonEncode({'read_at': DateTime.now().toUtc().toIso8601String()}));
      } catch (_) {}
    }
  }

  // ───────────────────────── ئەدمین ─────────────────────────

  Future<String?> adminLogin(String email, String password) async {
    if (!enabled) return 'Supabase not configured';
    final r = await http.post(Uri.parse('$_base/auth/v1/token?grant_type=password'),
        headers: {'apikey': AppConfig.supabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}));
    if (r.statusCode != 200) return 'ئیمەیل یان پاسوۆرد خەلەتە (${r.statusCode})';
    // پاشەکەفتکرنا هەژمارا فێرخوازی بەری گوهۆڕینێ
    if (!isAdmin && _refresh != null) {
      await _p.setString('sb_learner_refresh', _refresh!);
      await _p.setString('sb_learner_user', userId ?? '');
    }
    _saveSession(jsonDecode(r.body) as Map<String, dynamic>);
    isAdmin = true;
    await _p.setBool('sb_admin', true);
    notifyListeners();
    return null;
  }

  Future<void> adminLogout() async {
    isAdmin = false;
    await _p.setBool('sb_admin', false);
    _refresh = _p.getString('sb_learner_refresh');
    userId = _p.getString('sb_learner_user');
    if (userId != null && userId!.isEmpty) userId = null;
    _access = null;
    _expires = DateTime.fromMillisecondsSinceEpoch(0);
    await _p.setString('sb_refresh', _refresh ?? '');
    if (userId != null) await _p.setString('sb_user', userId!);
    try {
      await _ensureToken();
    } catch (_) {}
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    await _ensureToken();
    final r = await http.get(Uri.parse('$_base/rest/v1/$path'), headers: _h);
    if (r.statusCode != 200) throw Exception('${r.statusCode}: ${r.body}');
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminLearners() => _getList('learners?select=*&order=last_seen.desc.nullslast');
  Future<List<Map<String, dynamic>>> adminActivity(String id) =>
      _getList('activity?learner_id=eq.$id&select=*&order=day.desc&limit=30');
  Future<List<Map<String, dynamic>>> adminActivityAll(String sinceDay) => _getList('activity?day=gte.$sinceDay&select=*');
  Future<List<Map<String, dynamic>>> adminExams(String id) =>
      _getList('exam_results?learner_id=eq.$id&select=*&order=created_at.desc&limit=30');
  Future<List<Map<String, dynamic>>> adminMessages(String? id) => _getList(
      id == null ? 'messages?learner_id=is.null&select=*&order=created_at.desc&limit=30' : 'messages?learner_id=eq.$id&select=*&order=created_at.desc&limit=30');

  Future<String?> sendMessage({String? learnerId, required String title, required String body}) async {
    await _ensureToken();
    final r = await http.post(Uri.parse('$_base/rest/v1/messages'),
        headers: _h, body: jsonEncode({'learner_id': learnerId, 'title': title, 'body': body, 'kind': 'admin'}));
    return r.statusCode < 300 ? null : '${r.statusCode}: ${r.body}';
  }

  Future<void> deleteMessage(int id) async {
    await _ensureToken();
    await http.delete(Uri.parse('$_base/rest/v1/messages?id=eq.$id'), headers: _h);
  }

  // ───────────────────────── ناڤەرۆک (گوهۆڕین ژ لایێ ئەدمینی) ─────────────────────────

  /// ناڤەرۆکا گوهۆڕی ژ سێرڤەری (یان ژ کاشێ). null = ناڤەرۆکا ئەسلی یا ئەپی.
  Future<String?> contentOverride(String key) async {
    if (!enabled) return null;
    final cached = _p.getString('content_$key');
    try {
      final r = await http
          .get(Uri.parse('$_base/rest/v1/content?key=eq.$key&select=value,updated_at'),
              headers: {'apikey': AppConfig.supabaseAnonKey})
          .timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        if (list.isEmpty) {
          await _p.remove('content_$key');
          return null;
        }
        final v = jsonEncode((list.first as Map<String, dynamic>)['value']);
        await _p.setString('content_$key', v);
        return v;
      }
    } catch (_) {}
    return cached;
  }

  Future<String?> saveContent(String key, Object value) async {
    await _ensureToken();
    final r = await http.post(Uri.parse('$_base/rest/v1/content'),
        headers: {..._h, 'Prefer': 'resolution=merge-duplicates'},
        body: jsonEncode({'key': key, 'value': value, 'updated_at': DateTime.now().toUtc().toIso8601String()}));
    return r.statusCode < 300 ? null : '${r.statusCode}: ${r.body}';
  }

  Future<String?> resetContent(String key) async {
    await _ensureToken();
    final r = await http.delete(Uri.parse('$_base/rest/v1/content?key=eq.$key'), headers: _h);
    return r.statusCode < 300 ? null : '${r.statusCode}: ${r.body}';
  }
}

class AppMessage {
  final int id;
  final String title, body, kind;
  final DateTime created;
  final bool broadcast;
  bool read;

  AppMessage(this.id, this.title, this.body, this.kind, this.created, this.broadcast, this.read);

  factory AppMessage.fromJson(Map<String, dynamic> j, Set<int> readBroadcast) {
    final id = (j['id'] as num).toInt();
    final broadcast = j['learner_id'] == null;
    return AppMessage(
      id,
      (j['title'] as String?) ?? '',
      (j['body'] as String?) ?? '',
      (j['kind'] as String?) ?? 'admin',
      DateTime.tryParse((j['created_at'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
      broadcast,
      broadcast ? readBroadcast.contains(id) : j['read_at'] != null,
    );
  }
}
