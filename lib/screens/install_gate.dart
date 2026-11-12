import 'dart:math';

import 'package:flutter/material.dart';

import '../services/push_stub.dart' if (dart.library.js_interop) '../services/push_web.dart';
import '../ui.dart';

/// 📲 بەری هەر تشتەکی: ئەپ دڤێت ل سەر شاشێ (Home Screen) بیت.
/// iPhone: Safari ➔ Share ➔ Add to Home Screen · Android: دامەزراندن
/// پشتی ڤەکرنا ئەپێ ژ سەر شاشێ، هەمی تشت ژ وێرێ بەردەوام دبیت.
bool get installGateNeeded => (platformKind == 'ios' || platformKind == 'android') && !isStandalone;

class InstallGateScreen extends StatefulWidget {
  const InstallGateScreen({super.key});

  @override
  State<InstallGateScreen> createState() => _InstallGateScreenState();
}

class _InstallGateScreenState extends State<InstallGateScreen> with SingleTickerProviderStateMixin {
  bool coach = false; // 🧭 رێنمایا ل سەر هەمی شاشێ
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  bool installed = false;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Widget _step(int n, String title, String sub, Widget icon) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.blue,
            child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (sub.isNotEmpty) Text(sub, style: TextStyle(color: AppColors.fg60, fontSize: 13, height: 1.5)),
            ]),
          ),
          const SizedBox(width: 8),
          icon,
        ]),
      );

  Widget _chip(String t, IconData i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 20, color: AppColors.blue),
          const SizedBox(width: 4),
          Text(t, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );

  List<Widget> _iosSteps() => [
        // 🎬 نیشاندانەکا کورت: چاوا ل سەر شاشێ دانی
        const Center(child: _IosDemo()),
        const SizedBox(height: 16),
        if (!iosNonSafari) ...[
          BigButton(
            label: '📲 دانانا ل سەر شاشێ',
            onPressed: () => setState(() => coach = true),
          ),
          const SizedBox(height: 8),
          Text('Apple رێ نادەت ماڵپەڕ ب خۆ ڤێ بکەت — بەلێ ئەم دێ گاڤ ب گاڤ نیشا تە دەین 👇',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg60, fontSize: 13)),
          const SizedBox(height: 18),
          Text('یان ب دەستێ خۆ:', style: TextStyle(color: AppColors.fg54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
        ],
        if (iosNonSafari)
          _step(0, 'باشترە ب Safari ڤەکەی', 'لینکێ کۆپی بکە و د Safari دا ڤەکە', _chip('Safari', Icons.explore_rounded)),
        _step(1, 'ل سێ خالان «⋯» بدە', 'ل خوارێ Safari، ل لایێ راستێ یێ ناڤنیشانێ (asp-poya.com). ئەگەر دوگمەیا Share دیار بیت، دشێی راستەوخۆ وێ بکەی.',
            _chip('⋯', Icons.more_horiz_rounded)),
        _step(2, '«Share» هەلبژێرە', 'د لیستا ڤەبووی دا', _chip('Share', Icons.ios_share_rounded)),
        _step(3, '«Add to Home Screen» هەلبژێرە', 'ب خوارێ بچە؛ ئەگەر نەدیت، ل «View More» / «More» بدە',
            _chip('Add to Home Screen', Icons.add_box_outlined)),
        _step(4, '«Open as Web App» ڤەکری بهێلە و ل «Add» بدە', 'ل سەری ل لایێ راستێ', _chip('Add', Icons.check_rounded)),
        _step(5, 'ئەپا ASP ژ سەر شاشێ ڤەکە', 'و ژ وێرێ دەست پێبکە — هەمی تشت ل وێرێ دمینیت', ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/brand/logo.png', width: 34, height: 34),
        )),
      ];

  List<Widget> _androidSteps() => [
        if (canPromptInstall)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: BigButton(
              label: '📲 ئەپێ دامەزرینە',
              onPressed: () async {
                final ok = await promptInstall();
                if (mounted) setState(() => installed = ok);
              },
            ),
          ),
        _step(1, 'ل ⋮ بدە', 'ل سەری ل لایێ راستێ یێ Chrome', _chip('⋮', Icons.more_vert_rounded)),
        _step(2, '«Install app» یان «Add to Home screen»', '', _chip('Install', Icons.install_mobile_rounded)),
        _step(3, 'ئەپا ASP ژ سەر شاشێ ڤەکە', 'و ژ وێرێ دەست پێبکە', ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/brand/logo.png', width: 34, height: 34),
        )),
      ];

  @override
  Widget build(BuildContext context) {
    final ios = platformKind == 'ios';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Stack(children: [
            ListView(padding: const EdgeInsets.fromLTRB(22, 20, 22, 120), children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/brand/logo.png', width: 96, height: 96),
                ),
              ),
              const SizedBox(height: 14),
              const Text('📲 پێشی ASP ل سەر شاشا مۆبایلێ دانە',
                  textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Sarchia', fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  'وەسا ئەپ وەکی ئەپەکا راستەقینە کار دکەت: ئاگەهداری دهێن، دەنگ باشترن، و پێشکەفتنا تە پاراستی دمینیت.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.fg70, fontSize: 15, height: 1.6)),
              const SizedBox(height: 20),
              if (inAppBrowser) ...[
                _step(1, 'ل ⋯ یان ⋮ بدە', 'ل سەری یان ل خوارێ یێ ڤێ پەڕێ', _chip('⋯', Icons.more_horiz_rounded)),
                _step(2, ios ? '«Open in Safari» / «Open in browser»' : '«Open in Chrome» / «Open in browser»', 'ئەپ دێ د براوزەری دا ڤەبیت',
                    _chip(ios ? 'Safari' : 'Chrome', Icons.open_in_browser_rounded)),
                _step(3, 'پاشان ئەپێ ل سەر شاشێ دانە', 'دێ رێنمایان ل وێرێ بینی', _chip('Home', Icons.home_rounded)),
                OutlinedButton.icon(
                  onPressed: () async {
                    await copyText(Uri.base.origin);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ لینک هاتە کۆپیکرن — د Safari/Chrome دا ڤەکە')));
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('کۆپیکرنا لینکێ'),
                ),
              ] else if (installed)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
                  child: const Text('✅ ئەپ هاتە دامەزراندن! نوکە ئەپا ASP ژ سەر شاشێ ڤەکە.',
                      textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                )
              else
                ...(ios ? _iosSteps() : _androidSteps()),
            ]),
            // ⬇️ تیرا ب لڤین بۆ «⋯» ل خوارێ Safari (لایێ راستێ)
            if (ios && !inAppBrowser && !iosNonSafari && !coach)
              Positioned(bottom: 6, right: 14, child: _Arrow(c: c, label: '⋯ ل ڤێرێ')),
            // 🧭 رێنمایا مەزن (پشتی لێدانا دوگمێ کەسک)
            if (coach)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => coach = false),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.86),
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 0),
                    child: Column(children: [
                      const Text('٤ گاڤێن ب ساناهی 👇',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      const _IosDemo(),
                      const SizedBox(height: 14),
                      for (final (n, t) in const [
                        ('١', 'ل «⋯» ل خوارێ ل لایێ راستێ بدە'),
                        ('٢', '«Share» هەلبژێرە'),
                        ('٣', '«Add to Home Screen» (یان پێشی «View More»)'),
                        ('٤', '«Open as Web App» ✅ ➔ «Add»'),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            CircleAvatar(radius: 13, backgroundColor: AppColors.blue,
                                child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 10),
                            Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 15))),
                          ]),
                        ),
                      const Spacer(),
                      Align(alignment: Alignment.bottomRight, child: _Arrow(c: c, label: 'ئێکەم: ⋯ ل ڤێرێ')),
                      const SizedBox(height: 6),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// iPhone: Google/Facebook ل پەنجەرەکا جودا تەمام بوو ➔ تنێ «Done» بکە
class OAuthDoneScreen extends StatelessWidget {
  const OAuthDoneScreen({super.key});
  @override
  Widget build(BuildContext context) => const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('✅', style: TextStyle(fontSize: 70)),
                SizedBox(height: 14),
                Text('تەمام! تو چوویە ژوور', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text('ل «Done» یان «تەمام» ل سەری بدە دا بزڤڕییە ئەپا ASP.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.6)),
              ]),
            ),
          ),
        ),
      );
}


/// 🎬 نیشاندانا ب لڤین (٥ چرکە): Share ➔ Add to Home Screen ➔ Add ➔ ئایکۆنا ASP ل سەر شاشێ
class _IosDemo extends StatefulWidget {
  const _IosDemo();
  @override
  State<_IosDemo> createState() => _IosDemoState();
}

class _IosDemoState extends State<_IosDemo> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6000))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  Widget _row(IconData i, String t, {bool hi = false}) => Container(
        height: 30,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hi ? const Color(0xFF1CB0F6).withValues(alpha: 0.35) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
            child: Text(t,
                textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Icon(i, size: 15, color: Colors.white),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final t = c.value;
        final tap1 = _seg(t, 0.08, 0.18); // لێدان ل Share
        final sheet = Curves.easeOutCubic.transform(_seg(t, 0.30, 0.40));
        final tap2 = _seg(t, 0.40, 0.50); // Add to Home Screen
        final addScr = _seg(t, 0.50, 0.58);
        final tap3 = _seg(t, 0.62, 0.70); // Add
        final home = Curves.easeOutBack.transform(_seg(t, 0.72, 0.84));
        Widget finger(double k) => k <= 0 || k >= 1
            ? const SizedBox()
            : Opacity(
                opacity: sin(k * pi),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.35),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              );
        return Container(
          width: 210,
          height: 300,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF3A3A3C), width: 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(children: [
              // 📄 پەڕا ASP د Safari دا / یان شاشا مۆبایلێ
              Positioned.fill(
                child: home > 0
                    ? Container(
                        color: const Color(0xFF1D3557),
                        padding: const EdgeInsets.all(14),
                        child: Wrap(spacing: 14, runSpacing: 14, children: [
                          for (final col in const [Color(0xFF34C759), Color(0xFFFF9500), Color(0xFF5856D6)])
                            Container(width: 38, height: 38, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(10))),
                          Transform.scale(
                            scale: home,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset('assets/brand/logo.png', width: 38, height: 38),
                              ),
                              const Text('ASP', style: TextStyle(color: Colors.white, fontSize: 9)),
                            ]),
                          ),
                        ]),
                      )
                    : Container(
                        color: const Color(0xFF131F24),
                        child: Column(children: [
                          const SizedBox(height: 30),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset('assets/brand/logo.png', width: 56, height: 56),
                          ),
                          const SizedBox(height: 8),
                          const Text('asp-poya.com', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        ]),
                      ),
              ),
              // ⬇️ نیشانا Safari ل خوارێ
              if (home <= 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 34,
                    color: const Color(0xFF1C1C1E),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(children: [
                      const Icon(Icons.chevron_left, color: Colors.white38, size: 18),
                      Expanded(
                        child: Container(
                          height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(11)),
                          child: const Text('asp-poya.com', style: TextStyle(color: Colors.white70, fontSize: 9)),
                        ),
                      ),
                      Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                        const Icon(Icons.more_horiz_rounded, color: Color(0xFF0A84FF), size: 20),
                        finger(tap1),
                      ]),
                    ]),
                  ),
                ),
              // ⋯ لیستا بچووک ➔ «Share»
              if (tap1 >= 1 && t < 0.30 && home <= 0)
                Positioned(
                  right: 6,
                  bottom: 38,
                  child: Container(
                    width: 120,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(10)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Stack(alignment: Alignment.center, children: [
                        _row(Icons.ios_share_rounded, 'Share', hi: t > 0.22),
                        finger(_seg(t, 0.20, 0.29)),
                      ]),
                      _row(Icons.bookmark_border_rounded, 'Add Bookmark'),
                    ]),
                  ),
                ),
              // 📋 پەنجەرا Share
              if (sheet > 0 && t >= 0.30 && addScr < 1 && home <= 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -170 * (1 - sheet),
                  child: Container(
                    height: 170,
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Column(children: [
                      _row(Icons.copy_rounded, 'Copy'),
                      _row(Icons.bookmark_border_rounded, 'Add Bookmark'),
                      Stack(alignment: Alignment.center, children: [
                        _row(Icons.add_box_outlined, 'Add to Home Screen', hi: tap2 > 0),
                        finger(tap2),
                      ]),
                      _row(Icons.search_rounded, 'Find on Page'),
                    ]),
                  ),
                ),
              // ➕ شاشا «Add»
              if (addScr > 0 && home <= 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: addScr,
                    child: Container(
                      color: const Color(0xFF1C1C1E),
                      padding: const EdgeInsets.all(10),
                      child: Column(children: [
                        Row(children: [
                          const Text('Cancel', style: TextStyle(color: Color(0xFF0A84FF), fontSize: 11)),
                          const Spacer(),
                          Stack(alignment: Alignment.center, children: [
                            const Text('Add', style: TextStyle(color: Color(0xFF0A84FF), fontSize: 12, fontWeight: FontWeight.bold)),
                            finger(tap3),
                          ]),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset('assets/brand/logo.png', width: 36, height: 36),
                          ),
                          const SizedBox(width: 8),
                          const Text('ASP', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          const Expanded(child: Text('Open as Web App', style: TextStyle(color: Colors.white, fontSize: 10))),
                          Container(
                            width: 28,
                            height: 16,
                            decoration: BoxDecoration(color: const Color(0xFF34C759), borderRadius: BorderRadius.circular(8)),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.all(2),
                            child: const CircleAvatar(radius: 6, backgroundColor: Colors.white),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

class _Arrow extends StatelessWidget {
  final AnimationController c;
  final String label;
  const _Arrow({required this.c, required this.label});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, 10 * sin(c.value * 2 * pi)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.more_horiz_rounded, color: Colors.white),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.keyboard_double_arrow_down_rounded, size: 44, color: AppColors.blue),
            ),
          ]),
        ),
      );
}
