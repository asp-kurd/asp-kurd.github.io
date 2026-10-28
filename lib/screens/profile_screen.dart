import 'package:flutter/material.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final v = VoiceService.instance;
    final n = p.nativeLang;

    Widget statCard(IconData icon, Color c, String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              Icon(icon, color: c, size: 30),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
        );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(tr(n, 'پرۆفایلێ من', 'Mein Profil', 'My profile'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            statCard(Icons.bolt, AppColors.gold, '${p.xp}', 'XP'),
            const SizedBox(width: 10),
            statCard(Icons.local_fire_department, AppColors.orange, '${p.streak}', tr(n, 'رۆژ', 'Tage', 'days')),
            const SizedBox(width: 10),
            statCard(Icons.emoji_events_rounded, AppColors.green, '${p.completedUnits.length}/${appCurriculum.length}',
                tr(n, 'پێنگاڤ', 'Einheiten', 'units')),
          ]),
          const SizedBox(height: 24),
          Text(tr(n, '🏅 دەستکەفت', '🏅 Erfolge', '🏅 Achievements'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: p.achievements
                .map((a) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: a.unlocked ? AppColors.gold.withValues(alpha: 0.15) : AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: a.unlocked ? AppColors.gold : Colors.white12, width: 2),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Opacity(opacity: a.unlocked ? 1 : 0.25, child: Text(a.emoji, style: const TextStyle(fontSize: 30))),
                        const SizedBox(height: 6),
                        Text(tr(n, a.ku, a.de, a.en),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(fontSize: 12, color: a.unlocked ? Colors.white : Colors.white38)),
                      ]),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Text(tr(n, '☀️ ئارمانجا رۆژانە', '☀️ Tagesziel', '☀️ Daily goal'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: p,
            builder: (_, __) => SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 20, label: Text('20')),
                ButtonSegment(value: 30, label: Text('30')),
                ButtonSegment(value: 50, label: Text('50')),
                ButtonSegment(value: 80, label: Text('80')),
              ],
              selected: {p.dailyGoal},
              onSelectionChanged: (s) => p.setDailyGoal(s.first),
            ),
          ),
          const SizedBox(height: 24),
          Text(tr(n, '🎤 تۆمارێن دەنگێ من', '🎤 Meine Aufnahmen', '🎤 My recordings'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...AppLanguage.values.map((l) {
            final c = v.countMyVoice(l, allConcepts); // تۆمار + کلۆن
            return ListTile(
              leading: Text(l.flag, style: const TextStyle(fontSize: 24)),
              title: Text(l.title),
              trailing: Text('$c / ${allConcepts.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          }),
          const SizedBox(height: 16),
          ListTile(
            tileColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: const Icon(Icons.translate_rounded),
            title: Text(tr(n, 'گوهۆڕینا زمانان', 'Sprachen ändern', 'Change languages')),
            subtitle: Text('${p.nativeLang.title} ➔ ${p.targetLang.title}'),
            onTap: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LanguageOnboardingScreen())),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: const Icon(Icons.restart_alt_rounded, color: AppColors.red),
            title: Text(tr(n, 'پێشکەفتنێ ژ نوو دەستپێبکە', 'Fortschritt zurücksetzen', 'Reset progress')),
            subtitle: Text(tr(n, 'تۆمارێن دەنگی نائێنە ژێبرن', 'Aufnahmen bleiben erhalten', 'Recordings are kept')),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(tr(n, 'تو پشتڕاستی؟', 'Bist du sicher?', 'Are you sure?')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('✕')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('✓')),
                  ],
                ),
              );
              if (ok == true) await p.resetAll();
            },
          ),
        ],
      ),
    );
  }
}
