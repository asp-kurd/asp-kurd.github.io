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

/// 🔔 دەمێ Push دگەهیت و ئەپ ڤەکرییە ➔ [onPush] (ئاواز + نویکرنا نامەیان)
void listenPush(void Function() onPush) {
  if (!pushSupported) return;
  try {
    final c = web.window.navigator.serviceWorker;
    c.addEventListener('message', ((web.MessageEvent e) {
      try {
        final d = e.data as JSObject?;
        if (d != null && d['asp']?.dartify() == 'push') onPush();
      } catch (_) {}
    }).toJS);
    // push-sw.js یا نوو بینە (بۆ کەسێن بەری نوکە تۆمارکرین)
    if (web.Notification.permission == 'granted') {
      () async {
        try {
          final r = await c.getRegistration('./push/').toDart;
          (r as JSObject?)?.callMethod('update'.toJS);
        } catch (_) {}
      }();
    }
  } catch (_) {}
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

// ───────── 📲 ژ Safari بۆ ئەپا سەر شاشێ (iPhone) ─────────

/// iPhone: ئەپا سەر شاشێ (Home Screen) جهێ خۆ یێ جودا هەیە (نە وەکی Safari).
/// لەوما کۆدەکێ دانینە د لینکێ دا: دەمێ کەس «Add to Home Screen» دکەت، ئەپ ب ڤی لینکی ڤەدبیت و هەژمار بەردەوام دبیت.
void prepareHomeScreenHandoff(String code) {
  // بێی manifest، Safari لینکێ نوکە (دگەل کۆدی) بۆ ئەپێ ب کار دئینیت
  web.document.querySelector('link[rel="manifest"]')?.remove();
  final path = web.window.location.pathname;
  web.window.history.replaceState(null, '', '$path?h=$code');
}


/// 🛡️ پەڕێ ئەدمینی: ئایکۆنەکا جودا ل سەر Home Screen (ب ناڤێ «ASP Admin» و لینکێ تایبەت)
/// 🛡️ پەڕێ /asp-d7k2/ (admin/index.html) ئەڤ نیشانە دانایە
bool get isAdminPage => globalContext['__aspAdmin']?.dartify() == true;

void prepareAdminHomeScreen() {
  web.document.querySelector('link[rel="manifest"]')?.remove();
  web.document.title = 'ASP Admin';
  final m = web.document.querySelector('meta[name="apple-mobile-web-app-title"]');
  m?.setAttribute('content', 'ASP Admin');
}

// ───────── 🔐 Google / Facebook ─────────

/// ڤەکرنا لینکێ د هەمان پەنجەرێ دا (بۆ چوونا ژوور ب Google/Facebook)
void openUrl(String url) => web.window.location.href = url;

/// 🔗 لینکەکێ دەرەکی (Facebook، TikTok …) د پەنجەرەکا نوو دا؛ mailto:/tel: ئێکسەر
void openExternal(String url) {
  try {
    if (url.startsWith('mailto:') || url.startsWith('tel:')) {
      web.window.location.href = url;
    } else {
      web.window.open(url, '_blank');
    }
  } catch (_) {}
}

/// iPhone: Google ل پەنجەرەکا جودا ڤەبوو و زڤڕی (نە ل ناڤ ئەپێ) ➔ تنێ «Done» بکە
bool get oauthOverlay => globalContext['__aspOAuthDone']?.dartify() == true;

/// براوزەرێن ناڤ ئەپان (Instagram, Facebook, TikTok…) — نەشێن «Add to Home Screen» بکەن
bool get inAppBrowser {
  final ua = web.window.navigator.userAgent;
  return RegExp(r'Instagram|FBAN|FBAV|FB_IAB|TikTok|musical_ly|Snapchat|Line/|Twitter|LinkedInApp|GSA/', caseSensitive: false).hasMatch(ua);
}

/// Safari یە یان نە (Chrome/Firefox ل iPhone ب CriOS/FxiOS)
bool get iosNonSafari {
  final ua = web.window.navigator.userAgent;
  return RegExp(r'CriOS|FxiOS|EdgiOS|OPiOS', caseSensitive: false).hasMatch(ua);
}

/// کۆپیکرنا لینکێ ئەپێ
Future<void> copyText(String t) async {
  try {
    await web.window.navigator.clipboard.writeText(t).toDart;
  } catch (_) {}
}

/// 📲 iPhone: پەنجەرا «Share» یا Safariێ ڤەدکەت (تێدا «Add to Home Screen» هەیە)
Future<bool> openShareSheet() async {
  try {
    final url = '${web.window.location.origin}${web.window.location.pathname}';
    await web.window.navigator.share(web.ShareData(title: 'ASP', url: url)).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
