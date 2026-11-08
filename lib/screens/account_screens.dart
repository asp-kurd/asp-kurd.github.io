import 'package:flutter/material.dart';

import '../config.dart';
import '../services/backend.dart';
import '../services/progress_service.dart';
import '../services/push_stub.dart' if (dart.library.js_interop) '../services/push_web.dart';
import '../ui.dart';
import 'character_screen.dart';
import 'onboarding_screen.dart';

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
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  String? error;
  String? gender; // 'm' / 'f'
  bool useEmail = true; // 📧 ب ئیمەیل یان 👤 تنێ ب ناڤ
  bool showPass = false;

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    city.dispose();
    email.dispose();
    pass.dispose();
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
    if (useEmail) {
      final e = validateEmailPass(email.text, pass.text);
      if (e != null) {
        setState(() => error = e);
        return;
      }
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
      email: useEmail ? email.text : null,
      password: useEmail ? pass.text : null,
      native: p.nativeLang.code,
      target: p.targetLang.code,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        busy = false;
        error = err.contains(' ') && !err.contains('Exception') && !err.startsWith('db ') && !err.startsWith('auth ')
            ? err
            : 'پەیوەندی سەرنەکەفت. ئینتەرنێتێ پشکنە و دیسا تاقی بکە.\n($err)';
      });
      return;
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => CharacterPickerScreen(next: SetupScreen(next: widget.next))));
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
            border: Border.all(color: sel ? AppColors.blue : AppColors.fg24, width: sel ? 3 : 1.5),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: sel ? AppColors.fg : AppColors.fg70)),
          ]),
        ),
      ),
    );
  }

  /// 📧 ب ئیمەیل (پاراستی) · 👤 تنێ ب ناڤ
  Widget _modeSwitch() {
    Widget opt(bool v, String emoji, String title, String sub) {
      final sel = useEmail == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            useEmail = v;
            error = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.green.withValues(alpha: 0.16) : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? AppColors.green : AppColors.fg24, width: sel ? 2.5 : 1.5),
            ),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 2),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: sel ? AppColors.fg : AppColors.fg70)),
              Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.fg54)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      opt(true, '📧', 'ب ئیمەیل', 'پێشکەفتن هەردەم پاراستی یە'),
      const SizedBox(width: 10),
      opt(false, '👤', 'تنێ ب ناڤ', 'ب لەز — پاشان دشێی ئیمەیلێ زێدە بکەی'),
    ]);
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
              Text('بەری دەستپێکرنێ، خۆ بدە ناسین', textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg60)),
              const SizedBox(height: 26),
              _modeSwitch(),
              const SizedBox(height: 16),
              if (useEmail) ...[
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  decoration: _dec('ئیمەیل', Icons.alternate_email_rounded),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pass,
                  obscureText: !showPass,
                  autocorrect: false,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  decoration: _dec('پاسۆرد (ب کێمی ٦ پیت)', Icons.lock_rounded).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => showPass = !showPass),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
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
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(next: widget.next))),
                icon: const Icon(Icons.login_rounded),
                label: const Text('هەژمارا من هەیە — چوونا ژوور', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
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
              return Center(child: Text('چ نامە نینن', style: TextStyle(color: AppColors.fg54)));
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
      color: m.read ? AppColors.card : AppColors.tint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: m.read ? AppColors.fg12 : AppColors.gold, width: m.read ? 1 : 2),
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: Text(icon, style: const TextStyle(fontSize: 26)),
        title: Text(m.title, style: TextStyle(fontWeight: m.read ? FontWeight.normal : FontWeight.bold)),
        subtitle: Text('ژ ASP · ${_ago(m.created)}', style: TextStyle(fontSize: 12, color: AppColors.fg54)),
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
            Text(msg ?? 'دا نامە و بیرئینانا Streak بگەهنە تە', style: TextStyle(color: AppColors.fg70, fontSize: 13)),
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
                      color: (k == 0 ? step >= 0 : step == 1) ? AppColors.green : AppColors.fg12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 30),
            if (step == 1) ..._pushStep() else ..._installStep(),
            if (note != null) ...[
              const SizedBox(height: 14),
              Text(note!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.goldText)),
            ],
            const SizedBox(height: 10),
            TextButton(onPressed: step == 1 ? _afterPush : _done, child: Text('پاشان', style: TextStyle(color: AppColors.fg54))),
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
        Text(
          'دا نامە، بیرئینانا وانەیان و هشیاریا 🔥 Streak بگەهنە تە — حەتا دەمێ ئەپ گرتی ژی بیت.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.fg70, height: 1.6),
        ),
        const SizedBox(height: 30),
        busy
            ? const Center(child: CircularProgressIndicator())
            : BigButton(label: 'ڤەکە 🔔', onPressed: _enablePush),
        const SizedBox(height: 8),
        Text('پشتی هنگێ، مۆبایل دێ پرسیار کەت: «Allow» بکە.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg54, fontSize: 13)),
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
        style: TextStyle(color: AppColors.fg70, fontSize: 15, height: 1.6),
      ),
      const SizedBox(height: 22),
      if (_ios) ...[
        row('١', '⬆️', 'ل خوارێ Safari، دوگمەیا Share (چوارگۆشە ب تیرەکێ) بکە'),
        row('٢', '➕', 'بچە خوارێ و «Add to Home Screen» هەلبژێرە'),
        row('٣', '✅', 'ل سەری «Add» بکە'),
        row('٤', '🏠', 'ASP ژ Home Screen ڤەکە — ئاگەهداری دێ ل وێرێ هێنە پرسیارکرن'),
        const SizedBox(height: 6),
        Center(child: Text('👇 دوگمەیا Share ل خوارێ یە', style: TextStyle(color: AppColors.goldText))),
      ] else ...[
        BigButton(label: 'دامەزراندن 📲', onPressed: _install),
        const SizedBox(height: 16),
        row('١', '⋮', 'ئەگەر پەنجەرە دیار نەبوو: ل سەری سێ خالان ⋮ بکە'),
        row('٢', '📲', '«Install app» یان «Add to Home screen» هەلبژێرە'),
      ],
    ];
  }
}


// ───────────────────────── 🔑 چوونا ژوور ب ئیمەیل ─────────────────────────

String? validateEmailPass(String email, String pass) {
  final e = email.trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'ئیمەیلەکا دروست بنڤیسە (بۆ نموونە name@gmail.com)';
  if (pass.length < 6) return 'پاسۆرد دڤێت ب کێمی ٦ پیت بیت';
  return null;
}

InputDecoration _authDec(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );

class LoginScreen extends StatefulWidget {
  final Widget next;
  final String? prefillEmail;
  const LoginScreen({super.key, required this.next, this.prefillEmail});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final email = TextEditingController(text: widget.prefillEmail ?? '');
  final pass = TextEditingController();
  bool busy = false, show = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final v = validateEmailPass(email.text, pass.text);
    if (v != null) return setState(() => error = v);
    setState(() {
      busy = true;
      error = null;
    });
    final err = await Backend.instance.loginEmail(email.text, pass.text);
    if (err == null) {
      // پێشکەفتنا ڤێ هەژمارێ ژ سێرڤەری
      await ProgressService.instance.syncFromCloud(preferServer: true);
    }
    if (!mounted) return;
    if (err != null) {
      setState(() {
        busy = false;
        error = err;
      });
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => SetupScreen.needed() ? SetupScreen(next: widget.next) : widget.next),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('🔑 چوونا ژوور')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Text(
              widget.prefillEmail != null
                  ? 'ب خێر بێی بۆ ئەپا ASP ل سەر شاشێ! 📲 پاسۆردا خۆ بنڤیسە دا هەمی پێشکەفتنا تە ل ڤێرێ ژی بهێت.'
                  : 'ب ئیمەیل و پاسۆردا خۆ بچە ژوور. هەمی پێشکەفتنا تە (XP، ستریک، قۆناغ) دێ زڤڕیت.',
              style: TextStyle(color: AppColors.fg70, fontSize: 15, height: 1.5)),
          const SizedBox(height: 20),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            decoration: _authDec('ئیمەیل', Icons.alternate_email_rounded),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: pass,
            obscureText: !show,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            onSubmitted: (_) => _go(),
            decoration: _authDec('پاسۆرد', Icons.lock_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => show = !show),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(error!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 22),
          busy ? const Center(child: CircularProgressIndicator()) : BigButton(label: 'چوونا ژوور', onPressed: _go),
        ]),
      ),
    );
  }
}

// ───────────────────────── 📧 زێدەکرنا ئیمەیلێ بۆ هەژمارا ب ناڤ تنێ ─────────────────────────

class LinkEmailScreen extends StatefulWidget {
  const LinkEmailScreen({super.key});
  @override
  State<LinkEmailScreen> createState() => _LinkEmailScreenState();
}

class _LinkEmailScreenState extends State<LinkEmailScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false, show = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final v = validateEmailPass(email.text, pass.text);
    if (v != null) return setState(() => error = v);
    setState(() {
      busy = true;
      error = null;
    });
    final err = await Backend.instance.linkEmail(email.text, pass.text);
    if (err == null) await ProgressService.instance.syncFromCloud();
    if (!mounted) return;
    if (err != null) {
      setState(() {
        busy = false;
        error = err;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ ئیمەیل هاتە زێدەکرن — پێشکەفتنا تە نوکە پاراستی یە')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('📧 پاراستنا هەژمارێ')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(16)),
            child: Text(
              'ئیمەیل و پاسۆردەکێ زێدە بکە. پاشان ئەگەر مۆبایلا خۆ گوهۆڕی یان ئەپ ژێبر، ب ڤێ ئیمەیلێ دچییە ژوور و هەمی پێشکەفتنا تە دزڤڕیت. 🔒',
              style: TextStyle(color: AppColors.fg, fontSize: 15, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            decoration: _authDec('ئیمەیل', Icons.alternate_email_rounded),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: pass,
            obscureText: !show,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            onSubmitted: (_) => _go(),
            decoration: _authDec('پاسۆرد (ب کێمی ٦ پیت)', Icons.lock_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => show = !show),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(error!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 22),
          busy ? const Center(child: CircularProgressIndicator()) : BigButton(label: 'پاراستن', onPressed: _go),
        ]),
      ),
    );
  }
}

/// 🔒 کارتا هەژمارێ (ل پرۆفایلێ و سەرەکی)
class AccountCard extends StatelessWidget {
  final bool compact;
  final VoidCallback? onClose;
  const AccountCard({super.key, this.compact = false, this.onClose});

  @override
  Widget build(BuildContext context) {
    final b = Backend.instance;
    if (!b.enabled || !b.registered || b.isAdmin) return const SizedBox.shrink();
    if (b.hasEmail) {
      if (compact) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Text('📧', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.email!, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('✅ پێشکەفتنا تە ل سەر سێرڤەری پاراستی یە', style: TextStyle(color: AppColors.fg60, fontSize: 13)),
            ]),
          ),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('دەرکەفتن؟'),
                  content: const Text('پێشکەفتنا تە ل سەر سێرڤەری دمینیت. پاشان ب ئیمەیلێ دشێی دیسا بچییە ژوور.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('نە')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('بەلێ، دەرکەڤە')),
                  ],
                ),
              );
              if (ok != true) return;
              await b.logout();
              await ProgressService.instance.init();
              ProgressService.instance.notifyListeners();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const _AfterLogout()));
            },
            child: const Text('دەرکەفتن'),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF9600), Color(0xFFFF4B4B)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        const Text('🔒', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('ئیمەیلێ زێدە بکە دا پێشکەفتنا تە چ جاران نەچیت',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, height: 1.4)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFFF4B4B)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkEmailScreen())),
          child: const Text('زێدە بکە', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (onClose != null) IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: Colors.white70, size: 20)),
      ]),
    );
  }
}

/// پشتی دەرکەفتنێ: وەکی جارا ئێکێ (هەلبژارتنا زمانی ➔ تۆمارکرن / چوونا ژوور)
class _AfterLogout extends StatelessWidget {
  const _AfterLogout();
  @override
  Widget build(BuildContext context) => const LanguageOnboardingScreen();
}
