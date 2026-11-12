import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart' show openUrl, oauthOverlay;

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

  /// 'm' = نێر · 'f' = مێ · null = نەهاتییە دیارکرن (هەژمارێن کەڤن)
  String? get gender => (profile?['gender'] as String?) ?? (enabled ? _p.getString('gender') : null);
  int get unread => messages.where((m) => !m.read).length;

  /// 💬 گفتوگۆیا راستەوخۆ دگەل ئەدمینی
  List<AppMessage> chat = [];
  int get chatUnread => chat.where((m) => !m.fromLearner && !m.read).length;

  /// 📧 ئیمەیلا هەژمارێ (بۆ هەژمارێن ب ناڤ تنێ: null)
  String? get email {
    final e = (profile?['email'] as String?) ?? (enabled ? _p.getString('sb_email') : null);
    return (e == null || e.isEmpty) ? null : e;
  }

  bool get hasEmail => email != null;

  // ───────── 🔐 Google / Facebook ─────────
  /// 'google' / 'facebook' (ئەگەر حساب ب وان ڤە گرێدایی بیت)
  String? get provider => enabled ? _p.getString('sb_provider') : null;

  /// خەلەتیا داوی یا Google/Facebook (بۆ نیشاندانێ)
  String? oauthError;

  /// پشتی Google/Facebook: حسابەکا دی هاتە ڤەکرن (ئانکو پێشکەفتن ژ سێرڤەری بینە)
  bool switchedAccount = false;

  /// ناڤێ ژ Google/Facebook (بۆ پڕکرنا فۆرمێ)
  String? get oauthName => _p.getString('sb_oname');

  bool get oauthPending => _p.getString('oauth_pending') != null;

  // ───────── 👤 هەژمارا ب ناڤ تنێ: ٣ رۆژ ─────────
  static const guestDays = 3;
  bool get isGuest => enabled && registered && !isAdmin && !hasEmail;
  int get guestDaysLeft {
    var since = _p.getInt('sb_guest_since');
    if (since == null) {
      since = DateTime.now().millisecondsSinceEpoch;
      _p.setInt('sb_guest_since', since);
    }
    final days = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(since)).inHours ~/ 24;
    return (guestDays - days).clamp(0, guestDays);
  }

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
  Future<void> setFlagNotify(String k) async {
    await setFlag(k);
    notifyListeners();
  }

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
    // 🔐 زڤڕین ژ Google/Facebook (index.html تۆکن پاشەکەفت کرینە)
    final oh = _p.getString('oauth_hash');
    if (oh != null && !oauthOverlay) {
      await _p.remove('oauth_hash');
      await _consumeOAuth(oh);
    }
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

  /// #access_token=…&refresh_token=… ➔ هەژمار
  Future<void> _consumeOAuth(String frag) async {
    await _p.remove('oauth_pending');
    final q = Uri.splitQueryString(frag);
    if (q['access_token'] == null) {
      final d = q['error_description'] ?? q['error'] ?? 'error';
      oauthError = d.contains('already') || d.contains('identity_already_exists')
          ? 'ئەڤ هەژمارا Google/Facebook ب حسابەکێ دی یێ ASP ڤە گرێدایە. «چوونا ژوور» ب کار بینە یان یەکا دی هەلبژێرە.'
          : 'چوونا ژوور سەرنەکەفت: $d';
      return;
    }
    final oldId = userId;
    Map<String, dynamic> claims = {};
    try {
      final parts = q['access_token']!.split('.');
      claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
    } catch (_) {}
    userId = claims['sub'] as String? ?? userId;
    isAdmin = false;
    await _p.setBool('sb_admin', false);
    _saveSession({
      'access_token': q['access_token'],
      'refresh_token': q['refresh_token'],
      'expires_in': int.tryParse(q['expires_in'] ?? '') ?? 3600,
    });
    switchedAccount = oldId != null && oldId != userId;
    if (switchedAccount || oldId == null) {
      profile = null;
      await _p.remove('sb_profile');
    }
    // ئیمەیل و ناڤ ژ Google/Facebook
    String? em, prov, nm;
    try {
      final r = await http.get(Uri.parse('$_base/auth/v1/user'), headers: _h).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final u = jsonDecode(r.body) as Map<String, dynamic>;
        for (final idn in (u['identities'] as List? ?? const [])) {
          final m = idn as Map<String, dynamic>;
          final pv = m['provider'] as String?;
          if (pv == 'google' || pv == 'facebook') {
            prov = pv;
            final d = (m['identity_data'] as Map?) ?? const {};
            em ??= d['email'] as String?;
            nm ??= (d['full_name'] ?? d['name']) as String?;
          }
        }
        em ??= u['email'] as String?;
      }
    } catch (_) {}
    em ??= claims['email'] as String?;
    if (em != null && em.isNotEmpty && !em.endsWith('@guest.asp-poya.com')) await _p.setString('sb_email', em.toLowerCase());
    if (prov != null) await _p.setString('sb_provider', prov);
    if (nm != null) await _p.setString('sb_oname', nm);
    await _p.remove('sb_gem');
    await _p.remove('sb_gpw');
    await _p.remove('sb_guest_since');
  }

  /// 🔐 دەستپێکرنا Google/Facebook. هەژمارا ب ناڤ تنێ ➔ گرێدان (پێشکەفتن دمینیت)
  Future<String?> startOAuth(String provider, {bool signInOnly = false}) async {
    if (!enabled) return 'offline';
    oauthError = null;
    final back = Uri.encodeComponent('${Uri.base.origin}${Uri.base.path}');
    try {
      String url;
      final link = !signInOnly && userId != null && !isAdmin && registered && !hasEmail;
      if (link) {
        await _ensureToken();
        final r = await http.get(
            Uri.parse('$_base/auth/v1/user/identities/authorize?provider=$provider&redirect_to=$back&skip_http_redirect=true'),
            headers: _h);
        if (r.statusCode >= 300) return authError(r.body);
        url = (jsonDecode(r.body) as Map<String, dynamic>)['url'] as String;
      } else {
        url = '$_base/auth/v1/authorize?provider=$provider&redirect_to=$back';
      }
      await _p.setString('oauth_pending', provider);
      openUrl(url);
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// iPhone: ئەگەر Google ل پەنجەرەکا جودا ڤەبوو، تۆکن د جهێ هەڤپشک دا دهێت ➔ ل ڤێرێ بخوینە
  Future<bool> checkOAuthReturn() async {
    if (!enabled) return false;
    await _p.reload();
    final oh = _p.getString('oauth_hash');
    if (oh != null) {
      await _p.remove('oauth_hash');
      await _consumeOAuth(oh);
      if (oauthError == null) await _loadProfile().catchError((_) {});
      notifyListeners();
      return true;
    }
    final u = _p.getString('sb_user');
    if (u != null && u != userId) {
      await init();
      notifyListeners();
      return true;
    }
    return false;
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

  /// خەلەتیێن Supabase ب کوردی
  static String authError(String body) {
    if (body.contains('already') || body.contains('email_exists') || body.contains('user_already_exists')) {
      return 'ئەڤ ئیمەیلە بەری نوکە هاتییە تۆمارکرن. «چوونا ژوور» ب کار بینە.';
    }
    if (body.contains('weak_password') || body.contains('at least 6')) return 'پاسۆرد دڤێت ب کێمی ٦ پیت بیت.';
    if (body.contains('email_address_invalid') || body.contains('invalid format')) return 'ئیمەیل نە دروستە.';
    if (body.contains('invalid_credentials')) return 'ئیمەیل یان پاسۆرد خەلەتە.';
    if (body.contains('email_not_confirmed') || body.contains('confirm')) return 'پشتراستکرنا ئیمەیلێ ل سێرڤەری هێشتا ڤەکرییە (ئەدمین دڤێت بگریت).';
    if (body.contains('over_email_send_rate_limit') || body.contains('rate limit')) return 'گەلەک هەولدان — کەمەکێ دی دیسا تاقی بکە.';
    return body.length > 160 ? body.substring(0, 160) : body;
  }

  /// 📧 ئیمەیل + پاسۆرد: هەژمارا نوو، یان گرێدانا هەژمارا ب ناڤ تنێ (بێ کو پێشکەفتن ژ دەست بچیت)
  Future<String?> _emailAuth(String email, String password) async {
    final body = jsonEncode({'email': email.trim().toLowerCase(), 'password': password});
    http.Response r;
    if (userId != null && !isAdmin && _refresh != null && _refresh!.isNotEmpty) {
      await _ensureToken();
      r = await http.put(Uri.parse('$_base/auth/v1/user'), headers: _h, body: body);
      if (r.statusCode >= 300) return authError(r.body);
      final u = jsonDecode(r.body) as Map<String, dynamic>;
      if ((u['email'] as String?)?.toLowerCase() != email.trim().toLowerCase()) return authError('confirm');
    } else {
      r = await http.post(Uri.parse('$_base/auth/v1/signup'),
          headers: {'apikey': AppConfig.supabaseAnonKey, 'Content-Type': 'application/json'}, body: body);
      if (r.statusCode >= 300) return authError(r.body);
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['access_token'] == null) return authError('confirm');
      isAdmin = false;
      await _p.setBool('sb_admin', false);
      _saveSession(j);
    }
    await _p.setString('sb_email', email.trim().toLowerCase());
    return null;
  }

  /// گرێدانا ئیمەیلێ ب هەژمارا نوکە (ژ پرۆفایلێ)
  Future<String?> linkEmail(String email, String password) async {
    if (!enabled) return 'offline';
    // هەژمارێن ئیمەیلا ڤەشارتی هەی (ژ ئەپا سەر شاشێ): هەژمارەکا نوو + گوهاستنا پرۆفایل و پێشکەفتنێ
    if (_p.getString('sb_gem') != null) return _migrateGuestToEmail(email, password);
    try {
      final err = await _emailAuth(email, password);
      if (err != null) return err;
      await _patchLearner({'email': email.trim().toLowerCase()});
      notifyListeners();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> _migrateGuestToEmail(String email, String password) async {
    try {
      await _ensureToken();
      final oldTok = _access, oldId = userId, old = profile ?? {};
      final r = await http.post(Uri.parse('$_base/auth/v1/signup'),
          headers: {'apikey': AppConfig.supabaseAnonKey, 'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim().toLowerCase(), 'password': password}));
      if (r.statusCode >= 300) return authError(r.body);
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['access_token'] == null) return authError('confirm');
      _saveSession(j);
      await _p.setString('sb_email', email.trim().toLowerCase());
      await _p.remove('sb_gem');
      await _p.remove('sb_gpw');
      const keep = ['name', 'age', 'city', 'native_lang', 'target_lang', 'gender', 'xp', 'streak', 'completed_units', 'current_unit', 'last_study_date'];
      final row = <String, dynamic>{
        for (final k in keep)
          if (old[k] != null) k: old[k],
        'id': userId,
        'email': email.trim().toLowerCase(),
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      };
      final r2 = await http.post(Uri.parse('$_base/rest/v1/learners'),
          headers: {..._h, 'Prefer': 'resolution=merge-duplicates,return=representation'}, body: jsonEncode(row));
      if (r2.statusCode < 300) {
        final list = jsonDecode(r2.body) as List;
        if (list.isNotEmpty) _setProfile(list.first as Map<String, dynamic>);
      }
      // ردیفا کەڤن ژێببە (دا ئەدمین دوو جاران نەبینیت)
      if (oldTok != null && oldId != null && oldId != userId) {
        unawaited(http.delete(Uri.parse('$_base/rest/v1/learners?id=eq.$oldId'),
            headers: {'apikey': AppConfig.supabaseAnonKey, 'Authorization': 'Bearer $oldTok'}));
      }
      notifyListeners();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<void> _patchLearner(Map<String, dynamic> m) async {
    try {
      await _ensureToken();
      final r = await http.patch(Uri.parse('$_base/rest/v1/learners?id=eq.$userId'),
          headers: {..._h, 'Prefer': 'return=representation'}, body: jsonEncode(m));
      if (r.statusCode < 300) {
        final list = jsonDecode(r.body) as List;
        if (list.isNotEmpty) _setProfile(list.first as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  // ───────── 📲 دەربازکرنا هەژمارێ بۆ ئەپا سەر شاشێ (iPhone) ─────────

  /// کۆدەک بۆ لینکێ ئەپا سەر شاشێ. هەژمارێن ب ناڤ تنێ ئیمەیل/پاسۆردەکێ ڤەشارتی وەردگرن (ب خۆ).
  Future<String?> handoffCode() async {
    if (!enabled || !registered || isAdmin || userId == null) return null;
    String enc(String v) => base64Url.encode(utf8.encode(v)).replaceAll('=', '');
    if (provider != null) return 'o${enc(provider!)}';
    if (hasEmail) return 'e${enc(email!)}';
    var em = _p.getString('sb_gem'), pw = _p.getString('sb_gpw');
    if (em == null || pw == null) {
      try {
        await _ensureToken();
        final rnd = Random.secure();
        const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        final newPw = List.generate(22, (_) => chars[rnd.nextInt(chars.length)]).join();
        final newEm = 'g${userId!.replaceAll('-', '').substring(0, 16)}@guest.asp-poya.com';
        final r = await http.put(Uri.parse('$_base/auth/v1/user'), headers: _h, body: jsonEncode({'email': newEm, 'password': newPw}));
        if (r.statusCode >= 300) return null;
        final u = jsonDecode(r.body) as Map<String, dynamic>;
        if ((u['email'] as String?)?.toLowerCase() != newEm) return null;
        em = newEm;
        pw = newPw;
        await _p.setString('sb_gem', em);
        await _p.setString('sb_gpw', pw);
      } catch (_) {
        return null;
      }
    }
    return 'g${enc('$em\n$pw')}';
  }

  /// ئەپا سەر شاشێ: ب کۆدێ لینکی بچە ناڤ هەمان هەژمار. ئەگەر هەژمار ب ئیمەیلا تە بیت: 'email:<ئیمەیل>' (پاسۆرد پێدڤییە).
  Future<String?> handoffLogin(String code) async {
    if (!enabled || code.length < 2) return 'bad';
    String dec(String v) => utf8.decode(base64Url.decode(base64Url.normalize(v)));
    try {
      final body = dec(code.substring(1));
      if (code[0] == 'e') return 'email:$body';
      if (code[0] == 'o') return 'oauth:$body';
      if (code[0] != 'g') return 'bad';
      final parts = body.split('\n');
      if (parts.length != 2) return 'bad';
      final r = await http.post(Uri.parse('$_base/auth/v1/token?grant_type=password'),
          headers: {'apikey': AppConfig.supabaseAnonKey, 'Content-Type': 'application/json'},
          body: jsonEncode({'email': parts[0], 'password': parts[1]}));
      if (r.statusCode != 200) return authError(r.body);
      isAdmin = false;
      await _p.setBool('sb_admin', false);
      _saveSession(jsonDecode(r.body) as Map<String, dynamic>);
      await _p.setString('sb_gem', parts[0]);
      await _p.setString('sb_gpw', parts[1]);
      await _loadProfile();
      if (profile == null) return 'no profile';
      unawaited(track(open: true));
      unawaited(loadMessages());
      notifyListeners();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// 🔑 چوونا ژوور ب ئیمەیل + پاسۆرد (بۆ نموونە ل مۆبایلەکا نوو)
  Future<String?> loginEmail(String email, String password) async {
    if (!enabled) return 'offline';
    try {
      final r = await http.post(Uri.parse('$_base/auth/v1/token?grant_type=password'),
          headers: {'apikey': AppConfig.supabaseAnonKey, 'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim().toLowerCase(), 'password': password}));
      if (r.statusCode != 200) return authError(r.body);
      isAdmin = false;
      await _p.setBool('sb_admin', false);
      _saveSession(jsonDecode(r.body) as Map<String, dynamic>);
      await _p.setString('sb_email', email.trim().toLowerCase());
      profile = null;
      await _loadProfile();
      if (profile == null) return 'ئەڤ هەژمارە پرۆفایل نینە.';
      unawaited(track(open: true));
      unawaited(loadMessages());
      notifyListeners();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// 🚪 دەرکەفتن: هەمی زانیاریێن ڤێ مۆبایلێ ژێدبەت (پێشکەفتن ل سەر سێرڤەری دمینیت)
  Future<void> logout() async {
    for (final k in _p.getKeys().toList()) {
      if (k == 'theme_mode') continue;
      await _p.remove(k);
    }
    _access = _refresh = userId = null;
    _expires = DateTime.fromMillisecondsSinceEpoch(0);
    profile = null;
    messages = [];
    isAdmin = false;
    notifyListeners();
  }

  // ───────────────────────── ☁️ پاراستنا پێشکەفتنێ ─────────────────────────

  Future<void> pushProgress(Map<String, Object> data, int xp) async {
    if (!enabled || userId == null || isAdmin || profile == null) return;
    try {
      await _ensureToken();
      await http.post(Uri.parse('$_base/rest/v1/progress'),
          headers: {..._h, 'Prefer': 'resolution=merge-duplicates'},
          body: jsonEncode({'user_id': userId, 'data': data, 'xp': xp, 'updated_at': DateTime.now().toUtc().toIso8601String()}));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> pullProgress() async {
    if (!enabled || userId == null || isAdmin) return null;
    try {
      await _ensureToken();
      final r = await http.get(Uri.parse('$_base/rest/v1/progress?user_id=eq.$userId&select=data,xp,updated_at'), headers: _h);
      if (r.statusCode != 200) return null;
      final list = jsonDecode(r.body) as List;
      return list.isEmpty ? null : list.first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// تۆمارکرنا فێرخوازەکێ نوو: ناڤ + تەمەن + جهێ ئاکنجیبوونێ (+ ئیمەیل/پاسۆرد ئەگەر هەبن)
  Future<String?> register(
      {required String name,
      required int? age,
      required String city,
      String? gender,
      String? email,
      String? password,
      String native = 'ku',
      String target = 'de'}) async {
    if (gender != null) await _p.setString('gender', gender);
    if (!enabled) return 'offline';
    try {
      if (email != null && password != null) {
        final err = await _emailAuth(email, password);
        if (err != null) return err;
      } else if (userId == null || isAdmin) {
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
        if (gender != null) 'gender': gender,
        if (email != null) 'email': email.trim().toLowerCase(),
        if (email == null && this.email != null) 'email': this.email,
      };
      Future<http.Response> send() => http.post(Uri.parse('$_base/rest/v1/learners'),
          headers: {..._h, 'Prefer': 'resolution=merge-duplicates,return=representation'}, body: jsonEncode(row));
      var r = await send();
      // ئەگەر ستوونێن نوو (gender / email) هێشتا د داتابەیسێ دا نەبن، بێ وان تۆمار بکە
      if (r.statusCode >= 300 && (r.body.contains('gender') || r.body.contains('email'))) {
        row.remove('gender');
        row.remove('email');
        r = await send();
      }
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
      if (list.isNotEmpty) {
        _setProfile(list.first as Map<String, dynamic>);
        // هەژمارا ب Google/Facebook هاتییە گرێدان: ئیمەیلێ ل پرۆفایلێ بنڤیسە
        final em = _p.getString('sb_email');
        if (em != null && (profile?['email'] == null || '${profile?['email']}'.isEmpty)) unawaited(_patchLearner({'email': em}));
      }
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
    unawaited(loadChat());
    try {
      await _ensureToken();
      final r = await http.get(
          Uri.parse('$_base/rest/v1/messages?or=(learner_id.eq.$userId,learner_id.is.null)&kind=neq.chat&select=*&order=created_at.desc&limit=50'),
          headers: _h);
      if (r.statusCode == 200) {
        messages = (jsonDecode(r.body) as List)
            .map((m) => AppMessage.fromJson(m as Map<String, dynamic>, _readBroadcast))
            .where((m) => m.kind != 'streak') // بیرئینانێن Streak تنێ Push ن
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  /// 💬 نامێن گفتوگۆیێ (یێن من و ئەدمینی)
  Future<void> loadChat() async {
    if (!enabled || userId == null || isAdmin) return;
    try {
      await _ensureToken();
      final r = await http.get(
          Uri.parse('$_base/rest/v1/messages?learner_id=eq.$userId&kind=eq.chat&select=*&order=created_at.asc&limit=500'),
          headers: _h);
      if (r.statusCode == 200) {
        chat = (jsonDecode(r.body) as List).map((m) => AppMessage.fromJson(m as Map<String, dynamic>, _readBroadcast)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<String?> sendChat(String text) async {
    if (!enabled || userId == null) return 'offline';
    final t = text.trim();
    if (t.isEmpty) return null;
    try {
      await _ensureToken();
      final r = await http.post(Uri.parse('$_base/rest/v1/messages'),
          headers: {..._h, 'Prefer': 'return=representation'},
          body: jsonEncode({'learner_id': userId, 'title': '💬 ${name.isEmpty ? 'فێرخواز' : name}', 'body': t, 'kind': 'chat', 'from_learner': true}));
      if (r.statusCode >= 300) return r.body.contains('from_learner') ? 'setup' : '${r.statusCode}';
      await loadChat();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// ئەدمینی نامێن من خواندن ➔ «هاتە خواندن»
  Future<void> markChatRead() async {
    final un = chat.where((m) => !m.fromLearner && !m.read).toList();
    if (un.isEmpty) return;
    for (final m in un) {
      m.read = true;
    }
    notifyListeners();
    try {
      await http.patch(Uri.parse('$_base/rest/v1/messages?learner_id=eq.$userId&kind=eq.chat&from_learner=is.false&read_at=is.null'),
          headers: _h, body: jsonEncode({'read_at': DateTime.now().toUtc().toIso8601String()}));
    } catch (_) {}
  }

  /// ✍️ گوهۆڕینا ناڤی (٢ ناڤ)
  Future<void> updateName(String n) => _patchLearner({'name': n.trim()});

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

  /// پێشکەفتنا فێرخوازی (خەلەتی، دینار …) — پێدڤی ب SQL ـا backend/admin_tools.sql
  Future<Map<String, dynamic>?> adminProgress(String id) async {
    final l = await _getList('progress?user_id=eq.$id&select=data,xp,updated_at');
    if (l.isEmpty) return null;
    final d = l.first['data'];
    return d is Map<String, dynamic> ? d : null;
  }

  /// 💬 هەمی گفتوگۆ (ئەدمین)
  Future<List<Map<String, dynamic>>> adminChats() => _getList('messages?kind=eq.chat&select=*&order=created_at.desc&limit=1000');
  Future<List<Map<String, dynamic>>> adminChat(String id) =>
      _getList('messages?learner_id=eq.$id&kind=eq.chat&select=*&order=created_at.asc&limit=500');

  Future<String?> adminSendChat(String learnerId, String text) async {
    await _ensureToken();
    final r = await http.post(Uri.parse('$_base/rest/v1/messages'),
        headers: _h, body: jsonEncode({'learner_id': learnerId, 'title': '💬 ASP', 'body': text.trim(), 'kind': 'chat'}));
    return r.statusCode < 300 ? null : '${r.statusCode}: ${r.body}';
  }

  Future<void> adminMarkChatRead(String learnerId) async {
    try {
      await _ensureToken();
      await http.patch(Uri.parse('$_base/rest/v1/messages?learner_id=eq.$learnerId&kind=eq.chat&from_learner=is.true&read_at=is.null'),
          headers: _h, body: jsonEncode({'read_at': DateTime.now().toUtc().toIso8601String()}));
    } catch (_) {}
  }

  Future<String?> adminDeleteChat(String learnerId) async {
    await _ensureToken();
    final r = await http.delete(Uri.parse('$_base/rest/v1/messages?learner_id=eq.$learnerId&kind=eq.chat'), headers: _h);
    return r.statusCode < 300 ? null : '${r.statusCode}: ${r.body}';
  }

  /// 🗑️ ژێبرنا هەژمارەکێ ژ بنی — پێدڤی ب SQL ـا backend/asp_2_22.sql
  Future<String?> adminDeleteUser(String id) async {
    await _ensureToken();
    final r = await http.post(Uri.parse('$_base/rest/v1/rpc/admin_delete_user'), headers: _h, body: jsonEncode({'p_id': id}));
    if (r.statusCode < 300) return null;
    if (r.statusCode == 404 || r.body.contains('admin_delete_user')) return 'setup';
    return '${r.statusCode}: ${r.body}';
  }

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
  // ───────── ☁️ پاشەکەفتکرنا دەنگان ل سەر هەژمارێ (Supabase Storage: voices/<uid>/backup.zip) ─────────
  String get _voicesUrl => '$_base/storage/v1/object/voices/$userId/backup.zip';

  /// null = سەرکەفت؛ یان پەیاما خەلەتیێ
  Future<String?> uploadVoices(Uint8List zip) async {
    if (!enabled || userId == null) return 'offline';
    try {
      await _ensureToken();
      final r = await http
          .post(Uri.parse(_voicesUrl),
              headers: {
                'apikey': AppConfig.supabaseAnonKey,
                'Authorization': 'Bearer $_access',
                'Content-Type': 'application/zip',
                'x-upsert': 'true',
              },
              body: zip)
          .timeout(const Duration(minutes: 2));
      return r.statusCode < 300 ? null : '${r.statusCode}';
    } catch (e) {
      return '$e';
    }
  }

  Future<Uint8List?> downloadVoices() async {
    if (!enabled || userId == null) return null;
    try {
      await _ensureToken();
      final r = await http.get(Uri.parse('$_base/storage/v1/object/authenticated/voices/$userId/backup.zip'),
          headers: {'apikey': AppConfig.supabaseAnonKey, 'Authorization': 'Bearer $_access'}).timeout(const Duration(minutes: 2));
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

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
  bool fromLearner = false;

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
    )..fromLearner = j['from_learner'] == true;
  }
}
