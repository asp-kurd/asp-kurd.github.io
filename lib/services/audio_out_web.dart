import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// لێدانا دەنگی ل سەر وێبێ (Safari / iPhone) ب Web Audio API.
/// iPhone رێکێ نادەت دەنگ بێ دەستلێدان لێبدەت؛ لەوما ل ئێکەم دەستلێدانێ
/// AudioContext و speechSynthesis «ڤەدکەین» (unlock)، پاشان هەمی دەنگ کار دکەن.
class AudioOut {
  web.AudioContext? _ctx;
  web.AudioBufferSourceNode? _src;
  bool _unlocked = false;

  web.AudioContext get _context => _ctx ??= web.AudioContext();

  void _unlock() {
    if (_unlocked) return;
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

  Future<void> play(Uint8List bytes, {double rate = 1.0, String mime = 'audio/wav'}) async {
    stopSync();
    final c = _context;
    if (c.state == 'suspended') {
      try {
        await c.resume().toDart;
      } catch (_) {}
    }
    // کۆپی: decodeAudioData بافەری دبەت
    final copy = Uint8List.fromList(bytes);
    final buffer = await c.decodeAudioData(copy.buffer.toJS).toDart;
    final src = c.createBufferSource();
    src.buffer = buffer;
    src.playbackRate.value = rate;
    src.connect(c.destination);
    src.start();
    _src = src;
  }

  void stopSync() {
    try {
      _src?.stop();
    } catch (_) {}
    _src = null;
  }

  Future<void> stop() async => stopSync();
}
