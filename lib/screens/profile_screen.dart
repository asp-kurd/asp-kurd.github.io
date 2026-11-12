import 'package:flutter/material.dart';

import 'chat_screen.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/voice_service.dart';
import '../services/backend.dart';
import '../ui.dart';
import 'account_screens.dart';
import 'character_screen.dart';
import 'widgets/mascot.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import 'stats_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final v = VoiceService.instance;
    final n = p.nativeLang;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (Backend.instance.registered) ...[
            ListenableBuilder(
              listenable: Backend.instance,
              builder: (_, __) {
                final nm = Backend.instance.name;
                final full = fullNameOk(nm);
                return Row(children: [
                  CircleAvatar(radius: 26, backgroundColor: AppColors.chip, backgroundImage: AssetImage(MascotChar.forUser().base)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nm, style: const TextStyle(fontFamily: 'Sarchia', fontSize: 24, fontWeight: FontWeight.bold)),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                        child: Text(aspHandle(nm), style: TextStyle(color: AppColors.goldText, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      if (!full)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('⚠️ ناڤێ خۆ یێ تەمام (٢ ناڤ) بنڤیسە ✏️', style: TextStyle(color: AppColors.orange, fontSize: 12)),
                        ),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'گوهۆڕینا ناڤی',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _editName(context),
                  ),
                ]);
              },
            ),
            const SizedBox(height: 14),
            // 💬 پەیوەندی ب ئەدمینی (گفتوگۆیا راستەوخۆ)
            ListenableBuilder(
              listenable: Backend.instance,
              builder: (_, __) => InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1CB0F6), Color(0xFF2B70C9)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    Badge(
                      isLabelVisible: Backend.instance.chatUnread > 0,
                      label: Text('${Backend.instance.chatUnread}'),
                      child: const Text('💬', style: TextStyle(fontSize: 34)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('پەیوەندی ب ئەدمینی', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          Backend.instance.chatUnread > 0
                              ? '${Backend.instance.chatUnread} بەرسڤێن نوو 📩'
                              : 'پرسیار یان پێشنیارەکا تە هەیە؟ راستەوخۆ بنڤیسە 🔒',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ]),
                    ),
                    const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 30),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: AppColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.chip,
                backgroundImage: AssetImage(MascotChar.forUser().base),
              ),
              title: Text('🦸 کاراکتەرێ من: ${MascotChar.forUser().name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('بگوهۆڕە'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CharacterPickerScreen())),
            ),
            const SizedBox(height: 12),
            // 📬 نامە (ژ سەرێ ماڵێ هاتنە ڤێرێ)
            ListenableBuilder(
              listenable: Backend.instance,
              builder: (_, __) => ListTile(
                tileColor: AppColors.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Badge(
                  isLabelVisible: Backend.instance.unread > 0,
                  label: Text('${Backend.instance.unread}'),
                  child: const Icon(Icons.mail_rounded, size: 30, color: AppColors.blue),
                ),
                title: const Text('📬 نامەیێن من', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(Backend.instance.unread > 0 ? '${Backend.instance.unread} نامێن نوو' : 'هەمی نامە ژ ASP'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen())),
              ),
            ),
            const SizedBox(height: 12),
            // 🌍 زمانێن دی — زوو
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.blue.withValues(alpha: 0.18), AppColors.green.withValues(alpha: 0.18)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.blue.withValues(alpha: 0.5)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Text('🌍', style: TextStyle(fontSize: 26)),
                  SizedBox(width: 10),
                  Expanded(child: Text('زمانێن دی ژی دێ زوو بەردەست بن!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 6),
                Text('نوکە: 🇩🇪 ئەلمانی و 🇬🇧 ئینگلیزی. ل نێزیک: زمانێن دی ب هەمان رێک — ب کوردیا بادینی.',
                    style: TextStyle(color: AppColors.fg70, height: 1.5)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final l in const ['🇫🇷 Français', '🇹🇷 Türkçe', '🇸🇦 العربية', '🇪🇸 Español', '🇳🇱 Nederlands', '🇸🇪 Svenska'])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
                      child: Text('$l · زوو', style: TextStyle(fontSize: 13, color: AppColors.fg70)),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            const AccountCard(),
            const SizedBox(height: 12),
            const NotifyCard(),
          ],
          Row(children: [
            Expanded(
              child: Text(tr(n, 'ئامار و پرۆفایل', 'Statistik & Profil', 'Statistics & profile'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ]),
          Text(tr(n, 'ڤێبوونا تە یا راستەقینە', 'Deine echte Übung', 'Your real practice'),
              style: TextStyle(color: AppColors.fg60)),
          const SizedBox(height: 14),
          const StatsSection(),
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
                        border: Border.all(color: a.unlocked ? AppColors.gold : AppColors.fg12, width: 2),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Opacity(opacity: a.unlocked ? 1 : 0.25, child: Text(a.emoji, style: const TextStyle(fontSize: 30))),
                        const SizedBox(height: 6),
                        Text(tr(n, a.ku, a.de, a.en),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(fontSize: 12, color: a.unlocked ? AppColors.fg : AppColors.fg38)),
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
          const SizedBox(height: 26),
          // 🏷️ ڤێرژنا ئەپێ
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(20)),
              child: Text('asp 2.22', textDirection: TextDirection.ltr,
                  style: TextStyle(color: AppColors.fg60, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 18),
          // 🛡️ ئەدمین ل ڤێرە نینە: تنێ ب لینکێ تایبەت (?admin=...) ڤەدبیت
        ],
      ),
    );
  }
}


/// ✍️ گوهۆڕینا ناڤی: دڤێت ٢ ناڤ بن
Future<void> _editName(BuildContext context) async {
  final c = TextEditingController(text: Backend.instance.name);
  String? err;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('✏️ ناڤێ تە یێ تەمام'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setS(() => err = null),
              decoration: InputDecoration(hintText: 'ئازاد بەرواری', errorText: err),
            ),
            const SizedBox(height: 8),
            Text('٢ ناڤ: ناڤێ تە و ناڤێ بابێ تە. ل ئەپێ دێ وەکی «${aspHandle(c.text)}» دیار بیت.',
                style: TextStyle(fontSize: 12, color: AppColors.fg60)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('نە')),
            FilledButton(
              onPressed: () async {
                if (!fullNameOk(c.text)) {
                  setS(() => err = 'دڤێت ٢ ناڤ بن');
                  return;
                }
                await Backend.instance.updateName(c.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('پاشەکەفت بکە'),
            ),
          ],
        ),
      ),
    ),
  );
}
