import 'package:flutter/material.dart';

import '../models.dart';
import '../services/progress_service.dart';
import '../ui.dart';
import '../services/backend.dart';
import 'account_screens.dart';
import 'home_screen.dart';

/// شاشەیا هەلبژارتنا زمانێ دایکێ و زمانێ فێربوونێ
class LanguageOnboardingScreen extends StatefulWidget {
  const LanguageOnboardingScreen({super.key});

  @override
  State<LanguageOnboardingScreen> createState() => _LanguageOnboardingScreenState();
}

class _LanguageOnboardingScreenState extends State<LanguageOnboardingScreen> {
  late AppLanguage nativeLang = ProgressService.instance.nativeLang;
  late AppLanguage targetLang = ProgressService.instance.targetLang;

  @override
  Widget build(BuildContext context) {
    final n = nativeLang;
    return Directionality(
      textDirection: n.direction,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset('assets/brand/logo.png', width: 132, height: 132),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr(n, 'ب خێر بێی بۆ ASP', 'Willkommen bei ASP', 'Welcome to ASP'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                tr(n, 'زمانان ب دەنگێ خۆ فێر ببە', 'Lerne Sprachen mit deiner eigenen Stimme', 'Learn languages with your own voice'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 32),
              _label(tr(n, '١. زمانێ خۆ یێ ئاخفتنێ هەلبژێرە:', '1. Wähle deine Muttersprache:', '1. Select your native language:')),
              ...AppLanguage.values.map((lang) => _langOption(lang, nativeLang == lang, () {
                    setState(() {
                      nativeLang = lang;
                      if (targetLang == nativeLang) {
                        targetLang = AppLanguage.values.firstWhere((l) => l != nativeLang);
                      }
                    });
                  })),
              const SizedBox(height: 24),
              _label(tr(n, '٢. تە دڤێت کیژ زمانی فێر ببی؟', '2. Welche Sprache möchtest du lernen?', '2. Which language do you want to learn?')),
              ...AppLanguage.values
                  .where((l) => l != nativeLang)
                  .map((lang) => _langOption(lang, targetLang == lang, () => setState(() => targetLang = lang))),
              const SizedBox(height: 32),
              BigButton(
                label: tr(n, 'دەستپێبکە', 'Los geht\'s', 'START LEARNING'),
                onPressed: () async {
                  await ProgressService.instance.setLanguages(nativeLang, targetLang);
                  if (!context.mounted) return;
                  final b = Backend.instance;
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => b.enabled && !b.registered && !b.isAdmin
                              ? const RegisterScreen(next: HomeScreen())
                              : const HomeScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70)),
      );

  Widget _langOption(AppLanguage lang, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue.withValues(alpha: 0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.blue : Colors.white12, width: 2),
        ),
        child: Row(
          children: [
            Text(lang.flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Text(
              lang.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.blue : Colors.white,
              ),
            ),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.blue),
          ],
        ),
      ),
    );
  }
}
