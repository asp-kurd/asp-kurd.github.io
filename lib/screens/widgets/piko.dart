import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 🦜 پیکۆ — بغبغایێ ASP. ژ پارچان (سەر، لەش، باسک، چاڤ، دەندوک، پێ) پێکدهێت
/// و هەر پارچەیەک ب کۆدی دلڤیت (وەکی rig ـا Rive): هەناسە، چاڤ گرتن، ئاخفتن،
/// کەیف، خەم، هزرکرن، فڕین، سلاڤ و ب ڕێڤە چوون.
enum PikoMood { idle, talk, happy, sad, think, fly, wave, walk }

/// پارچە: ناڤێ وێنەی، قەبارێ وێ یێ سروشتی (px)
const _dims = <String, Size>{
  'head': Size(460, 536),
  'body': Size(355, 405),
  'wing_l': Size(208, 388),
  'wing_r': Size(212, 383),
  'wing_open': Size(413, 326),
  'eye': Size(189, 193),
  'eye_closed': Size(188, 89),
  'brow': Size(118, 64),
  'beak_top': Size(232, 207),
  'beak_bottom': Size(221, 154),
  'foot_l': Size(313, 201),
  'foot_r': Size(310, 203),
};

/// 🎛️ پۆز: هەمی ژمارێن کو لڤینێ دیار دکەن (د کانڤاسەکێ 1000×1000 دا)
class _Pose {
  double rootX = 0, rootY = 0, rootRot = 0, rootSx = 1, rootSy = 1;
  double headRot = 0, headY = 0;
  double wingL = 0.18, wingR = -0.18; // ڕادیان؛ + = باسکێ چەپێ بەرەڤ دەرڤە
  double spread = 0; // ٠ = باسکێن نوشتاندی · ١ = باسکێن ڤەکری (فڕین)
  double tail = 0;
  double footL = 0, footR = 0; // بلندبوون
  double eyeOpen = 1, happyEyes = 0, eyeDX = 0, eyeDY = 0;
  double browRot = 0, browY = 0;
  double beak = 0; // ٠ گرتی … ١ ڤەکری

  static _Pose lerp(_Pose a, _Pose b, double t) {
    double l(double x, double y) => lerpDouble(x, y, t)!;
    return _Pose()
      ..rootX = l(a.rootX, b.rootX)
      ..rootY = l(a.rootY, b.rootY)
      ..rootRot = l(a.rootRot, b.rootRot)
      ..rootSx = l(a.rootSx, b.rootSx)
      ..rootSy = l(a.rootSy, b.rootSy)
      ..headRot = l(a.headRot, b.headRot)
      ..headY = l(a.headY, b.headY)
      ..wingL = l(a.wingL, b.wingL)
      ..wingR = l(a.wingR, b.wingR)
      ..spread = l(a.spread, b.spread)
      ..tail = l(a.tail, b.tail)
      ..footL = l(a.footL, b.footL)
      ..footR = l(a.footR, b.footR)
      ..eyeOpen = l(a.eyeOpen, b.eyeOpen)
      ..happyEyes = l(a.happyEyes, b.happyEyes)
      ..eyeDX = l(a.eyeDX, b.eyeDX)
      ..eyeDY = l(a.eyeDY, b.eyeDY)
      ..browRot = l(a.browRot, b.browRot)
      ..browY = l(a.browY, b.browY)
      ..beak = l(a.beak, b.beak);
  }
}

class Piko extends StatefulWidget {
  final double size;
  final PikoMood mood;

  /// دەندوک دلڤیت (دەمێ دەنگ لێ ددەت) — ب هەر حالەتەکێ دگەل
  final bool talking;
  const Piko({super.key, this.size = 200, this.mood = PikoMood.idle, this.talking = false});

  static const parts = ['head', 'body', 'wing_l', 'wing_r', 'wing_open', 'eye', 'eye_closed', 'brow', 'beak_top', 'beak_bottom', 'foot_l', 'foot_r'];

  /// وێنەیان پێشوەخت بار بکە (دا ل جارا ئێکێ نەلەرزن)
  static Future<void> precache(BuildContext context) async {
    for (final p in parts) {
      await precacheImage(AssetImage('assets/piko/$p.webp'), context);
    }
  }

  @override
  State<Piko> createState() => _PikoState();
}

class _PikoState extends State<Piko> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0);
  PikoMood _from = PikoMood.idle;
  double _switchAt = -10;
  double _nextBlink = 2.2;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _from = widget.mood;
    _ticker = createTicker((e) => _t.value = e.inMicroseconds / 1e6)..start();
  }

  @override
  void didUpdateWidget(covariant Piko old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _from = old.mood;
      _switchAt = _t.value;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  // ───────── 🎬 پۆزێن هەر حالەتەکێ ل دەمێ t ─────────
  _Pose _pose(PikoMood m, double t) {
    const tau = 2 * pi;
    final p = _Pose();
    final breathe = sin(tau * t / 2.6);
    // بنەڕەت: هەناسە، سەر هێدی دلڤیت، دووڤ دهەژیت
    p
      ..rootSy = 1 + 0.014 * breathe
      ..rootSx = 1 - 0.007 * breathe
      ..headRot = 0.035 * sin(tau * t / 4.3)
      ..headY = 4 * breathe
      ..wingL = 0.16 + 0.03 * sin(tau * t / 2.6)
      ..wingR = -0.16 - 0.03 * sin(tau * t / 2.6)
      ..tail = 0.07 * sin(tau * t / 1.8)
      ..eyeDX = 7 * sin(tau * t / 7.3).clamp(-0.6, 0.6);
    switch (m) {
      case PikoMood.idle:
        break;
      case PikoMood.talk:
        p
          ..headRot = 0.06 * sin(tau * t / 1.4)
          ..headY = 6 * sin(tau * t / 0.7)
          ..wingR = -0.2 - 0.5 * max(0.0, sin(tau * t / 1.7));
      case PikoMood.happy:
        final ph = (t % 0.72) / 0.72;
        final up = sin(pi * ph);
        final land = ph < 0.1 || ph > 0.92;
        p
          ..rootY = -85 * up
          ..rootSy = land ? 0.9 : 1.04
          ..rootSx = land ? 1.08 : 0.97
          ..wingL = 1.75 + 0.35 * sin(tau * t * 2.8)
          ..wingR = -1.75 - 0.35 * sin(tau * t * 2.8)
          ..happyEyes = 1
          ..beak = 0.75
          ..browY = -14
          ..footL = 10 * up
          ..footR = 10 * up
          ..tail = 0.25 * sin(tau * t * 2.8);
      case PikoMood.sad:
        p
          ..headRot = -0.09 + 0.015 * sin(tau * t / 3.5)
          ..headY = 30
          ..rootSy = 0.97 + 0.008 * breathe
          ..wingL = -0.05
          ..wingR = 0.05
          ..eyeOpen = 0.72
          ..eyeDY = 14
          ..eyeDX = -4
          ..browRot = -0.38
          ..browY = 6
          ..tail = -0.22;
      case PikoMood.think:
        p
          ..headRot = 0.14 + 0.02 * sin(tau * t / 2.4)
          ..eyeDX = 14
          ..eyeDY = -16
          ..browRot = 0.12
          ..browY = -10
          ..wingR = -2.25 + 0.06 * sin(tau * t / 1.2);
      case PikoMood.fly:
        final f = sin(tau * t * 3.2);
        p
          ..rootY = -70 + 18 * sin(tau * t * 1.6)
          ..rootRot = 0.03 * sin(tau * t * 0.8)
          ..spread = 1
          ..wingL = 0.45 * f
          ..wingR = -0.45 * f
          ..footL = 28
          ..footR = 28
          ..tail = 0.12 * sin(tau * t * 1.6)
          ..beak = 0.35;
      case PikoMood.wave:
        p
          ..headRot = 0.07
          ..wingR = -2.35 + 0.38 * sin(tau * t * 2.3)
          ..beak = 0.45
          ..browY = -8;
      case PikoMood.walk:
        final s = sin(tau * t / 1.0);
        p
          ..rootRot = 0.07 * s
          ..rootX = 10 * s
          ..rootY = -8 * s.abs()
          ..footL = 30 * max(0.0, s)
          ..footR = 30 * max(0.0, -s)
          ..wingL = 0.22 + 0.1 * s
          ..wingR = -0.22 + 0.1 * s
          ..headRot = -0.04 * s
          ..tail = 0.15 * s;
    }
    return p;
  }

  /// 👄 دەندوک دگەل ئاخفتنێ: ڕیتما «پڕگانە» (نە ب ڕێکی، وەکی ئاخفتنا ڕاستەقینە)
  double _syllable(double t) {
    final a = sin(t * 15.0) * 0.55 + sin(t * 23.0 + 1.3) * 0.35 + sin(t * 7.0) * 0.25;
    return a.clamp(0.0, 1.0);
  }

  _Pose _current(double t) {
    final b = ((t - _switchAt) / 0.35).clamp(0.0, 1.0);
    var p = b >= 1 ? _pose(widget.mood, t) : _Pose.lerp(_pose(_from, t), _pose(widget.mood, t), Curves.easeInOut.transform(b));
    // 💬 ئاخفتن
    if (widget.talking || widget.mood == PikoMood.talk) {
      p.beak = max(p.beak, _syllable(t));
    }
    // 😑 چاڤ گرتن (هەر ٢٫٥–٥ چرکان)
    if (t >= _nextBlink) {
      final k = (t - _nextBlink) / 0.16;
      if (k >= 1) {
        _nextBlink = t + 2.5 + _rng.nextDouble() * 2.5;
      } else if (p.happyEyes < 0.5) {
        p.eyeOpen *= (1 - sin(pi * k)).clamp(0.08, 1.0);
      }
    }
    return p;
  }

  // ───────── 🧩 دانانا پارچان ─────────
  Widget _part(String name, double cx, double cy, double s, {Matrix4? m, Offset? pivot, bool flip = false, double opacity = 1}) {
    final d = _dims[name]!;
    final w = d.width * s, h = d.height * s;
    final left = cx - w / 2, top = cy - h / 2;
    Widget img = Image.asset('assets/piko/$name.webp', width: w, height: h, fit: BoxFit.fill, filterQuality: FilterQuality.medium, gaplessPlayback: true);
    if (flip) img = Transform.flip(flipX: true, child: img);
    if (m != null) img = Transform(transform: m, origin: (pivot ?? Offset(cx, cy)) - Offset(left, top), child: img);
    if (opacity < 1) img = Opacity(opacity: opacity.clamp(0.0, 1.0), child: img);
    return Positioned(left: left, top: top, width: w, height: h, child: img);
  }

  Matrix4 _rot(double r) => Matrix4.rotationZ(r);

  Widget _group(Matrix4 m, Offset origin, List<Widget> children) => Positioned.fill(
        child: Transform(transform: m, origin: origin, child: Stack(clipBehavior: Clip.none, children: children)),
      );

  Widget _build(_Pose p) {
    final spread = p.spread;
    final folded = 1 - spread;
    // 👀 چاڤ: گرتن ب scaleY، و چاڤێن کەیفێ (^ ^) ب ڤەگوهاستنێ
    Matrix4 eyeM() => Matrix4.identity()
      ..translate(p.eyeDX, p.eyeDY)
      ..scale(1.0, p.eyeOpen.clamp(0.06, 1.0));
    final head = _group(
      Matrix4.identity()
        ..translate(0.0, p.headY)
        ..rotateZ(p.headRot),
      const Offset(500, 520),
      [
        _part('head', 500, 330, 1.0),
        _part('eye', 400, 335, 0.72, m: eyeM(), opacity: 1 - p.happyEyes),
        _part('eye', 600, 335, 0.72, m: eyeM(), opacity: 1 - p.happyEyes),
        if (p.happyEyes > 0.01) ...[
          _part('eye_closed', 400, 345, 0.62, opacity: p.happyEyes),
          _part('eye_closed', 600, 345, 0.62, opacity: p.happyEyes),
        ],
        _part('brow', 400, 250 + p.browY, 0.66, m: _rot(0.14 + p.browRot)),
        _part('brow', 600, 250 + p.browY, 0.66, m: _rot(-0.14 - p.browRot), flip: true),
        // دەندوکا بنی: دچیتە خوار و هندەک دزڤڕیت
        _part('beak_bottom', 500, 440 + 42 * p.beak, 0.44),
        _part('beak_top', 500, 398 - 4 * p.beak, 0.68),
      ],
    );
    return Transform(
      // 🧍 هەمی لەش: هەلبەزین / خوار بوون / فشار (squash & stretch) ل سەر پێیان
      transform: Matrix4.identity()
        ..translate(p.rootX, p.rootY)
        ..rotateZ(p.rootRot)
        ..scale(p.rootSx, p.rootSy),
      origin: const Offset(500, 940),
      child: Stack(clipBehavior: Clip.none, children: [
        // دووڤ (ل پشت لەشی)
        _part('wing_open', 320, 805, 0.64, m: _rot(-0.38 + p.tail), pivot: const Offset(430, 770)),
        // باسکێن ڤەکری بۆ فڕینێ (ل پشت لەشی)
        if (spread > 0.01) ...[
          _part('wing_open', 250, 580, 0.78, m: _rot(-0.25 + p.wingL), pivot: const Offset(400, 600), opacity: spread),
          _part('wing_open', 750, 580, 0.78, m: _rot(0.25 + p.wingR), pivot: const Offset(600, 600), flip: true, opacity: spread),
        ],
        _part('foot_l', 405, 905 - p.footL, 0.64),
        _part('foot_r', 595, 905 - p.footR, 0.64),
        _part('body', 500, 688, 1.06),
        if (folded > 0.01) ...[
          _part('wing_l', 335, 690, 0.86, m: _rot(0.21 - 0.16 + p.wingL), pivot: const Offset(360, 540), opacity: folded),
          _part('wing_r', 665, 690, 0.86, m: _rot(-0.21 + 0.16 + p.wingR), pivot: const Offset(640, 540), opacity: folded),
        ],
        head,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FittedBox(
        child: SizedBox(
          width: 1000,
          height: 1000,
          child: ValueListenableBuilder<double>(
            valueListenable: _t,
            builder: (_, t, __) => _build(_current(t)),
          ),
        ),
      ),
    );
  }
}
