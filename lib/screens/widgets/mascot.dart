import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/backend.dart';
import '../../services/voice_service.dart';

/// 🧑‍🏫 کاریکاتێرێن ASP — وەکی Duolingo: چاڤان دقوچینن، دەڤێ خۆ دلڤینن دەمێ دئاخڤن،
/// و ب بازدان / هەژاندنێ بەرسڤێ ددەن.
enum MascotMood { ask, listen, speak, happy, sad }

class MascotChar {
  final String id;
  const MascotChar(this.id);

  String get base => 'assets/mascot/${id}_base.webp';
  String get blink => 'assets/mascot/${id}_blink.webp';
  String get talk1 => 'assets/mascot/${id}_talk1.webp';
  String get talk2 => 'assets/mascot/${id}_talk2.webp';
  String get side => 'assets/mascot/${id}_side.webp';
  List<String> get all => [base, blink, talk1, talk2, side];

  static const teacher = MascotChar('teacher');
  static const woman = MascotChar('woman');
  static const boy = MascotChar('boy');
  static const kid = MascotChar('kid');
  static const happyPhoto = 'assets/mascot/teacher_happy.webp';

  /// کاریکاتێرێ سەرەکی: ئافرەت بۆ ئافرەتان، مامۆستا بۆ هەمییێن دی
  static MascotChar forUser() => Backend.instance.gender == 'f' ? woman : teacher;

  static const _female = {
    'Dilan', 'Frau', 'Frau Ahmad', 'Kundin', 'Lara', 'Lehrerin', 'Lina', 'Mina', 'Sara', 'Verkäuferin', 'Ärztin', 'Rezeption'
  };
  static const _young = {'Tim', 'Sami'};

  /// بۆ دیالۆگان: ل دویف ناڤێ ئاخفتنکەری
  static MascotChar forSpeaker(String who) {
    if (_female.contains(who) || who.startsWith('Frau')) return woman;
    if (_young.contains(who)) return boy;
    return teacher;
  }

  /// هەمی وێنەیان پێشوەخت بار بکە دا لڤین نەڕاوەستیت
  static void precache(BuildContext context) {
    for (final c in [teacher, woman, boy, kid]) {
      for (final p in c.all) {
        precacheImage(AssetImage(p), context);
      }
    }
  }
}

const _praise = ['دەستخۆش! 👏', 'زۆر باشە! 🌟', 'تو قارەمانی! 💪', 'نایاب! 🎉', 'هەر وەسا بەردەوام بە! 🚀', 'ئافەرین! ✨'];
const _comfort = ['نە خەم، جارا بێت! 💪', 'نێزیک بوو! 🙂', 'هێدی هێدی فێر دبین 🌱', 'دیسا تاقی بکە، تو دشێی!'];
String randomPraise() => _praise[Random().nextInt(_praise.length)];
String randomComfort() => _comfort[Random().nextInt(_comfort.length)];

/// 🎭 کاریکاتێرێ زیندی (تنێ وێنە، بێ بالۆن)
class MascotView extends StatefulWidget {
  final MascotChar char;
  final MascotMood mood;
  final double height;

  /// ئەگەر true بیت، دەمێ دەنگ دهێتە لێدان دەڤێ خۆ دلڤینیت
  final bool lipSync;
  const MascotView({super.key, required this.char, this.mood = MascotMood.ask, this.height = 150, this.lipSync = true});

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView> with TickerProviderStateMixin {
  final _rng = Random();
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
  late final AnimationController _react = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..forward();

  bool _blinking = false;
  int _mouth = 0; // 0 گرتی · 1 نیڤ · 2 ڤەکری
  Timer? _blinkTimer, _talkTimer, _cheerTimer;
  bool _cheering = false; // پشتی بەرسڤا دروست کورتەکێ دئاخڤیت

  VoiceService get _voice => VoiceService.instance;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
    if (widget.mood == MascotMood.happy) _react.repeat(period: const Duration(milliseconds: 1400));
    if (widget.lipSync) _voice.speaking.addListener(_onSpeaking);
  }

  @override
  void didUpdateWidget(MascotView old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      if (widget.mood == MascotMood.happy || widget.mood == MascotMood.sad) {
        _react.forward(from: 0);
      }
      if (widget.mood == MascotMood.happy) {
        // وەکی کو دبێژیت «دەستخۆش!»
        _cheering = true;
        _startTalk();
        _cheerTimer?.cancel();
        _cheerTimer = Timer(const Duration(milliseconds: 900), () {
          _cheering = false;
          if (!_voice.speaking.value) _stopTalk();
        });
      }
      if (old.mood == MascotMood.happy || old.mood == MascotMood.sad) _enter.forward(from: 0.4);
    }
  }

  void _onSpeaking() {
    if (_voice.speaking.value) {
      _startTalk();
    } else if (!_cheering) {
      _stopTalk();
    }
  }

  void _startTalk() {
    if (!mounted || _talkTimer != null) return;
    _talkTimer = Timer.periodic(const Duration(milliseconds: 115), (_) {
      if (!mounted) return;
      // ڤەبوونا دەڤی ب شێوەیەکێ سروشتی (نە هەردەم وەکی ئێک)
      final next = const [1, 2, 1, 0, 2, 1, 2, 0][_rng.nextInt(8)];
      setState(() => _mouth = next);
    });
  }

  void _stopTalk() {
    _talkTimer?.cancel();
    _talkTimer = null;
    if (mounted) setState(() => _mouth = 0);
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(Duration(milliseconds: 2200 + _rng.nextInt(3200)), () async {
      if (!mounted) return;
      final twice = _rng.nextInt(5) == 0;
      for (var k = 0; k < (twice ? 2 : 1); k++) {
        setState(() => _blinking = true);
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        setState(() => _blinking = false);
        if (twice) await Future.delayed(const Duration(milliseconds: 140));
      }
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _voice.speaking.removeListener(_onSpeaking);
    _blinkTimer?.cancel();
    _talkTimer?.cancel();
    _cheerTimer?.cancel();
    _idle.dispose();
    _react.dispose();
    _enter.dispose();
    super.dispose();
  }

  String get _frame {
    final c = widget.char;
    if (widget.mood == MascotMood.listen) return c.side;
    if (_mouth == 1) return c.talk1;
    if (_mouth == 2) return c.talk2;
    if (_blinking) return c.blink;
    return c.base;
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final happy = widget.mood == MascotMood.happy;
    final sad = widget.mood == MascotMood.sad;

    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _react, _enter]),
      builder: (_, __) {
        final i = Curves.easeInOut.transform(_idle.value);
        final t = _react.value;
        final e = Curves.easeOutBack.transform(_enter.value);
        var dy = (1 - e) * 40 - 2 * i; // هاتنا ژۆر + بێهنکێشان
        var dx = 0.0, rot = (i - 0.5) * 0.025, sx = 1.0, sy = 1.0 + 0.012 * i;
        if (t > 0 && t < 1) {
          if (happy) {
            // بازدان دگەل squash & stretch
            final jump = sin(pi * min(1, t * 1.6));
            dy -= h * 0.16 * jump;
            sy *= 1 + 0.06 * jump;
            sx *= 1 - 0.04 * jump;
            if (t > 0.6) {
              final land = sin(pi * (t - 0.6) / 0.4);
              sy *= 1 - 0.07 * land;
              sx *= 1 + 0.05 * land;
            }
          } else if (sad) {
            dx = 7 * sin(t * pi * 7) * (1 - t);
            rot += -0.06 * sin(t * pi) ;
            dy += 4 * sin(t * pi);
          }
        }
        if (sad && t >= 1) {
          rot -= 0.03; // سەری کەمەکێ خوار دمینیت
        }
        return Opacity(
          opacity: _enter.value.clamp(0.0, 1.0),
          child: SizedBox(
            height: h,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
              // سیبەر
              Positioned(
                bottom: -4,
                child: Container(
                  width: h * 0.55 * (1 - 0.25 * (-dy / (h * 0.16)).clamp(0.0, 1.0)),
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: RadialGradient(colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent]),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(dx, dy),
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..rotateZ(rot)
                    ..scale(sx, sy),
                  child: Image.asset(_frame, height: h, gaplessPlayback: true, filterQuality: FilterQuality.medium),
                ),
              ),
              if (widget.mood == MascotMood.listen)
                Positioned(top: h * 0.12, right: -h * 0.12, child: _SoundWaves(anim: _idle, size: h * 0.22)),
              if (happy && t > 0 && t < 1) ..._sparkles(h, t),
            ]),
          ),
        );
      },
    );
  }

  List<Widget> _sparkles(double h, double t) {
    const n = 7;
    return [
      for (var k = 0; k < n; k++)
        Positioned(
          left: h * 0.3 + cos(k / n * 2 * pi - pi / 2) * h * 0.55 * Curves.easeOut.transform(t),
          top: h * 0.3 + sin(k / n * 2 * pi - pi / 2) * h * 0.5 * Curves.easeOut.transform(t),
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Icon(k.isEven ? Icons.star_rounded : Icons.auto_awesome, size: h * 0.11, color: k.isEven ? const Color(0xFFFFC800) : Colors.white),
          ),
        ),
    ];
  }
}

/// 🔊 شەپۆلێن دەنگی ل تەنشت گوهێ کاریکاتێری (دەمێ گوهداریێ)
class _SoundWaves extends StatelessWidget {
  final Animation<double> anim;
  final double size;
  const _SoundWaves({required this.anim, required this.size});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _WavePainter(anim.value));
}

class _WavePainter extends CustomPainter {
  final double v;
  _WavePainter(this.v);
  @override
  void paint(Canvas canvas, Size s) {
    for (var k = 0; k < 3; k++) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1CB0F6).withValues(alpha: (0.9 - k * 0.25) * (0.5 + 0.5 * ((v + k * 0.33) % 1)));
      final r = s.width * (0.3 + k * 0.25);
      canvas.drawArc(Rect.fromCircle(center: Offset(0, s.height / 2), radius: r), -0.7, 1.4, false, p);
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.v != v;
}

/// کاریکاتێر + بالۆنا ئاخفتنێ (وەکی Duolingo)
class MascotSays extends StatelessWidget {
  final MascotMood mood;
  final String text;
  final double height;
  final MascotChar char;
  final TextDirection textDirection;
  MascotSays({
    super.key,
    required this.mood,
    required this.text,
    this.height = 150,
    MascotChar? char,
    this.textDirection = TextDirection.rtl,
  }) : char = char ?? MascotChar.forUser();

  Color get _bubble => switch (mood) {
        MascotMood.happy => const Color(0xFF1F4D1A),
        MascotMood.sad => const Color(0xFF4D1F23),
        _ => const Color(0xFF233640),
      };
  Color get _border => switch (mood) {
        MascotMood.happy => const Color(0xFF58CC02),
        MascotMood.sad => const Color(0xFFFF4B4B),
        _ => Colors.white24,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MascotView(char: char, mood: mood, height: height),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: height * 0.42),
            child: CustomPaint(
              painter: _BubbleTail(color: _bubble, border: _border, rtl: Directionality.of(context) == TextDirection.rtl),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsetsDirectional.only(start: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _bubble,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border, width: 2),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: c),
                  ),
                  child: Text(
                    text,
                    key: ValueKey(text),
                    textDirection: textDirection,
                    style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// دوچکا بالۆنێ کو بەرەڤ کاریکاتێری دچیت
class _BubbleTail extends CustomPainter {
  final Color color, border;
  final bool rtl;
  _BubbleTail({required this.color, required this.border, required this.rtl});

  @override
  void paint(Canvas canvas, Size s) {
    final y = s.height * 0.62;
    final edge = rtl ? s.width - 10 : 10.0;
    final tip = rtl ? s.width + 1 : -1.0;
    final path = Path()
      ..moveTo(edge, y - 9)
      ..lineTo(tip, y + 4)
      ..lineTo(edge, y + 9)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
        path,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // ڕێکا هەڤبەش ب رەنگێ بالۆنێ دا خەت دیار نەبیت
    canvas.drawRect(Rect.fromLTWH(rtl ? edge - 3 : edge, y - 7, 4, 14), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubbleTail o) => o.color != color || o.border != border || o.rtl != rtl;
}

/// وێنەیێ بازنەیی (سەر و ملان) بۆ دیالۆگان — دەمێ دئاخڤیت دەڤ دلڤیت
class MascotAvatar extends StatelessWidget {
  final MascotChar char;
  final double size;
  final Color ring;
  final bool talking;
  const MascotAvatar({super.key, required this.char, this.size = 46, this.ring = Colors.white24, this.talking = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2B3B44), border: Border.all(color: ring, width: 2.5)),
      child: ClipOval(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxWidth: size * 1.55,
          maxHeight: size * 1.55 * 1.4,
          child: talking
              ? MascotView(char: char, height: size * 1.55 * 1.4, mood: MascotMood.speak)
              : Image.asset(char.base, height: size * 1.55 * 1.4, fit: BoxFit.fitHeight),
        ),
      ),
    );
  }
}
