import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/voice_service.dart';
import '../../ui.dart';

/// دوگمەیا تۆمارکرنێ: دەست ب سەر دا بگرە = تۆمار، بەردە = پاشەکەفت.
/// بازنە ل دویف بلندیا دەنگێ تە مەزن دبیت.
class RecordButton extends StatefulWidget {
  final Future<bool> Function() onStart;
  final Future<void> Function() onStop;
  final double size;
  final String? hintText;
  final int maxSeconds;
  final bool toggle;

  const RecordButton({
    this.toggle = false,
    super.key,
    required this.onStart,
    required this.onStop,
    this.size = 72,
    this.hintText,
    this.maxSeconds = 15,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  bool recording = false;
  double level = 0; // 0..1
  StreamSubscription? _ampSub;
  Timer? _timer;
  int seconds = 0;
  bool _pointerDown = false;

  Future<void> _start() async {
    _pointerDown = true;
    final ok = await widget.onStart();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🎤 دەستووریا مایکرۆفۆنێ بدە ئەپی (Settings ➔ Microphone)'),
      ));
      return;
    }
    // ئەگەر بەکارهێنەری بەری دەستپێکرنێ دەست بەردا
    if (!_pointerDown) {
      await widget.onStop();
      return;
    }
    setState(() {
      recording = true;
      seconds = 0;
    });
    _ampSub = VoiceService.instance.levelStream().listen((v) {
      if (mounted) setState(() => level = v);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => seconds++);
      if (seconds >= widget.maxSeconds) _stop(); // درێژترین دەمێ تۆمارێ
    });
  }

  Future<void> _stop() async {
    _pointerDown = false;
    if (!recording) return;
    await _ampSub?.cancel();
    _timer?.cancel();
    setState(() {
      recording = false;
      level = 0;
    });
    await widget.onStop();
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _timer?.cancel();
    if (recording) VoiceService.instance.cancelRecording();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          // toggle: کلیک = دەستپێکرن، کلیکا دووێ = راوەستان (بۆ خواندنا دەقێن درێژ)
          // نە toggle: دەست ب سەر دا بگرە
          onPointerDown: (_) => widget.toggle ? (recording ? _stop() : _start()) : _start(),
          onPointerUp: (_) => widget.toggle ? null : _stop(),
          onPointerCancel: (_) => widget.toggle ? null : _stop(),
          child: SizedBox(
            width: s * 1.6,
            height: s * 1.6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: s * (1 + (recording ? 0.15 + level * 0.45 : 0)),
                  height: s * (1 + (recording ? 0.15 + level * 0.45 : 0)),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: recording ? 0.25 : 0),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    color: recording ? AppColors.red : AppColors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(recording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: s * 0.5),
                ),
              ],
            ),
          ),
        ),
        if (widget.hintText != null || recording)
          Text(
            recording ? '● 0:${seconds.toString().padLeft(2, '0')}' : widget.hintText!,
            style: TextStyle(color: recording ? AppColors.red : Colors.white54, fontSize: 13),
          ),
      ],
    );
  }
}
