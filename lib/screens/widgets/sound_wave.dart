import 'dart:math';

import 'package:flutter/material.dart';

/// 🎙️ ل جهێ وێنێ مایکێ: خەتێن دەنگی (waveform)
/// [active] ➔ خەت ب لڤین دهێن و دچن (ل دویف [level] ئەگەر هەبیت)
class SoundWave extends StatefulWidget {
  final bool active;
  final double size;
  final Color color;
  final double? level; // ٠..١ — بلندیا دەنگێ راستەقینە (ئەگەر هەبیت)
  const SoundWave({super.key, required this.active, this.size = 48, this.color = Colors.white, this.level});

  @override
  State<SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<SoundWave> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(SoundWave old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _WavePainter(t: _c.value, active: widget.active, color: widget.color, level: widget.level),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  final bool active;
  final Color color;
  final double? level;
  _WavePainter({required this.t, required this.active, required this.color, this.level});

  static const _rest = [0.30, 0.55, 0.80, 1.0, 0.80, 0.55, 0.30];

  @override
  void paint(Canvas canvas, Size size) {
    const n = 7;
    final gap = size.width / (n * 2 - 1);
    final p = Paint()
      ..color = color
      ..strokeWidth = gap * 0.95
      ..strokeCap = StrokeCap.round;
    final mid = size.height / 2;
    for (var i = 0; i < n; i++) {
      double h;
      if (!active) {
        h = _rest[i] * 0.62;
      } else {
        final wave = 0.5 + 0.5 * sin(2 * pi * (t * 2 + i / n * 1.3));
        final amp = level == null ? 1.0 : (0.35 + level!.clamp(0.0, 1.0) * 0.9);
        h = (0.22 + 0.78 * wave * _rest[i]) * amp;
      }
      final half = (size.height * 0.92 * h.clamp(0.12, 1.0)) / 2;
      final x = gap * (i * 2) + gap / 2;
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), p);
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.t != t || o.active != active || o.level != level || o.color != color;
}
