import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'voice_service.dart';

/// 💾 پاشەکەفتکرنا تۆمارێن من: WAV (22kHz/16bit) ➔ μ-law 11kHz/8bit + zip ≈ ٥ جاران بچووکتر.
class VoiceBackup {
  static const rate = 11025;

  static int _mulaw(int s) {
    const bias = 0x84, clip = 32635;
    final sign = (s >> 8) & 0x80;
    if (sign != 0) s = -s;
    if (s > clip) s = clip;
    s += bias;
    var exp = 7;
    for (var m = 0x4000; (s & m) == 0 && exp > 0; m >>= 1) {
      exp--;
    }
    final mant = (s >> (exp + 3)) & 0x0F;
    return (~(sign | (exp << 4) | mant)) & 0xFF;
  }

  static int _unmulaw(int u) {
    u = ~u & 0xFF;
    final sign = u & 0x80, exp = (u >> 4) & 0x07, mant = u & 0x0F;
    var s = ((mant << 3) + 0x84) << exp;
    s -= 0x84;
    return sign != 0 ? -s : s;
  }

  /// WAV ➔ μ-law (نیڤا لەزا نموونەیان)
  static Uint8List? _encode(Uint8List wav) {
    if (wav.length < 46) return null;
    final bd = ByteData.sublistView(wav);
    final srcRate = bd.getUint32(24, Endian.little);
    final bits = bd.getUint16(34, Endian.little);
    if (bits != 16) return null;
    // پارچا data
    var off = 12, dataOff = 44, dataLen = wav.length - 44;
    while (off + 8 <= wav.length) {
      final id = String.fromCharCodes(wav.sublist(off, off + 4));
      final len = bd.getUint32(off + 4, Endian.little);
      if (id == 'data') {
        dataOff = off + 8;
        dataLen = len.clamp(0, wav.length - dataOff);
        break;
      }
      off += 8 + len;
    }
    final n = dataLen ~/ 2;
    final step = srcRate / rate;
    final outN = (n / step).floor();
    final out = Uint8List(outN);
    for (var i = 0; i < outN; i++) {
      final j = (i * step).floor();
      out[i] = _mulaw(bd.getInt16(dataOff + j * 2, Endian.little));
    }
    return out;
  }

  static Uint8List _decode(Uint8List ul) {
    final pcm = ByteData(ul.length * 2);
    for (var i = 0; i < ul.length; i++) {
      pcm.setInt16(i * 2, _unmulaw(ul[i]), Endian.little);
    }
    final h = ByteData(44);
    void str(int o, String s) {
      for (var k = 0; k < 4; k++) {
        h.setUint8(o + k, s.codeUnitAt(k));
      }
    }

    str(0, 'RIFF');
    h.setUint32(4, 36 + ul.length * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);
    h.setUint16(22, 1, Endian.little);
    h.setUint32(24, rate, Endian.little);
    h.setUint32(28, rate * 2, Endian.little);
    h.setUint16(32, 2, Endian.little);
    h.setUint16(34, 16, Endian.little);
    str(36, 'data');
    h.setUint32(40, ul.length * 2, Endian.little);
    return Uint8List.fromList([...h.buffer.asUint8List(), ...pcm.buffer.asUint8List()]);
  }

  /// هەمی تۆمارێن من ➔ zip. (ژمارا تۆماران، فایل)
  static Future<(int, Uint8List)> build() async {
    final v = VoiceService.instance;
    final a = Archive();
    final keys = <String>[];
    for (final k in v.myRecordingKeys) {
      final wav = await v.rawRecording(k);
      if (wav == null) continue;
      final ul = _encode(wav);
      if (ul == null) continue;
      final name = '${keys.length}.ul';
      a.addFile(ArchiveFile(name, ul.length, ul));
      keys.add(k);
    }
    final man = utf8.encode(jsonEncode({'v': 1, 'rate': rate, 'keys': keys}));
    a.addFile(ArchiveFile('manifest.json', man.length, man));
    return (keys.length, Uint8List.fromList(ZipEncoder().encode(a)!));
  }

  /// zip ➔ تۆمار (ل سەر یێن هەین دنڤیسیت). ژمارا تۆمارێن ڤەگەڕاندی
  static Future<int> restore(Uint8List zip) async {
    final a = ZipDecoder().decodeBytes(zip);
    final mf = a.findFile('manifest.json');
    if (mf == null) return 0;
    final keys = ((jsonDecode(utf8.decode(mf.content as List<int>)) as Map)['keys'] as List).cast<String>();
    var n = 0;
    for (var i = 0; i < keys.length; i++) {
      final f = a.findFile('$i.ul');
      if (f == null || !keys[i].startsWith('mine/')) continue;
      await VoiceService.instance.putRawRecording(keys[i], _decode(Uint8List.fromList(f.content as List<int>)));
      n++;
    }
    return n;
  }
}
