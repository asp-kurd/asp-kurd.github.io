import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// لێدانا دەنگی ل سەر Android/iOS (ئەپا ئاسایی)
class AudioOut {
  final AudioPlayer _player = AudioPlayer();

  /// تنێ بۆ وێبێ پێدڤییە
  void installUnlock() {}

  Future<void> play(Uint8List bytes, {double rate = 1.0, String mime = 'audio/wav'}) async {
    await _player.stop();
    await _player.setPlaybackRate(rate);
    await _player.play(BytesSource(bytes));
  }

  Future<void> stop() => _player.stop();
}
