import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// لێدانا دەنگی ل سەر وێبێ (Safari / iPhone) ب Web Audio API.
/// iPhone رێکێ نادەت دەنگ بێ دەستلێدان لێبدەت؛ لەوما ل دەستلێدانێ
/// AudioContext و speechSynthesis «ڤەدکەین» (unlock)، پاشان هەمی دەنگ کار دکەن.
///
/// 🔁 دەمێ ئەپ ل پشتێ دمینیت، iPhone ئامیرێ دەنگی رادوەستینیت (state = interrupted/suspended)
/// و جار جار ب تەمامی دشکێت. ل ڤێرێ: پشتی زڤڕینێ ب خۆ ڤەدکەینەڤە، و ئەگەر
/// ڤەنەبوو، AudioContext ـەکێ نوو دروست دکەین — بێ کو پێدڤی ب گرتنا ئەپێ بیت.
class AudioOut {
  static final List<AudioOut> _all = [];
  static bool _lifecycle = false;
  static int _hiddenAt = 0;

  web.AudioContext? _ctx;
  web.AudioBufferSourceNode? _src;
  bool _unlocked = false;

  AudioOut() {
    _all.add(this);
    _installLifecycle();
  }

  web.AudioContext get _context => _ctx ??= web.AudioContext();

  bool get _running => _ctx?.state == 'running';

  /// AudioContext ـا شکەستی بگرە و یەکا نوو دروست بکە
  void _recreate() {
    final old = _ctx;
    _ctx = null;
    _src = null;
    _unlocked = false;
    try {
      old?.close();
    } catch (_) {}
  }

  void _unlock() {
    // ئەگەر نوکە کار دکەت، پێدڤی ب چ نینە
    if (_unlocked && _running) return;
    try {
      final c = _context;
      c.resume();
      // دەنگەکێ بێدەنگ بۆ ڤەکرنا Audio ل iOS
      final b = c.createBuffer(1, 1, 22050);
      final s = c.createBufferSource();
      s.buffer = b;
      s.connect(c.destination);
      s.start();
      // ڤەکرنا TTS ل iOS
      web.window.speechSynthesis.speak(web.SpeechSynthesisUtterance(''));
      _unlocked = true;
    } catch (_) {}
  }

  void installUnlock() {
    final handler = ((web.Event _) => _unlock()).toJS;
    for (final type in ['pointerdown', 'touchend', 'click', 'keydown']) {
      web.document.addEventListener(type, handler, web.AddEventListenerOptions(capture: true));
    }
  }

  /// 🔁 زڤڕین ژ پشتێ ➔ هەمی ئامیرێن دەنگی ژ نوو ڤەبن
  static void _installLifecycle() {
    if (_lifecycle) return;
    _lifecycle = true;
    void back() {
      final away = _hiddenAt == 0 ? 0 : DateTime.now().millisecondsSinceEpoch - _hiddenAt;
      _hiddenAt = 0;
      try {
        web.window.speechSynthesis.cancel(); // TTS ل iOS پشتی پشتێ «دمینیت»
      } catch (_) {}
      for (final a in _all) {
        a._unlocked = false; // دەستلێدانا داهاتی دیسا ڤەدکەت
        // پشتی دەمەکێ درێژ: AudioContext ـا کەڤن ل iOS گەلەک جاران ب بێدەنگی دشکێت ➔ یا نوو
        if (away > 20000) {
          a._recreate();
        } else {
          try {
            a._ctx?.resume();
          } catch (_) {}
        }
      }
    }

    web.document.addEventListener(
        'visibilitychange',
        ((web.Event _) {
          if (web.document.visibilityState == 'hidden') {
            _hiddenAt = DateTime.now().millisecondsSinceEpoch;
          } else {
            back();
          }
        }).toJS);
    web.window.addEventListener('pageshow', ((web.Event _) => back()).toJS);
    web.window.addEventListener('focus', ((web.Event _) {
      for (final a in _all) {
        if (a._ctx != null && !a._running) {
          try {
            a._ctx!.resume();
          } catch (_) {}
        }
      }
    }).toJS);
  }

  /// AudioContext ـەکا کو کار دکەت ددەت؛ ئەگەر نەبیت، یەکا نوو
  Future<web.AudioContext> _ready() async {
    var c = _context;
    if (c.state != 'running') {
      try {
        await c.resume().toDart.timeout(const Duration(milliseconds: 700));
      } catch (_) {}
    }
    if (c.state == 'closed' || c.state == 'interrupted' || c.state == 'suspended') {
      _recreate();
      c = _context;
      _unlock();
      try {
        await c.resume().toDart.timeout(const Duration(milliseconds: 700));
      } catch (_) {}
    }
    return c;
  }

  /// درێژیا دەنگی ب چرکان ددەتە دەر (بۆ لڤینا دەڤێ کاریکاتێری)
  Future<double> play(Uint8List bytes, {double rate = 1.0, String mime = 'audio/wav'}) async {
    stopSync();
    try {
      return await _playOn(await _ready(), bytes, rate);
    } catch (_) {
      // 🔁 جارەکا دی ب AudioContext ـەکا نوو
      _recreate();
      return await _playOn(await _ready(), bytes, rate);
    }
  }

  Future<double> _playOn(web.AudioContext c, Uint8List bytes, double rate) async {
    // کۆپی: decodeAudioData بافەری دبەت
    final copy = Uint8List.fromList(bytes);
    final buffer = await c.decodeAudioData(copy.buffer.toJS).toDart;
    final src = c.createBufferSource();
    src.buffer = buffer;
    src.playbackRate.value = rate;
    src.connect(c.destination);
    src.start();
    _src = src;
    return buffer.duration / rate;
  }

  void stopSync() {
    try {
      _src?.stop();
    } catch (_) {}
    _src = null;
  }

  Future<void> stop() async => stopSync();
}
