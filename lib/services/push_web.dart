import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

@JS('JSON.stringify')
external JSString _stringify(JSAny value);

/// Web Push ل سەر iPhone (iOS 16.4+) تنێ دەمێ ئەپ ل سەر Home Screen بیت.
bool get pushSupported =>
    globalContext.has('Notification') && web.window.navigator.has('serviceWorker') && globalContext.has('PushManager');

String get pushPermission => pushSupported ? web.Notification.permission : 'unsupported';

Uint8List _b64url(String s) {
  var t = s.replaceAll('-', '+').replaceAll('_', '/');
  while (t.length % 4 != 0) {
    t += '=';
  }
  return base64.decode(t);
}

/// داخوازا دەستووریێ + تۆمارکرنا Push. دڤێت ژ دەستلێدانەکێ بهێتە بانگکرن.
Future<Map<String, dynamic>?> subscribePush(String vapidPublicKey) async {
  if (!pushSupported) return null;
  final perm = (await web.Notification.requestPermission().toDart).toDart;
  if (perm != 'granted') return null;
  final container = web.window.navigator.serviceWorker;
  // scope یا جودا دا دگەل service worker ـا Flutter تێک نەچیت
  final reg = await container
      .register('push-sw.js'.toJS, web.RegistrationOptions(scope: './push/'))
      .toDart;
  var sub = await reg.pushManager.getSubscription().toDart;
  sub ??= await reg.pushManager
      .subscribe(web.PushSubscriptionOptionsInit(userVisibleOnly: true, applicationServerKey: _b64url(vapidPublicKey).toJS))
      .toDart;
  return jsonDecode(_stringify(sub).toDart) as Map<String, dynamic>;
}


// ───────── 📲 دامەزراندن ل سەر مۆبایلێ (PWA) ─────────

/// 'ios' · 'android' · 'other'
String get platformKind {
  final ua = web.window.navigator.userAgent.toLowerCase();
  if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod')) return 'ios';
  if (ua.contains('macintosh') && web.window.navigator.maxTouchPoints > 1) return 'ios'; // iPad
  if (ua.contains('android')) return 'android';
  return 'other';
}

/// ئەپ ژ Home Screen هاتییە ڤەکرن؟
bool get isStandalone {
  if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
  final s = (web.window.navigator as JSObject)['standalone'];
  return s != null && s.dartify() == true;
}

/// Android/Chrome: دەمێ دوگمەیا دامەزراندنێ ئامادە بیت
bool get canPromptInstall {
  final e = globalContext['__aspInstall'];
  return e != null && !e.isUndefinedOrNull;
}

/// پەنجەرەیا دامەزراندنێ یا Android نیشان ددەت. true = هاتە دامەزراندن
Future<bool> promptInstall() async {
  final e = globalContext['__aspInstall'];
  if (e == null || e.isUndefinedOrNull) return false;
  final ev = e as JSObject;
  ev.callMethod('prompt'.toJS);
  try {
    final choice = await (ev['userChoice'] as JSPromise<JSObject>).toDart;
    final outcome = choice['outcome']?.dartify();
    globalContext['__aspInstall'] = null;
    return outcome == 'accepted';
  } catch (_) {
    return false;
  }
}
