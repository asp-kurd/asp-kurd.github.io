import 'dart:math';

import 'package:flutter/material.dart';

import '../services/sfx.dart';
import '../ui.dart';
import 'widgets/league_art.dart';
import 'widgets/mascot.dart';

/// 🏆 پێشبینینا لیگا هەفتانە (تنێ بۆ ئەدمینی — هێشتا بۆ فێرخوازان نینە)
/// مەدال، نیشانێن باژێران، سەکۆ، چوارچووڤە، لیستا گرووپێ و ئاهەنگا شەمبیێ — هەمی ب کۆدی.
class LeaguePreviewScreen extends StatelessWidget {
  const LeaguePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = MascotChar.forUser();
    final cast = MascotChar.builtIn;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('🏆 پێشبینینا لیگێ')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: const Text('👀 ئەڤە تنێ نموونەیە بۆ تە. هێشتا بۆ فێرخوازان ڤەنەبوویە.', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          BigButton(
            label: 'ئاهەنگا شەمبیێ ببینە 🎉',
            color: AppColors.gold,
            onPressed: () => Navigator.push(context, PageRouteBuilder(opaque: false, pageBuilder: (_, __, ___) => const LeagueCeremony())),
          ),
          const SizedBox(height: 22),
          _h('🥇 مەدال'),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Medal(kind: MedalKind.silver, size: 82),
            Medal(kind: MedalKind.gold, size: 104),
            Medal(kind: MedalKind.bronze, size: 82),
          ]),
          const SizedBox(height: 22),
          _h('🗺️ ئاستێن لیگێ: ڕێکا ئەلمانیا'),
          Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 14, children: [
            for (var k = 0; k < leagueLevels.length; k++)
              Column(mainAxisSize: MainAxisSize.min, children: [
                LeagueBadge(level: k, size: 84),
                const SizedBox(height: 4),
                Text('${k + 1}. ${leagueLevels[k].ku}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(leagueLevels[k].de, style: TextStyle(color: AppColors.fg54, fontSize: 12)),
              ]),
            Column(mainAxisSize: MainAxisSize.min, children: [
              const LeagueBadge(level: 5, size: 84, locked: true),
              const SizedBox(height: 4),
              Text('هێشتا گرتی', style: TextStyle(color: AppColors.fg54, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 22),
          _h('🏅 سەکۆ'),
          Podium(chars: [cast[0], cast[12], cast[1]], names: [cast[0].name, cast[12].name, cast[1].name]),
          const SizedBox(height: 22),
          _h('🖼️ چوارچووڤێن پرۆفایلێ (ب ئاستی)'),
          Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
            for (var k = 0; k < leagueLevels.length; k++)
              AvatarFrame(level: k, size: 64, child: Image(image: me.img('base'), fit: BoxFit.cover)),
          ]),
          const SizedBox(height: 22),
          _h('📋 گرووپا هەفتێ (نموونە)'),
          const _Board(),
          const SizedBox(height: 26),
          _h('👥 هەڤال و تیم (پلان)'),
          const _FriendsPlan(),
        ]),
      ),
    );
  }

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      );
}

/// 📋 لیستا گرووپێ: ٣ یێن ئێکێ ⬆️ · ٢ یێن دوماهیێ ⬇️
class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) {
    final cast = MascotChar.builtIn;
    final rnd = Random(7);
    var xp = 980;
    final rows = [
      for (var k = 0; k < 10; k++) (cast[k % cast.length], xp -= 40 + rnd.nextInt(90)),
    ];
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const LeagueBadge(level: 2, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('لیگا ئەستەنبوڵێ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text('⏳ ٢ ڕۆژ و ٥ دەمژمێر مان', style: TextStyle(color: AppColors.fg60, fontSize: 12)),
              ]),
            ),
          ]),
        ),
        for (var k = 0; k < rows.length; k++) ...[
          if (k == 3) _zone('⬆️ ٣ یێن ئێکێ دچنە ڤیەنا', AppColors.green),
          if (k == 8) _zone('⬇️ ٢ یێن دوماهیێ دزڤڕنە هەولێرێ', AppColors.red),
          Container(
            color: k == 4 ? AppColors.accent.withValues(alpha: 0.12) : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              SizedBox(
                width: 30,
                child: Text(k < 3 ? ['🥇', '🥈', '🥉'][k] : '${k + 1}',
                    textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              const SizedBox(width: 8),
              AvatarFrame(level: 2, size: 42, child: Image(image: rows[k].$1.img('base'), fit: BoxFit.cover)),
              const SizedBox(width: 10),
              Expanded(child: Text(k == 4 ? '${rows[k].$1.name} (تو)' : rows[k].$1.name, style: const TextStyle(fontWeight: FontWeight.bold))),
              Text('${rows[k].$2} XP', textDirection: TextDirection.ltr, style: TextStyle(color: AppColors.goldText, fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _zone(String t, Color c) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: c.withValues(alpha: 0.12),
        child: Text(t, textAlign: TextAlign.center, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

/// 👥 پلانا هەڤالان و تیمان: کۆدا ڤەخواندنێ، لیستا هەڤالان یا هەفتێ، تیمەکا ٣–٥ کەسی کو XP پێکڤە کۆم دکەن
class _FriendsPlan extends StatelessWidget {
  const _FriendsPlan();

  @override
  Widget build(BuildContext context) {
    final cast = MascotChar.builtIn;
    final friends = [(cast[0], 640, 9), (cast[12], 520, 14), (cast[3], 410, 4), (cast[6], 180, 2)];
    final team = [(cast[0], 640), (cast[12], 520), (cast[3], 410), (cast[6], 180)];
    final teamXp = team.fold<int>(0, (a, b) => a + b.$2);
    const goal = 2500;
    Widget card(Widget child) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
          child: child,
        );
    Widget sub(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        );
    return Column(children: [
      // ١. ڤەخواندن
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sub('١. هەڤالەکی زێدە بکە'),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('POYA-4821', textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3)),
            ),
          ),
          const SizedBox(width: 10),
          Column(children: [
            _pill('🔗 لینک بنێرە', AppColors.green),
            const SizedBox(height: 6),
            _pill('📷 QR', AppColors.blue),
          ]),
        ]),
        const SizedBox(height: 8),
        Text('هەر فێرخوازەک کۆدەکا خۆ یا تایبەت هەیە. هەڤالێ تە کۆدێ دنڤیسیت یان لینکێ ڤەدکەت ➔ هەردوو دبنە هەڤال.',
            style: TextStyle(color: AppColors.fg60, fontSize: 13)),
      ])),
      // ٢. لیستا هەڤالان
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sub('٢. هەڤالێن من — ڤێ هەفتێ'),
        for (var k = 0; k < friends.length; k++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 26, child: Text('${k + 1}', style: const TextStyle(fontWeight: FontWeight.w900))),
              AvatarFrame(level: [3, 2, 1, 0][k], size: 40, child: Image(image: friends[k].$1.img('base'), fit: BoxFit.cover)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k == 1 ? '${friends[k].$1.name} (تو)' : friends[k].$1.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('🔥 ${friends[k].$3} ڕۆژ', style: TextStyle(color: AppColors.fg54, fontSize: 12)),
                ]),
              ),
              Text('${friends[k].$2} XP', textDirection: TextDirection.ltr, style: TextStyle(color: AppColors.goldText, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (k != 1) _pill('👋', AppColors.orange),
            ]),
          ),
        const SizedBox(height: 6),
        Text('👋 = هاندان بنێرە ("وەرە، ئەڤرۆ دەرسا خۆ بخوینە!")', style: TextStyle(color: AppColors.fg60, fontSize: 13)),
      ])),
      // ٣. تیم
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sub('٣. تیما من: 🦅 شێرێن دهۆکێ'),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final m in team)
            Column(children: [
              AvatarFrame(level: 2, size: 48, child: Image(image: m.$1.img('base'), fit: BoxFit.cover)),
              const SizedBox(height: 4),
              Text(m.$1.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('+${m.$2}', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 11, color: AppColors.goldText)),
            ]),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: teamXp / goal,
            minHeight: 16,
            backgroundColor: AppColors.fg54.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(AppColors.gold),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('$teamXp / $goal XP', textDirection: TextDirection.ltr, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Text('🎁 سندوقا تیمێ'),
        ]),
        const SizedBox(height: 8),
        Text('تیم ٣–٥ کەسن. XP یا هەمییان پێکڤە کۆم دبیت. ئەگەر تیم گەهشتە ئارمانجا هەفتێ ➔ هەر ئێک سندوقەکێ وەردگریت.',
            style: TextStyle(color: AppColors.fg60, fontSize: 13)),
      ])),
      // ٤. پلان
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sub('📝 پلان چاوا کار دکەت'),
        for (final t in const [
          '🏆 لیگ: گرووپێن ١٠–٣٠ کەسی (ل دویڤ ژمارا فێرخوازان)، هەر دووشەمبی ژ نوو دەست پێ دکەت.',
          '⬆️⬇️ ٣ یێن ئێکێ دچنە ئاستێ پاشتر، ٢ یێن دوماهیێ دزڤڕن. ئەوێن ٠ XP ناکەڤنە گرووپێ.',
          '👥 هەڤال: ب کۆد/لینک/QR. لیستا هەڤالان ب XP یا هەفتێ، و هاندان (👋).',
          '🦅 تیم: ٣–٥ هەڤال، ئارمانجا هەفتێ پێکڤە، خەلاتێ پێکڤە. کەس ناهێتە دەرێخستن ژبەر کێم خواندنێ.',
          '🔒 ناڤ تنێ ناڤێ پرۆفایلێ و کاراکتەرە — نە ژمارا تەلەفۆنێ نە ئیمەیل.',
          '⚙️ بۆ ڤەکرنا ڕاستەقینە: خشتەیێن نوو ل Supabase (پێدڤی ب ڕەزامەندیا تە یە).',
        ])
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontSize: 14, height: 1.5))),
      ])),
    ]);
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

/// 🎉 ئاهەنگا شەمبیێ: تاری ➔ ڕۆناهی ➔ سەکۆ ➔ مەدال دکەڤیت ➔ کۆنفێتی ➔ کوین ➔ ئاستێ نوو
class LeagueCeremony extends StatefulWidget {
  const LeagueCeremony({super.key});

  @override
  State<LeagueCeremony> createState() => _LeagueCeremonyState();
}

class _LeagueCeremonyState extends State<LeagueCeremony> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200))..forward();
  bool _sfx1 = false, _sfx2 = false;

  @override
  void initState() {
    super.initState();
    c.addListener(() {
      if (!_sfx1 && c.value > 0.32) {
        _sfx1 = true;
        Sfx.star();
      }
      if (!_sfx2 && c.value > 0.62) {
        _sfx2 = true;
        Sfx.correct();
      }
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  double _seg(double a, double b) => ((c.value - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final me = MascotChar.forUser();
    final cast = MascotChar.builtIn;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: () => c.value > 0.95 ? Navigator.pop(context) : null,
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) {
            final dark = _seg(0, 0.08);
            final spot = _seg(0.06, 0.2);
            final podium = Curves.easeOutBack.transform(_seg(0.12, 0.32));
            final medal = Curves.bounceOut.transform(_seg(0.3, 0.5));
            final coins = _seg(0.55, 0.75);
            final level = Curves.easeOutBack.transform(_seg(0.72, 0.9));
            return Material(
              color: Colors.black.withValues(alpha: 0.92 * dark),
              child: Stack(children: [
                // 🔦 ڕۆناهیا ژ سەری
                Positioned.fill(
                  child: Opacity(
                    opacity: spot,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(center: Alignment(0, -1.1), radius: 1.2, colors: [Color(0x55FFF3B0), Color(0x00000000)]),
                      ),
                    ),
                  ),
                ),
                if (c.value > 0.3) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_seg(0.3, 1))))),
                SafeArea(
                  child: Column(children: [
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: spot,
                      child: const Text('🏆 ئەنجامێن هەفتێ', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 10),
                    // 🥇 مەدال دکەڤیت
                    SizedBox(
                      height: 150,
                      child: Transform.translate(
                        offset: Offset(0, -220 * (1 - medal)),
                        child: Opacity(opacity: medal > 0 ? 1 : 0, child: const Medal(kind: MedalKind.gold, size: 100)),
                      ),
                    ),
                    Opacity(
                      opacity: _seg(0.5, 0.6),
                      child: Text('${me.name} — جهێ ئێکێ! 🎉',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 8),
                    // 🪙 کوین
                    Opacity(
                      opacity: coins > 0 ? 1 : 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0x33FFC107), borderRadius: BorderRadius.circular(20)),
                        child: Text('+${(100 * coins).round()} 🪙',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 22, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const Spacer(),
                    // ⬆️ ئاستێ نوو
                    Transform.scale(
                      scale: level,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const LeagueBadge(level: 2, size: 52),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 30),
                        ),
                        const LeagueBadge(level: 3, size: 70),
                        const SizedBox(width: 10),
                        Text('بۆ ${leagueLevels[3].ku}!', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    // 🥇🥈🥉 سەکۆ
                    Transform.translate(
                      offset: Offset(0, 320 * (1 - podium)),
                      child: Podium(chars: [me, cast[12], cast[1]], names: [me.name, cast[12].name, cast[1].name]),
                    ),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: _seg(0.92, 1),
                      child: const Text('دەست ل هەر جهەکی بدە', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                    const SizedBox(height: 10),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);
  static final _rnd = Random(3);
  static final _bits = [
    for (var i = 0; i < 90; i++)
      (_rnd.nextDouble(), _rnd.nextDouble() * 0.4, 0.6 + _rnd.nextDouble() * 0.8, _rnd.nextDouble() * 6, _rnd.nextInt(5)),
  ];
  static const _colors = [Color(0xFFFFC107), Color(0xFF58CC02), Color(0xFF1CB0F6), Color(0xFFFF4B4B), Color(0xFFCE82FF)];

  @override
  void paint(Canvas canvas, Size s) {
    for (final (x, delay, speed, rot, ci) in _bits) {
      final tt = ((t - delay) * speed).clamp(0.0, 1.0);
      if (tt <= 0) continue;
      final y = -20 + (s.height + 40) * tt;
      final dx = sin(tt * 8 + rot) * 18;
      canvas.save();
      canvas.translate(x * s.width + dx, y);
      canvas.rotate(rot + tt * 10);
      canvas.drawRect(const Rect.fromLTWH(-4, -7, 8, 14), Paint()..color = _colors[ci].withValues(alpha: 1 - tt * 0.3));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}
