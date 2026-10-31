import 'dart:async';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// 🔄 نوویکرنا ئۆتۆماتیک: دەمێ وەشانەکا نوو هاتە بەلاڤکرن، ئەپ ب خۆ دبیتە یا نوو.
/// build_id.txt ل گەل هەر build ـەکێ دهێتە نڤیسین. ئەگەر جودا بیت ژ یا ئەپێ ڤەکری ➔ کاش ژێببە و ڤەکەڤە.
void startAutoUpdate(String buildId) {
  if (buildId.isEmpty) return;
  var busy = false;

  Future<void> check() async {
    if (busy) return;
    busy = true;
    try {
      final r = await http.get(Uri.base.resolve('build_id.txt?t=${DateTime.now().millisecondsSinceEpoch}'));
      final remote = r.statusCode == 200 ? r.body.trim() : '';
      if (remote.isNotEmpty && remote != buildId && remote.length < 64) {
        // پاراستن ژ دووبارەبوونا بێ دویماهی
        final store = web.window.sessionStorage;
        if (store.getItem('asp_reload_for') == remote) return;
        store.setItem('asp_reload_for', remote);
        await _clearFlutterCache();
        final path = web.window.location.pathname;
        web.window.location.replace('$path?v=$remote');
      }
    } catch (_) {
    } finally {
      busy = false;
    }
  }

  check();
  Timer.periodic(const Duration(minutes: 5), (_) => check());
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (web.document.visibilityState == 'visible') check();
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
