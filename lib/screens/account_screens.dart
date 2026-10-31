import 'package:flutter/material.dart';

import '../config.dart';
import '../services/backend.dart';
import '../services/progress_service.dart';
import '../services/push_stub.dart' if (dart.library.js_interop) '../services/push_web.dart';
import '../ui.dart';

// ───────────────────────── 📝 تۆمارکرن ─────────────────────────

/// دەمێ کەسەک بۆ جارا ئێکێ ئەپی ڤەدکەت: ناڤ + تەمەن + جهێ ئاکنجیبوونێ
class RegisterScreen extends StatefulWidget {
  final Widget next;
  const RegisterScreen({super.key, required this.next});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final age = TextEditingController();
  final city = TextEditingController();
  bool busy = false;
  String? error;
  String? gender; // 'm' / 'f'

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (name.text.trim().length < 2) {
      setState(() => error = 'تکایە ناڤێ خۆ بنڤیسە');
      return;
    }
    if (gender == null) {
      setState(() => error = 'تکایە ڕەگەزێ خۆ هەلبژێرە: نێر یان مێ');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final p = ProgressService.instance;
    final err = await Backend.instance.register(
      name: name.text,
      age: int.tryParse(age.text.trim()),
      city: city.text,
      gender: gender,
      native: p.nativeLang.code,
      target: p.targetLang.code,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        busy = false;
        error = 'پەیوەندی سەرنەکەفت. ئینتەرنێتێ پشکنە و دیسا تاقی بکە.\n($err)';
      });
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SetupScreen(next: widget.next)));
  }

  Widget _genderBtn(String v, String emoji, String label) {
    final sel = gender == v;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          gender = v;
          if (error != null && error!.contains('ڕەگەز')) error = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: sel ? AppColors.blue.withValues(alpha: 0.2) : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? AppColors.blue : Colors.white24, width: sel ? 3 : 1.5),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.white70)),
          ]),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 10),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset('assets/brand/logo.png', width: 110, height: 110),
                ),
              ),
              const SizedBox(height: 18),
              const Text('ب خێر بێی بۆ ASP! 👋',
                  textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Sarchia', fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('بەری دەستپێکرنێ، خۆ بدە ناسین', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 26),
              TextField(controller: name, textInputAction: TextInputAction.next, decoration: _dec('ناڤێ تە', Icons.person_rounded)),
              const SizedBox(height: 14),
              Row(children: [
                _genderBtn('m', '👨', 'نێر'),
                const SizedBox(width: 12),
                _genderBtn('f', '👩', 'مێ'),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: age,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: _dec('تەمەن', Icons.cake_rounded),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: city,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _go(),
                decoration: _dec('جهێ ئاکنجیبوونێ (باژێڕ)', Icons.location_on_rounded),
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Text(error!, style: const TextStyle(color: AppColors.red)),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => widget.next)),
                  child: const Text('پاشان — بێ هەژمار بەردەوام بە'),
                ),
              ],
              const SizedBox(height: 22),
              busy
                  ? const Center(child: CircularProgressIndicator())
                  : BigButton(label: 'دەستپێبکە', icon: Icons.arrow_back_rounded, onPressed: _go),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 📬 نامە ─────────────────────────

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final b = Backend.instance;

  @override
  void initState() {
    super.initState();
    b.loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('📬 نامەیێن من')),
        body: ListenableBuilder(
          listenable: b,
          builder: (_, __) {
            if (b.messages.isEmpty) {
              return const Center(child: Text('چ نامە نینن', style: TextStyle(color: Colors.white54)));
            }
            return RefreshIndicator(
              onRefresh: b.loadMessages,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                if (pushSupported && pushPermission != 'granted') const NotifyCard(),
                for (final m in b.messages) _tile(m),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _tile(AppMessage m) {
    final icon = switch (m.kind) { 'streak' => '🔥', 'system' => '⚙️', _ => '✉️' };
    return Card(
      color: m.read ? AppColors.card : const Color(0xFF1B3A4B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: m.read ? Colors.white12 : AppColors.gold, width: m.read ? 1 : 2),
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: Text(icon, style: const TextStyle(fontSize: 26)),
        title: Text(m.title, style: TextStyle(fontWeight: m.read ? FontWeight.normal : FontWeight.bold)),
        subtitle: Text('ژ ASP · ${_ago(m.created)}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
        onExpansionChanged: (open) {
          if (open) b.markRead(m);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(m.body, style: const TextStyle(fontSize: 16, height: 1.6)),
            ),
          ),
        ],
      ),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'نوکە';
  if (d.inMinutes < 60) return '${d.inMinutes} خولەک بەری نوکە';
  if (d.inHours < 24) return '${d.inHours} دەمژمێر بەری نوکە';
  if (d.inDays < 30) return '${d.inDays} رۆژ بەری نوکە';
  return '${t.year}/${t.month}/${t.day}';
}

String agoKu(DateTime t) => _ago(t);

/// 🔔 کارتا ڤەکرنا ئاگەهداریان (iPhone: تنێ ژ Home Screen)
class NotifyCard extends StatefulWidget {
  const NotifyCard({super.key});

  @override
  State<NotifyCard> createState() => _NotifyCardState();
}

class _NotifyCardState extends State<NotifyCard> {
  bool busy = false;
  String? msg;

  @override
  Widget build(BuildContext context) {
    if (!Backend.instance.registered) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF1CB0F6)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        const Text('🔔', style: TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ئاگەهداریان ڤەکە', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
            Text(msg ?? 'دا نامە و بیرئینانا Streak بگەهنە تە', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        busy
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                onPressed: () async {
                  setState(() => busy = true);
                  try {
                    final sub = await subscribePush(AppConfig.vapidPublicKey);
                    if (sub != null) {
                      await Backend.instance.savePushSubscription(sub);
                      msg = '✅ ڤەبوو!';
                    } else {
                      msg = 'ل iPhone: ئێکەم ئەپی بکە سەر Home Screen، پاشان ژ وێرێ ڤەکە.';
                    }
                  } catch (e) {
                    msg = 'سەرنەکەفت: $e';
                  }
                  if (mounted) setState(() => busy = false);
                },
                child: const Text('ڤەکە'),
              ),
      ]),
    );
  }
}

// ───────────────────────── 📲🔔 ئامادەکرنا مۆبایلێ ─────────────────────────

/// پشتی تۆمارکرنێ: (١) ئەپی بکە سەر Home Screen و (٢) ئاگەهداریان ڤەکە.
/// iPhone: ئاگەهداری تنێ کار دکەن پشتی ئەپ ل سەر Home Screen بیت، لەوما دامەزراندن ل پێشیێ یە.
class SetupScreen extends StatefulWidget {
  final Widget next;
  const SetupScreen({super.key, required this.next});

  /// ئەڤ شاشە پێدڤییە؟ (بۆ نموونە iPhone پشتی ئەپ ژ Home Screen هاتییە ڤەکرن)
  static bool needed() {
    final b = Backend.instance;
    if (!b.enabled || !b.registered || b.isAdmin) return false;
    if (!pushSupported) return !isStandalone && platformKind != 'other' && !b.flag('asked_install');
    return pushPermission == 'default' && (isStandalone || platformKind == 'android') && !b.flag('asked_push_${isStandalone ? 'app' : 'web'}');
  }

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late int step; // 0 = دامەزراندن، 1 = ئاگەهداری
  bool busy = false;
  String? note;

  bool get _ios => platformKind == 'ios';
  bool get _pushReady => pushSupported && pushPermission != 'granted';

  @override
  void initState() {
    super.initState();
    // Android: ئاگەهداری دبن ل وێبگەڕێ ژی، ئەم ئێکەم ئاگەهداریان دپرسین (وەکی خواستا تە)
    // iPhone: ئێکەم دامەزراندن، چونکی بێی وێ ئاگەهداری کار ناکەن
    if (isStandalone) {
      step = 1;
    } else if (_ios) {
      step = 0;
    } else {
      step = _pushReady ? 1 : 0;
    }
  }

  void _done() {
    Backend.instance.setFlag('asked_install');
    Backend.instance.setFlag('asked_push_${isStandalone ? 'app' : 'web'}');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => widget.next));
  }

  void _afterPush() {
    if (!isStandalone && !_ios) {
      setState(() {
        step = 0;
        note = null;
      });
    } else {
      _done();
    }
  }

  Future<void> _enablePush() async {
    setState(() => busy = true);
    try {
      final sub = await subscribePush(AppConfig.vapidPublicKey);
      if (sub != null) {
        await Backend.instance.savePushSubscription(sub);
        if (!mounted) return;
        setState(() => busy = false);
        _afterPush();
        return;
      }
      note = 'دەستووری نەهاتە دان. دشێی پاشان ژ پرۆفایلێ ڤەکەی.';
    } catch (e) {
      note = 'سەرنەکەفت: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _install() async {
    if (canPromptInstall) {
      final ok = await promptInstall();
      if (ok) {
        _done();
        return;
      }
    }
    setState(() => note = 'ئەگەر پەنجەرە دیار نەبوو: ⋮ (سێ خال ل سەری) ➔ «Install app» یان «Add to Home screen»');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Row(children: [
              for (var k = 0; k < 2; k++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: (k == 0 ? step >= 0 : step == 1) ? AppColors.green : Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 30),
            if (step == 1) ..._pushStep() else ..._installStep(),
            if (note != null) ...[
              const SizedBox(height: 14),
              Text(note!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gold)),
            ],
            const SizedBox(height: 10),
            TextButton(onPressed: step == 1 ? _afterPush : _done, child: const Text('پاشان', style: TextStyle(color: Colors.white54))),
          ]),
        ),
      ),
    );
  }

  List<Widget> _pushStep() => [
        const Center(child: Text('🔔', style: TextStyle(fontSize: 90))),
        const SizedBox(height: 14),
        const Text('ئاگەهداریان ڤەکە', textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Sarchia', fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text(
          'دا نامە، بیرئینانا وانەیان و هشیاریا 🔥 Streak بگەهنە تە — حەتا دەمێ ئەپ گرتی ژی بیت.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.6),
        ),
        const SizedBox(height: 30),
        busy
            ? const Center(child: CircularProgressIndicator())
            : BigButton(label: 'ڤەکە 🔔', onPressed: _enablePush),
        const SizedBox(height: 8),
        const Text('پشتی هنگێ، مۆبایل دێ پرسیار کەت: «Allow» بکە.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)),
      ];

  List<Widget> _installStep() {
    Widget row(String n, String emoji, String text) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            CircleAvatar(radius: 16, backgroundColor: AppColors.green, child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.5))),
          ]),
        );
    return [
      Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset('assets/brand/logo.png', width: 96, height: 96),
        ),
      ),
      const SizedBox(height: 14),
      const Text('ASP بکە سەر مۆبایلا خۆ 📲', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Sarchia', fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(
        _ios
            ? 'دا وەکی ئەپەکێ راستەقینە ل سەر شاشێ بیت — و دا ئاگەهداری بگەهنە تە (ل iPhone ئەڤە پێدڤییە).'
            : 'دا وەکی ئەپەکێ راستەقینە ل سەر شاشێ بیت.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
      ),
      const SizedBox(height: 22),
      if (_ios) ...[
        row('١', '⬆️', 'ل خوارێ Safari، دوگمەیا Share (چوارگۆشە ب تیرەکێ) بکە'),
        row('٢', '➕', 'بچە خوارێ و «Add to Home Screen» هەلبژێرە'),
        row('٣', '✅', 'ل سەری «Add» بکە'),
        row('٤', '🏠', 'ASP ژ Home Screen ڤەکە — ئاگەهداری دێ ل وێرێ هێنە پرسیارکرن'),
        const SizedBox(height: 6),
        const Center(child: Text('👇 دوگمەیا Share ل خوارێ یە', style: TextStyle(color: AppColors.gold))),
      ] else ...[
        BigButton(label: 'دامەزراندن 📲', onPressed: _install),
        const SizedBox(height: 16),
        row('١', '⋮', 'ئەگەر پەنجەرە دیار نەبوو: ل سەری سێ خالان ⋮ بکە'),
        row('٢', '📲', '«Install app» یان «Add to Home screen» هەلبژێرە'),
      ],
    ];
  }
}
