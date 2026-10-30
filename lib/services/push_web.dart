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
