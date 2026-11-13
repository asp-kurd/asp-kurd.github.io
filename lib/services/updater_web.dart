import 'dart:async';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// 🔄 نوویکرنا ئۆتۆماتیک: دەمێ وەشانەکا نوو هاتە بەلاڤکرن، ئەپ ب خۆ دبیتە یا نوو.
/// build_id.txt ل گەل هەر build ـەکێ دهێتە نڤیسین. ئەگەر جودا بیت ژ یا ئەپێ ڤەکری ➔ کاش ژێببە و ڤەکەڤە.
/// ⏸️ نوویکرن ئەپێ ژ نوو بار دکەت (شاشا دەستپێکێ دیار دبیت و وانە دهێتە بڕین)، لەوما تنێ:
///  - ل دەستپێکا ئەپێ (هێشتا شاشا دەستپێکێ یا ل سەر)، یان
///  - پشتی زڤڕینێ ژ پشتێ ب ١٥+ خولەکان.
/// د ناڤبەرێ دا: وەشانا نوو «ل هیڤیێ» دمینیت.
void startAutoUpdate(String buildId) {
  if (buildId.isEmpty) return;
  var busy = false;
  var allowReload = true; // ل دەستپێکێ
  var hiddenAt = 0;
  Timer(const Duration(seconds: 20), () => allowReload = false);

  Future<void> check() async {
    if (busy || !allowReload) return;
    busy = true;
    try {
      // ب base href (/) نە ب لینکێ پەڕێ (دا /asp-d7k2/ ژی کار بکەت)
      final r = await http.get(Uri.parse(web.document.baseURI).resolve('build_id.txt?t=${DateTime.now().millisecondsSinceEpoch}'));
      final remote = r.statusCode == 200 ? r.body.trim() : '';
      if (remote.isNotEmpty && remote != buildId && remote.length < 64) {
        // پاراستن ژ دووبارەبوونا بێ دویماهی
        final store = web.window.sessionStorage;
        if (store.getItem('asp_reload_for') == remote) return;
        store.setItem('asp_reload_for', remote);
        await _clearFlutterCache();
        // لینک وەکی خۆ دمینیت (?h=… یان ?admin=…)، تنێ v دگوهۆڕیت
        final cur = Uri.parse(web.window.location.href);
        final q = Map<String, String>.from(cur.queryParameters)..['v'] = remote;
        web.window.location.replace(cur.replace(queryParameters: q, fragment: '').toString());
      }
    } catch (_) {
    } finally {
      busy = false;
    }
  }

  check();
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (web.document.visibilityState == 'hidden') {
        hiddenAt = DateTime.now().millisecondsSinceEpoch;
        return;
      }
      final away = hiddenAt == 0 ? 0 : DateTime.now().millisecondsSinceEpoch - hiddenAt;
      hiddenAt = 0;
      if (away >= 15 * 60 * 1000) {
        allowReload = true;
        check().whenComplete(() => allowReload = false);
      }
    }).toJS,
  );
}

/// service worker ـێ Flutter و کاشێ وی ژێدبەت (نە یێ ئاگەهداریان)
Future<void> _clearFlutterCache() async {
  try {
    final regs = (await web.window.navigator.serviceWorker.getRegistrations().toDart).toDart;
    for (final r in regs) {
      final url = r.active?.scriptURL ?? r.waiting?.scriptURL ?? r.installing?.scriptURL ?? '';
      if (url.contains('flutter_service_worker')) await r.unregister().toDart;
    }
  } catch (_) {}
  try {
    final keys = (await web.window.caches.keys().toDart).toDart;
    for (final k in keys) {
      await web.window.caches.delete(k.toDart).toDart;
    }
  } catch (_) {}
}
