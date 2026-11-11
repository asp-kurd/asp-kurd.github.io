import 'package:flutter/material.dart';

import '../models.dart';
import '../services/progress_service.dart';
import '../services/rewards_service.dart';
import '../ui.dart';
import 'widgets/reward_fx.dart';

/// 🪙 دووکانا دیناران: بووست، پاراستنا Streak، ئارمانجا XP، و چاوا دینار کۆم بکەی
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final r = RewardsService.instance;
  AppLanguage get n => ProgressService.instance.nativeLang;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showPendingRewards(context);
    });
  }

  Future<void> _buy(Future<String?> Function() act) async {
    final err = await act();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      await showPendingRewards(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(n, '✅ کڕین سەرکەفت', '✅ Gekauft', '✅ Purchased'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: n.direction,
      child: ListenableBuilder(
        listenable: r,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(tr(n, '🪙 دووکانا دیناران', '🪙 Dinar-Laden', '🪙 Dinar shop'))),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
            _balance(),
            const SizedBox(height: 16),
            _section(tr(n, '⚡ بووستا XP', '⚡ XP-Boost', '⚡ XP boost')),
            if (r.boostActive)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                    tr(n, 'نوکە ×${r.xpMultiplier} یا چالاکە — ${r.boostLeft.inMinutes}:${(r.boostLeft.inSeconds % 60).toString().padLeft(2, '0')} ماوە',
                        'Aktiv ×${r.xpMultiplier} — noch ${r.boostLeft.inMinutes} Min.', 'Active ×${r.xpMultiplier} — ${r.boostLeft.inMinutes} min left'),
                    style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold)),
              ),
            _item('boost_blue', tr(n, 'XP ×٢ بۆ ٥ خولەکان', 'XP ×2 für 5 Min.', 'XP ×2 for 5 min'),
                tr(n, 'هەر XPیەک دووجار دبیت', 'Jedes XP zählt doppelt', 'Every XP counts double'), RewardsService.priceBoost5,
                () => _buy(() => r.buyBoost(5, n))),
            _item('boost_gold', tr(n, 'XP ×٢ بۆ ١٠ خولەکان', 'XP ×2 für 10 Min.', 'XP ×2 for 10 min'),
                tr(n, 'دەمەکێ درێژتر بۆ وانەیێن زێدەتر', 'Mehr Zeit für mehr Lektionen', 'More time, more lessons'), RewardsService.priceBoost10,
                () => _buy(() => r.buyBoost(10, n))),
            const SizedBox(height: 10),
            _section(tr(n, '🧊 پاراستنا Streak', '🧊 Serienschutz', '🧊 Streak freeze')),
            _item(
                'freeze_cube',
                tr(n, 'قەشایا ئاگری', 'Feuer einfrieren', 'Freeze your fire'),
                tr(n, 'ئەگەر رۆژەکێ نەخوینی، ئاگرێ تە ناڤەمریت (تە ${r.freezes} ژ ${RewardsService.maxFreezes} هەنە)',
                    'Ein verpasster Tag bricht die Serie nicht (${r.freezes}/${RewardsService.maxFreezes})',
                    'Miss a day without losing your streak (${r.freezes}/${RewardsService.maxFreezes})'),
                RewardsService.priceFreeze,
                () => _buy(() => r.buyFreeze(n))),
            const SizedBox(height: 10),
            _section(tr(n, '🎯 ئارمانجا XP یا رۆژانە', '🎯 Tägliches XP-Ziel', '🎯 Daily XP goal')),
            Text(
                tr(n, 'ئارمانجەکێ هەلبژێرە — ئارمانجا مەزنتر، خەلاتا مەزنتر (×٢ / ×٣)', 'Größeres Ziel = größere Belohnung (×2 / ×3)',
                    'Bigger goal = bigger reward (×2 / ×3)'),
                style: TextStyle(color: AppColors.fg60)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in RewardsService.xpGoals)
                ChoiceChip(
                  selected: r.xpGoal == g,
                  onSelected: (_) => r.setXpGoal(r.xpGoal == g ? 0 : g),
                  label: Text('$g XP  ·  ${_goalReward(g)}', textDirection: TextDirection.ltr),
                ),
            ]),
            if (r.xpGoal > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (ProgressService.instance.todayXp / r.xpGoal).clamp(0.0, 1.0),
                minHeight: 10,
                borderRadius: BorderRadius.circular(6),
                color: AppColors.gold,
                backgroundColor: AppColors.fg10,
              ),
              const SizedBox(height: 4),
              Text('${ProgressService.instance.todayXp} / ${r.xpGoal} XP', style: TextStyle(color: AppColors.fg60)),
            ],
            const SizedBox(height: 18),
            _section(tr(n, '🎯 ئەرکێن ئەڤرۆ', '🎯 Heutige Aufgaben', "🎯 Today's tasks")),
            const QuestList(),
            if (r.log.any((l) => l.contains(' +'))) ...[
              const SizedBox(height: 18),
              _section(tr(n, '🏅 خەلاتێن تە وەرگرتین', '🏅 Deine Belohnungen', '🏅 Rewards you got')),
              for (final l in r.log.where((l) => l.contains(' +')).take(12)) _logRow(l, AppColors.green),
            ],
            if (r.log.any((l) => l.contains(' -'))) ...[
              const SizedBox(height: 14),
              _section(tr(n, '🛒 تشتێن تە کڕین', '🛒 Deine Käufe', '🛒 Your purchases')),
              for (final l in r.log.where((l) => l.contains(' -')).take(12)) _logRow(l, AppColors.red),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _logRow(String l, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(l, style: TextStyle(color: AppColors.fg70))),
        ]),
      );

  String _goalReward(int g) => switch (g) {
        >= 750 => '50🪙 + ×3',
        >= 500 => '35🪙 + ×2',
        >= 400 => '25🪙 + ×2',
        _ => '15🪙',
      };

  Widget _balance() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF3A2A06), Color(0xFF1A1206)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Row(children: [
          Image.asset('assets/img/fx/chest.webp', width: 96, height: 96),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(n, 'دینارێن تە', 'Deine Dinar', 'Your dinars'), style: const TextStyle(color: Colors.white70)),
              Row(children: [
                Image.asset('assets/img/fx/coin_s.webp', width: 34, height: 34),
                const SizedBox(width: 6),
                Text('${r.dinar}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFFFFD54F))),
              ]),
              Row(children: [
                Image.asset('assets/img/fx/freeze_cube.webp', width: 20, height: 20),
                Text(' ${r.freezes}   ', style: const TextStyle(color: Colors.white70)),
                if (r.boostActive) Text('⚡×${r.xpMultiplier}', style: const TextStyle(color: Color(0xFF7FD3FF))),
              ]),
            ]),
          ),
        ]),
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      );

  Widget _item(String img, String title, String sub, int price, VoidCallback onBuy) {
    final can = r.dinar >= price;
    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Image.asset('assets/img/fx/$img.webp', width: 58, height: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(sub, style: TextStyle(fontSize: 12, color: AppColors.fg60)),
            ]),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: can ? AppColors.gold : AppColors.fg12,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: onBuy,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/img/fx/coin_s.webp', width: 18, height: 18),
              const SizedBox(width: 4),
              Text('$price', style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
      ),
    );
  }
}
