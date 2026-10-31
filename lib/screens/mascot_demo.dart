import 'dart:async';

import 'package:flutter/material.dart';

import '../services/voice_service.dart';
import 'widgets/mascot.dart';

/// 🧪 ?demo=mascot — شاشەیەکا تاقیکرنێ بۆ دیتنا کاریکاتێران (بۆ پشکنینا ئۆتۆماتیک ل GitHub)
class MascotDemo extends StatefulWidget {
  const MascotDemo({super.key});
  @override
  State<MascotDemo> createState() => _MascotDemoState();
}

class _MascotDemoState extends State<MascotDemo> {
  static const moods = [MascotMood.ask, MascotMood.happy, MascotMood.listen, MascotMood.sad, MascotMood.speak];
  int k = 0;
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      setState(() => k = (k + 1) % moods.length);
      final sp = VoiceService.instance.speaking;
      sp.value = moods[k] == MascotMood.speak || moods[k] == MascotMood.ask;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => MascotChar.precache(context));
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = moods[k];
    String text(MascotMood m) => switch (m) {
          MascotMood.happy => 'دەستخۆش! 👏',
          MascotMood.sad => 'نە خەم، جارا بێت! 💪',
          MascotMood.listen => 'گوهداری بکە و رامانێ هەلبژێرە 🎧',
          MascotMood.speak => 'ب دەنگێ خۆ بێژە 🎤',
          MascotMood.ask => 'ئەڤێ وەرگێڕە بۆ ئەلمانی:',
        };
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('mood: ${m.name}', textDirection: TextDirection.ltr),
            const SizedBox(height: 10),
            MascotSays(mood: m, text: text(m), height: 140, char: MascotChar.teacher),
            const SizedBox(height: 24),
            MascotSays(mood: m, text: text(m), height: 140, char: MascotChar.woman),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final c in [MascotChar.teacher, MascotChar.woman, MascotChar.boy, MascotChar.kid])
                MascotAvatar(char: c, size: 56, talking: k.isEven),
            ]),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              MascotView(char: MascotChar.boy, mood: m, height: 120),
              MascotView(char: MascotChar.kid, mood: m, height: 120),
            ]),
          ]),
        ),
      ),
    );
  }
}
