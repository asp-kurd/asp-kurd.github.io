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
        if (iosNonSafari)
          _step(0, 'باشترە ب Safari ڤەکەی', 'لینکێ کۆپی بکە و د Safari دا ڤەکە', _chip('Safari', Icons.explore_rounded)),
        _step(1, 'ل دوگمەیا «Share» بدە', 'ل خوارێ یان ل سەرێ Safari — چارگۆشەکا ب تیرێ', _chip('Share', Icons.ios_share_rounded)),
        _step(2, '«Add to Home Screen» هەلبژێرە', 'کەمەکێ ب خوارێ بچە هەتا دبینی', _chip('Add to Home Screen', Icons.add_box_outlined)),
        _step(3, 'ل «Add» بدە', 'ل سەری ل لایێ راستێ', _chip('Add', Icons.check_rounded)),
        _step(4, 'ئەپا ASP ژ سەر شاشێ ڤەکە', 'و ژ وێرێ دەست پێبکە — هەمی تشت ل وێرێ دمینیت', ClipRRect(
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
            // ⬇️ تیرا ب لڤین بۆ دوگمەیا Share ل خوارێ Safari
            if (ios && !inAppBrowser && !iosNonSafari)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: c,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, 10 * sin(c.value * 2 * pi)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(14)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.ios_share_rounded, color: Colors.white),
                          SizedBox(width: 6),
                          Text('ل ڤێرێ ل خوارێ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      const Icon(Icons.keyboard_double_arrow_down_rounded, size: 40, color: AppColors.blue),
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
