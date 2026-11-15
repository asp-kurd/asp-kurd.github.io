import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';

/// 🖼️ ئامادەکرنا وێنەیێن کاراکتەران (ل ناڤ ئەپێ، بێ سێرڤەر):
/// ١) پشتا کەسک (#00FF00) ژێدبەت  ٢) جهێ کاراکتەری دبڕیت  ٣) قەبارێ وەکی یێن دی
/// ٤) بۆ سەر و سنگ: خوارێ وێنەی هێدی دبیتە ڕۆهن  ٥) PNG ب پشتا ڤالا
class CharImageResult {
  final Uint8List png;
  final int width, height;

  /// جهێ بڕینێ ل وێنەیێ ئەسلی [x, y, w, h, srcW, srcH] — بۆ ڕاستکرنا «ئاسایی / چاڤ گرتی / ئاخفتن» ل سەر ئێک
  final List<double> frame;
  const CharImageResult(this.png, this.width, this.height, this.frame);
}

const _bustW = 324, _bustH = 360, _fullH = 420, _fullMaxW = 560;

Future<CharImageResult> processCharImage(Uint8List src, {required bool bust, List<double>? frame}) async {
  final codec = await ui.instantiateImageCodec(src);
  final img = (await codec.getNextFrame()).image;
  final sw = img.width.toDouble(), sh = img.height.toDouble();

  // ١) پێشبینینەکا بچووک ➔ جهێ کاراکتەری (bbox)
  Rect box;
  if (frame != null && frame.length == 6 && (frame[4] - sw).abs() < 1 && (frame[5] - sh).abs() < 1) {
    box = Rect.fromLTWH(frame[0], frame[1], frame[2], frame[3]);
  } else {
    final s = min(1.0, 500 / max(sw, sh));
    final pw = max(1, (sw * s).round()), ph = max(1, (sh * s).round());
    final px = await _draw(img, Rect.fromLTWH(0, 0, sw, sh), pw, ph);
    _key(px);
    final bb = _bbox(px, pw, ph);
    final r = bb == null ? Rect.fromLTWH(0, 0, sw, sh) : Rect.fromLTRB(bb.left / s, bb.top / s, bb.right / s, bb.bottom / s);
    box = bust ? _bustFrame(r, sw, sh) : _fullFrame(r, sw, sh);
  }

  // ٢) بڕین + قەبارێ دوماهیێ
  int tw, th;
  if (bust) {
    tw = _bustW;
    th = _bustH;
  } else {
    th = _fullH;
    tw = min(_fullMaxW, max(60, (box.width / box.height * _fullH).round()));
  }
  final out = await _draw(img, box, tw, th);
  _key(out);
  if (bust) _fadeBottom(out, tw, th);
  img.dispose();
  return CharImageResult(encodePng8(out, tw, th), tw, th, [box.left, box.top, box.width, box.height, sw, sh]);
}

/// سەر و سنگ: ب ڕێژا 0.9 (پانی/درێژی)، سەر ل سەری و خوارێ وێنەی وەکی خۆ
Rect _bustFrame(Rect r, double sw, double sh) {
  const ratio = _bustW / _bustH;
  var h = r.height * 1.05, w = h * ratio;
  if (w < r.width * 1.04) {
    w = r.width * 1.04;
    h = w / ratio;
  }
  final cx = r.center.dx;
  final bottom = r.bottom;
  return Rect.fromLTWH(cx - w / 2, bottom - h, w, h);
}

Rect _fullFrame(Rect r, double sw, double sh) {
  final m = max(r.width, r.height) * 0.03;
  return r.inflate(m);
}

/// پارچەیەکێ وێنەی [srcRect] دکێشیتە سەر کانڤاسەکا [w×h] و پیکسلان ددەت (RGBA، alpha ڕاست)
Future<Uint8List> _draw(ui.Image img, Rect srcRect, int w, int h) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawImageRect(img, srcRect, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.high);
  final pic = rec.endRecording();
  final out = await pic.toImage(w, h);
  final data = await out.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  pic.dispose();
  out.dispose();
  return data!.buffer.asUint8List();
}

/// پشتا کەسک ➔ ڤالا (و ڕەنگێ کەسک ل سەر لێڤاران ناهێلیت)
void _key(Uint8List p) {
  for (var i = 0; i < p.length; i += 4) {
    final r = p[i], g = p[i + 1], b = p[i + 2];
    final mx = r > b ? r : b;
    final d = g - mx;
    if (d > 30) {
      final a = (1 - (d - 30) / 70).clamp(0.0, 1.0);
      p[i + 3] = (p[i + 3] * a).round();
    }
    if (d > 12) p[i + 1] = mx; // despill (تنێ ل نێزیکی کەسکا پشتێ، نە جلکێن کەسک)
  }
}

Rect? _bbox(Uint8List p, int w, int h) {
  var x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (p[(y * w + x) * 4 + 3] > 40) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
  }
  if (x1 < 0) return null;
  return Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1 + 1.0, y1 + 1.0);
}

/// خوارێ وێنەیێ سەر و سنگی هێدی هێدی ڤالا دبیت (وەکی کاراکتەرێن دی)
void _fadeBottom(Uint8List p, int w, int h) {
  final start = (h * 0.88).round();
  for (var y = start; y < h; y++) {
    final f = 1 - (y - start) / (h - start);
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4 + 3;
      p[i] = (p[i] * f).round();
    }
  }
}

/// PNG (RGBA 8bit) ب Dart ب تنێ — ل وێب و مۆبایلێ کار دکەت
Uint8List encodePng(Uint8List rgba, int w, int h) {
  final raw = Uint8List(h * (w * 4 + 1));
  var o = 0;
  for (var y = 0; y < h; y++) {
    raw[o++] = 1; // فلتەرێ Sub
    final row = y * w * 4;
    for (var x = 0; x < w * 4; x++) {
      final cur = rgba[row + x];
      final left = x >= 4 ? rgba[row + x - 4] : 0;
      raw[o++] = (cur - left) & 0xFF;
    }
  }
  final idat = Uint8List.fromList(ZLibEncoder().encode(raw, level: 6));
  final b = BytesBuilder();
  b.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8)
    ..setUint8(9, 6)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  _chunk(b, 'IHDR', ihdr.buffer.asUint8List());
  _chunk(b, 'IDAT', idat);
  _chunk(b, 'IEND', Uint8List(0));
  return b.toBytes();
}

void _chunk(BytesBuilder b, String type, Uint8List data) {
  final len = ByteData(4)..setUint32(0, data.length);
  b.add(len.buffer.asUint8List());
  final td = Uint8List.fromList([...type.codeUnits, ...data]);
  b.add(td);
  final crc = ByteData(4)..setUint32(0, getCrc32(td));
  b.add(crc.buffer.asUint8List());
}


/// 🪶 PNG ب ٢٥٦ ڕەنگان (palette): ~٤ جاران سڤکتر (نێزیکی ٢٠–٣٥ KB بۆ هەر وێنەیەکی) و ب چاڤی وەکی خۆ
Uint8List encodePng8(Uint8List rgba, int w, int h) {
  final n = w * h;
  // ١) نموونەیەک ژ پیکسلێن دیار (هەتا ٢٠٬٠٠٠)
  final vis = <int>[];
  for (var i = 0; i < n; i++) {
    if (rgba[i * 4 + 3] > 8) vis.add(i);
  }
  final rnd = Random(1);
  final take = min(vis.length, 20000);
  final sample = <List<int>>[];
  if (vis.length <= take) {
    for (final i in vis) {
      sample.add([rgba[i * 4], rgba[i * 4 + 1], rgba[i * 4 + 2], rgba[i * 4 + 3]]);
    }
  } else {
    for (var k = 0; k < take; k++) {
      final i = vis[rnd.nextInt(vis.length)];
      sample.add([rgba[i * 4], rgba[i * 4 + 1], rgba[i * 4 + 2], rgba[i * 4 + 3]]);
    }
  }
  // ٢) Median cut ➔ ٢٥٥ ڕەنگ (+ ئێکێ ڤالا)
  (List<List<int>>, int, int) stat(List<List<int>> box) {
    var best = -1, bestCh = 0;
    for (var ch = 0; ch < 4; ch++) {
      var lo = 255, hi = 0;
      for (final p in box) {
        final v = p[ch];
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
      final score = box.length < 2 ? 0 : (hi - lo) * box.length;
      if (score > best) {
        best = score;
        bestCh = ch;
      }
    }
    return (box, best, bestCh);
  }

  final boxes = <(List<List<int>>, int, int)>[if (sample.isNotEmpty) stat(sample)];
  while (boxes.length < 255) {
    var bi = -1, best = 0;
    for (var b = 0; b < boxes.length; b++) {
      if (boxes[b].$2 > best) {
        best = boxes[b].$2;
        bi = b;
      }
    }
    if (bi < 0) break;
    final (box, _, ch) = boxes.removeAt(bi);
    box.sort((a, b) => a[ch].compareTo(b[ch]));
    final m = box.length ~/ 2;
    boxes
      ..add(stat(box.sublist(0, m)))
      ..add(stat(box.sublist(m)));
  }
  final pal = <List<int>>[
    [0, 0, 0, 0],
    for (final (box, _, _) in boxes)
      [
        for (var ch = 0; ch < 4; ch++) (box.fold<int>(0, (s, p) => s + p[ch]) / box.length).round(),
      ],
  ];
  // ٣) هەر پیکسلەک ➔ نێزیکترین ڕەنگ
  final idx = Uint8List(n);
  final memo = HashMap<int, int>();
  for (var i = 0; i < n; i++) {
    final a = rgba[i * 4 + 3];
    if (a <= 8) continue;
    final r = rgba[i * 4], g = rgba[i * 4 + 1], b = rgba[i * 4 + 2];
    final key = (r << 24) | (g << 16) | (b << 8) | a;
    idx[i] = memo.putIfAbsent(key, () {
      var bestI = 1, bestD = 1 << 30;
      for (var k = 1; k < pal.length; k++) {
        final p = pal[k];
        final dr = r - p[0], dg = g - p[1], db = b - p[2], da = a - p[3];
        final d = dr * dr + dg * dg + db * db + 2 * da * da;
        if (d < bestD) {
          bestD = d;
          bestI = k;
        }
      }
      return bestI;
    });
  }
  // ٤) PNG (رەنگێن palette + tRNS بۆ ڕۆهنیێ)
  final raw = Uint8List(h * (w + 1));
  var o = 0;
  for (var y = 0; y < h; y++) {
    raw[o++] = 0;
    raw.setRange(o, o + w, idx, y * w);
    o += w;
  }
  final idat = Uint8List.fromList(ZLibEncoder().encode(raw, level: 9));
  final out = BytesBuilder();
  out.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8)
    ..setUint8(9, 3)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  _chunk(out, 'IHDR', ihdr.buffer.asUint8List());
  _chunk(out, 'PLTE', Uint8List.fromList([for (final p in pal) ...[p[0], p[1], p[2]]]));
  _chunk(out, 'tRNS', Uint8List.fromList([for (final p in pal) p[3]]));
  _chunk(out, 'IDAT', idat);
  _chunk(out, 'IEND', Uint8List(0));
  return out.toBytes();
}
