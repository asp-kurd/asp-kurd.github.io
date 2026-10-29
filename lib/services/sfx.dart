import 'dart:math';

import 'progress_service.dart';
import 'voice_service.dart';

/// 🎵 دەنگێن کورت یێن یاریێ — ل دویڤ ڕێکخستنێن بکارهێنەری
class Sfx {
  static final _rng = Random();
  static ProgressService get _p => ProgressService.instance;

  static void correct() {
    if (_p.gameSounds) VoiceService.instance.playFx('correct');
  }

  /// پشتی خەلەتیێ؛ جار جار دەنگەکێ کەنی (ئەگەر ڤەکری بیت)
  static void wrong() {
    if (!_p.gameSounds) return;
    final funny = _p.funnySounds && _rng.nextInt(3) == 0;
    VoiceService.instance.playFx(funny ? 'funny' : 'wrong');
  }

  static void done() {
    if (_p.gameSounds) VoiceService.instance.playFx('done');
  }

  static void star() {
    if (_p.gameSounds) VoiceService.instance.playFx('star');
  }
}
