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

/// 🌐 زمانێن رێنمایێ
const _langs = <(String, String)>[
  ('ku', 'بادینی'),
  ('ckb', 'سۆرانی'),
  ('kmr', 'Kurmancî'),
  ('ar', 'العربية'),
  ('de', 'Deutsch'),
  ('en', 'English'),
];

/// ناڤێن دوگمەیێن Safari ب زمانێ مۆبایلێ (iPhone ب ئینگلیزی / عەرەبی / ئەلمانی)
const _ios = <String, Map<String, String>>{
  'en': {'share': 'Share', 'add': 'Add to Home Screen', 'more': 'View More', 'web': 'Open as Web App', 'ok': 'Add'},
  'ar': {'share': 'مشاركة', 'add': 'إضافة إلى الشاشة الرئيسية', 'more': 'عرض المزيد', 'web': 'فتح كتطبيق ويب', 'ok': 'إضافة'},
  'de': {'share': 'Teilen', 'add': 'Zum Home-Bildschirm', 'more': 'Mehr anzeigen', 'web': 'Als Web-App öffnen', 'ok': 'Hinzufügen'},
};

const _tx = <String, Map<String, String>>{
  'ku': {
    'title': '📲 پێشی ASP ل سەر شاشا مۆبایلێ دانە',
    'sub': 'وەسا ئەپ وەکی ئەپەکا ڕاستەقینە کار دکەت: ئاگەهداری دهێن، دەنگ باشترن، و پێشکەفتنا تە پاراستی دمینیت.',
    'btn': '📲 نیشا من بدە چاوا',
    'note': 'Apple ڕێ نادەت ماڵپەڕ ب خۆ ڤێ بکەت، بەلێ ئەم گاڤ ب گاڤ نیشا تە ددەین 👇',
    'manual': 'گاڤ ب گاڤ:',
    'safari': 'ڤێ پەڕێ ب Safari ڤەکە', 'safariSub': 'لینکێ کۆپی بکە و د Safari دا ڤەکە',
    's1': 'ل دوگمەیا «⋯» بدە', 's1sub': 'ل خوارێ شاشێ، ل لایێ ڕاستێ، ل ڕەخ ناڤنیشانا asp-poya.com (سێ خال). ئەگەر ئایکۆنا «Share» دیار بیت، ڕاستەوخۆ ل وێ بدە.',
    's2': 'ل «{share}» بدە', 's2sub': 'د لیستا ڤەبووی دا',
    's3': 'ل «{add}» بدە', 's3sub': 'لیستێ بۆ خوارێ ببە. ئەگەر نەدیت، پێشی ل «{more}» بدە.',
    's4': 'ل «{ok}» بدە', 's4sub': 'ل سەری ل لایێ ڕاستێ. «{web}» ڤەکری بهێلە ✅',
    's5': 'ئەپا ASP ژ سەر شاشێ ڤەکە', 's5sub': 'و ژ وێرێ دەست پێ بکە، هەمی تشت ل وێرێ دمینیت',
    'arrow': 'ل ڤێرێ ⋯',
    'coach': '٤ گاڤێن ب ساناهی 👇', 'close': 'دەست ل هەر جهەکی بدە دا بگری',
    'a1': 'ل ⋮ بدە', 'a1sub': 'ل سەری ل لایێ ڕاستێ یێ Chrome', 'a2': '«Install app» یان «Add to Home screen»', 'a3': 'ئەپا ASP ژ سەر شاشێ ڤەکە', 'a3sub': 'و ژ وێرێ دەست پێ بکە',
    'abtn': '📲 ئەپێ دامەزرینە', 'done': '✅ ئەپ هاتە دامەزراندن! نوکە ئەپا ASP ژ سەر شاشێ ڤەکە.',
    'i1': 'ل ⋯ یان ⋮ بدە', 'i1sub': 'ل سەری یان ل خوارێ یێ ڤێ پەڕێ', 'i2sub': 'ئەپ دێ د وێبگەڕی دا ڤەبیت', 'i3': 'پاشان ئەپێ ل سەر شاشێ دانە', 'i3sub': 'دێ ڕێنمایان ل وێرێ بینی',
    'copy': 'کۆپیکرنا لینکێ', 'copied': '✅ لینک هاتە کۆپیکرن، د Safari یان Chrome دا ڤەکە',
  },
  'ckb': {
    'title': '📲 سەرەتا ASP بخەرە سەر شاشەی مۆبایلەکەت',
    'sub': 'بەم شێوەیە وەک ئەپێکی ڕاستەقینە کار دەکات: ئاگادارکردنەوە دێن، دەنگ باشترە و پێشکەوتنەکەت پارێزراو دەبێت.',
    'btn': '📲 پیشانم بدە چۆن',
    'note': 'Apple ڕێگە نادات ماڵپەڕ خۆی ئەمە بکات، بەڵام هەنگاو بە هەنگاو پیشانت دەدەین 👇',
    'manual': 'هەنگاو بە هەنگاو:',
    'safari': 'ئەم پەڕەیە بە Safari بکەرەوە', 'safariSub': 'لینکەکە کۆپی بکە و لە Safari بیکەرەوە',
    's1': 'دوگمەی «⋯» دابگرە', 's1sub': 'لە خوارەوەی شاشە، لای ڕاست، لە تەنیشت ناونیشانی asp-poya.com (سێ خاڵ). ئەگەر ئایکۆنی «Share» دیار بوو، ڕاستەوخۆ ئەوە دابگرە.',
    's2': '«{share}» دابگرە', 's2sub': 'لە لیستەکەدا',
    's3': '«{add}» دابگرە', 's3sub': 'لیستەکە بۆ خوارەوە ببە. ئەگەر نەتبینی، سەرەتا «{more}» دابگرە.',
    's4': '«{ok}» دابگرە', 's4sub': 'لە سەرەوە لای ڕاست. «{web}» کراوە بهێڵەوە ✅',
    's5': 'ئەپی ASP لە سەر شاشەکە بکەرەوە', 's5sub': 'و لەوێوە دەست پێ بکە، هەموو شتێک لەوێ دەمێنێتەوە',
    'arrow': 'ئێرە ⋯',
    'coach': '٤ هەنگاوی ئاسان 👇', 'close': 'هەر شوێنێک دابگرە بۆ داخستن',
    'a1': '⋮ دابگرە', 'a1sub': 'لە سەرەوە لای ڕاستی Chrome', 'a2': '«Install app» یان «Add to Home screen»', 'a3': 'ئەپی ASP لە سەر شاشەکە بکەرەوە', 'a3sub': 'و لەوێوە دەست پێ بکە',
    'abtn': '📲 ئەپەکە دابمەزرێنە', 'done': '✅ ئەپەکە دامەزرا! ئێستا ئەپی ASP لە سەر شاشەکە بکەرەوە.',
    'i1': '⋯ یان ⋮ دابگرە', 'i1sub': 'لە سەرەوە یان خوارەوەی ئەم پەڕەیە', 'i2sub': 'ئەپەکە لە وێبگەڕدا دەکرێتەوە', 'i3': 'پاشان ئەپەکە بخەرە سەر شاشە', 'i3sub': 'ڕێنماییەکان لەوێ دەبینیت',
    'copy': 'کۆپیکردنی لینک', 'copied': '✅ لینکەکە کۆپی کرا، لە Safari یان Chrome بیکەرەوە',
  },
  'kmr': {
    'title': '📲 Pêşî ASP deyne ser ekrana telefonê',
    'sub': 'Wisa app wek appeke rastî dixebite: agahdarî tên, deng baştir in û pêşveçûna te tê parastin.',
    'btn': '📲 Nîşanî min bide çawa',
    'note': 'Apple destûrê nade ku malper bi xwe vê bike, lê em gav bi gav nîşanî te didin 👇',
    'manual': 'Gav bi gav:',
    'safari': 'Vê rûpelê bi Safari veke', 'safariSub': 'Girêdanê kopî bike û di Safari de veke',
    's1': 'Li bişkoka «⋯» bixe', 's1sub': 'Li jêrê ekranê, aliyê rastê, li kêleka navnîşana asp-poya.com (sê xal). Heke îkona «Share» xuya bibe, rasterast li wê bixe.',
    's2': 'Li «{share}» bixe', 's2sub': 'Di lîsteya vebûyî de',
    's3': 'Li «{add}» bixe', 's3sub': 'Lîsteyê ber bi jêr ve bibe. Heke nedît, pêşî li «{more}» bixe.',
    's4': 'Li «{ok}» bixe', 's4sub': 'Li jor aliyê rastê. «{web}» vekirî bihêle ✅',
    's5': 'App a ASP ji ser ekranê veke', 's5sub': 'û ji wir dest pê bike, her tişt li wir dimîne',
    'arrow': 'Li vir ⋯',
    'coach': '4 gavên hêsan 👇', 'close': 'Li her derekê bixe da ku bigire',
    'a1': 'Li ⋮ bixe', 'a1sub': 'Li jor aliyê rastê yê Chrome', 'a2': '«Install app» an «Add to Home screen»', 'a3': 'App a ASP ji ser ekranê veke', 'a3sub': 'û ji wir dest pê bike',
    'abtn': '📲 App saz bike', 'done': '✅ App hat sazkirin! Niha ASP ji ser ekranê veke.',
    'i1': 'Li ⋯ an ⋮ bixe', 'i1sub': 'Li jor an jêrê vê rûpelê', 'i2sub': 'App dê di gerokê de vebe', 'i3': 'Paşê app deyne ser ekranê', 'i3sub': 'Tu yê rêbernameyan li wir bibînî',
    'copy': 'Girêdanê kopî bike', 'copied': '✅ Girêdan hat kopîkirin, di Safari an Chrome de veke',
  },
  'ar': {
    'title': '📲 أولاً أضف ASP إلى الشاشة الرئيسية',
    'sub': 'هكذا يعمل كتطبيق حقيقي: تصلك الإشعارات، والصوت أفضل، ويبقى تقدمك محفوظاً.',
    'btn': '📲 أرني كيف',
    'note': 'لا تسمح Apple للموقع بفعل ذلك تلقائياً، لكننا سنريك خطوة بخطوة 👇',
    'manual': 'خطوة بخطوة:',
    'safari': 'افتح هذه الصفحة في Safari', 'safariSub': 'انسخ الرابط وافتحه في Safari',
    's1': 'اضغط على زر «⋯»', 's1sub': 'أسفل الشاشة على اليمين، بجانب عنوان asp-poya.com (ثلاث نقاط). إذا ظهر زر «المشاركة» اضغط عليه مباشرة.',
    's2': 'اضغط «{share}»', 's2sub': 'في القائمة التي تظهر',
    's3': 'اضغط «{add}»', 's3sub': 'مرّر القائمة للأسفل. إذا لم تجده اضغط أولاً «{more}».',
    's4': 'اضغط «{ok}»', 's4sub': 'في الأعلى على اليمين. اترك «{web}» مفعّلاً ✅',
    's5': 'افتح تطبيق ASP من الشاشة الرئيسية', 's5sub': 'وابدأ من هناك، كل شيء يبقى محفوظاً',
    'arrow': 'هنا ⋯',
    'coach': '٤ خطوات سهلة 👇', 'close': 'اضغط في أي مكان للإغلاق',
    'a1': 'اضغط ⋮', 'a1sub': 'أعلى يمين Chrome', 'a2': '«تثبيت التطبيق» أو «إضافة إلى الشاشة الرئيسية»', 'a3': 'افتح تطبيق ASP من الشاشة الرئيسية', 'a3sub': 'وابدأ من هناك',
    'abtn': '📲 ثبّت التطبيق', 'done': '✅ تم التثبيت! افتح ASP الآن من الشاشة الرئيسية.',
    'i1': 'اضغط ⋯ أو ⋮', 'i1sub': 'أعلى أو أسفل هذه الصفحة', 'i2sub': 'سيفتح التطبيق في المتصفح', 'i3': 'ثم أضف التطبيق إلى الشاشة الرئيسية', 'i3sub': 'ستجد التعليمات هناك',
    'copy': 'نسخ الرابط', 'copied': '✅ تم نسخ الرابط، افتحه في Safari أو Chrome',
  },
  'de': {
    'title': '📲 Lege ASP zuerst auf deinen Home-Bildschirm',
    'sub': 'So funktioniert ASP wie eine echte App: Benachrichtigungen, besserer Ton und dein Fortschritt bleibt gespeichert.',
    'btn': '📲 Zeig mir wie',
    'note': 'Apple erlaubt Webseiten das nicht automatisch – wir zeigen es dir Schritt für Schritt 👇',
    'manual': 'Schritt für Schritt:',
    'safari': 'Öffne diese Seite in Safari', 'safariSub': 'Kopiere den Link und öffne ihn in Safari',
    's1': 'Tippe auf «⋯»', 's1sub': 'Unten rechts neben der Adresse asp-poya.com (drei Punkte). Wenn du das Teilen-Symbol siehst, tippe direkt darauf.',
    's2': 'Tippe auf «{share}»', 's2sub': 'Im geöffneten Menü',
    's3': 'Tippe auf «{add}»', 's3sub': 'Nach unten scrollen. Nicht da? Zuerst «{more}» tippen.',
    's4': 'Tippe auf «{ok}»', 's4sub': 'Oben rechts. «{web}» eingeschaltet lassen ✅',
    's5': 'Öffne ASP vom Home-Bildschirm', 's5sub': 'und starte von dort – alles bleibt gespeichert',
    'arrow': 'Hier ⋯',
    'coach': '4 einfache Schritte 👇', 'close': 'Irgendwo tippen zum Schließen',
    'a1': 'Tippe auf ⋮', 'a1sub': 'Oben rechts in Chrome', 'a2': '«App installieren» oder «Zum Startbildschirm»', 'a3': 'Öffne ASP vom Startbildschirm', 'a3sub': 'und starte von dort',
    'abtn': '📲 App installieren', 'done': '✅ Installiert! Öffne ASP jetzt vom Startbildschirm.',
    'i1': 'Tippe auf ⋯ oder ⋮', 'i1sub': 'Oben oder unten auf dieser Seite', 'i2sub': 'Die App öffnet sich im Browser', 'i3': 'Dann ASP auf den Home-Bildschirm legen', 'i3sub': 'Dort siehst du die Anleitung',
    'copy': 'Link kopieren', 'copied': '✅ Link kopiert – öffne ihn in Safari oder Chrome',
  },
  'en': {
    'title': '📲 First, add ASP to your Home Screen',
    'sub': 'That way ASP works like a real app: notifications, better sound, and your progress stays saved.',
    'btn': '📲 Show me how',
    'note': "Apple doesn't let websites do this automatically – we'll show you step by step 👇",
    'manual': 'Step by step:',
    'safari': 'Open this page in Safari', 'safariSub': 'Copy the link and open it in Safari',
    's1': 'Tap the «⋯» button', 's1sub': 'At the bottom right, next to the address asp-poya.com (three dots). If you see the Share icon, tap it directly.',
    's2': 'Tap «{share}»', 's2sub': 'In the menu that opens',
    's3': 'Tap «{add}»', 's3sub': "Scroll down. Can't find it? Tap «{more}» first.",
    's4': 'Tap «{ok}»', 's4sub': 'Top right. Keep «{web}» switched on ✅',
    's5': 'Open ASP from your Home Screen', 's5sub': 'and start from there – everything stays saved',
    'arrow': 'Here ⋯',
    'coach': '4 easy steps 👇', 'close': 'Tap anywhere to close',
    'a1': 'Tap ⋮', 'a1sub': 'Top right in Chrome', 'a2': '«Install app» or «Add to Home screen»', 'a3': 'Open ASP from your Home Screen', 'a3sub': 'and start from there',
    'abtn': '📲 Install the app', 'done': '✅ Installed! Now open ASP from your Home Screen.',
    'i1': 'Tap ⋯ or ⋮', 'i1sub': 'At the top or bottom of this page', 'i2sub': 'The app will open in the browser', 'i3': 'Then add ASP to your Home Screen', 'i3sub': "You'll see the steps there",
    'copy': 'Copy link', 'copied': '✅ Link copied – open it in Safari or Chrome',
  },
};

class _InstallGateScreenState extends State<InstallGateScreen> with SingleTickerProviderStateMixin {
  bool coach = false; // 🧭 ڕێنمایا ل سەر هەمی شاشێ
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  bool installed = false;

  /// زمانێ ڕێنمایێ: ل دویف زمانێ مۆبایلێ (یان یێ هەلبژارتی)
  late String lang = () {
    final q = Uri.base.queryParameters['gl'];
    if (q != null && _tx.containsKey(q)) return q;
    final b = browserLang;
    if (b.startsWith('ar')) return 'ar';
    if (b.startsWith('de')) return 'de';
    if (b.startsWith('tr')) return 'kmr';
    if (b.startsWith('ckb')) return 'ckb';
    if (b.startsWith('en') && !b.contains('iq')) return 'en';
    return 'ku';
  }();

  bool get rtl => lang == 'ku' || lang == 'ckb' || lang == 'ar';

  /// ناڤێن دوگمەیێن Safari: ب زمانێ iPhone ـێ (ئەگەر عەرەبی / ئەلمانی بیت)، ئەگەر نە ئینگلیزی
  Map<String, String> get _iosL {
    final b = browserLang;
    if (b.startsWith('ar')) return _ios['ar']!;
    if (b.startsWith('de')) return _ios['de']!;
    return _ios['en']!;
  }

  String t(String k) {
    var s = _tx[lang]![k] ?? _tx['ku']![k] ?? k;
    for (final e in _iosL.entries) {
      s = s.replaceAll('{${e.key}}', e.value);
    }
    return s;
  }

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
            backgroundColor: AppColors.accent,
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

  /// 📱 وێنەیێ بچووک یێ دوگمەیا Safari (هەر وەکی ل سەر iPhone دیار دبیت)
  Widget _chip(String label, IconData i) => Container(
        constraints: const BoxConstraints(maxWidth: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0A84FF), width: 1.6),
          boxShadow: [BoxShadow(color: const Color(0xFF0A84FF).withValues(alpha: 0.35), blurRadius: 8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 20, color: const Color(0xFF0A84FF)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ]),
      );

  Widget _langBar() => SizedBox(
        height: 38,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final (code, name) in _langs)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                label: Text(name, style: const TextStyle(fontSize: 13)),
                selected: lang == code,
                onSelected: (_) => setState(() => lang = code),
              ),
            ),
        ]),
      );

  List<Widget> _iosSteps() => [
        // 🎬 نیشاندانەکا کورت: چاوا ل سەر شاشێ دانی
        const Center(child: _IosDemo()),
        const SizedBox(height: 16),
        if (!iosNonSafari) ...[
          BigButton(label: t('btn'), onPressed: () => setState(() => coach = true)),
          const SizedBox(height: 8),
          Text(t('note'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg60, fontSize: 13)),
          const SizedBox(height: 18),
          Text(t('manual'), style: TextStyle(color: AppColors.fg54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
        ],
        if (iosNonSafari) _step(0, t('safari'), t('safariSub'), _chip('Safari', Icons.explore_rounded)),
        _step(1, t('s1'), t('s1sub'), _chip('⋯', Icons.more_horiz_rounded)),
        _step(2, t('s2'), t('s2sub'), _chip(_iosL['share']!, Icons.ios_share_rounded)),
        _step(3, t('s3'), t('s3sub'), _chip(_iosL['add']!, Icons.add_box_outlined)),
        _step(4, t('s4'), t('s4sub'), _chip(_iosL['ok']!, Icons.check_rounded)),
        _step(5, t('s5'), t('s5sub'), ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/brand/logo.png', width: 34, height: 34),
        )),
      ];

  List<Widget> _androidSteps() => [
        if (canPromptInstall)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: BigButton(
              label: t('abtn'),
              onPressed: () async {
                final ok = await promptInstall();
                if (mounted) setState(() => installed = ok);
              },
            ),
          ),
        _step(1, t('a1'), t('a1sub'), _chip('⋮', Icons.more_vert_rounded)),
        _step(2, t('a2'), '', _chip('Install', Icons.install_mobile_rounded)),
        _step(3, t('a3'), t('a3sub'), ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/brand/logo.png', width: 34, height: 34),
        )),
      ];

  @override
  Widget build(BuildContext context) {
    final ios = platformKind == 'ios';
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: Stack(children: [
            ListView(padding: const EdgeInsets.fromLTRB(22, 14, 22, 130), children: [
              _langBar(),
              const SizedBox(height: 14),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/brand/logo.png', width: 90, height: 90),
                ),
              ),
              const SizedBox(height: 14),
              Text(t('title'),
                  textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Sarchia', fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(t('sub'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg70, fontSize: 15, height: 1.6)),
              const SizedBox(height: 20),
              if (inAppBrowser) ...[
                _step(1, t('i1'), t('i1sub'), _chip('⋯', Icons.more_horiz_rounded)),
                _step(2, ios ? '«Open in Safari»' : '«Open in Chrome»', t('i2sub'),
                    _chip(ios ? 'Safari' : 'Chrome', Icons.open_in_browser_rounded)),
                _step(3, t('i3'), t('i3sub'), _chip('Home', Icons.home_rounded)),
                OutlinedButton.icon(
                  onPressed: () async {
                    await copyText(Uri.base.origin);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('copied'))));
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(t('copy')),
                ),
              ] else if (installed)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
                  child: Text(t('done'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                )
              else
                ...(ios ? _iosSteps() : _androidSteps()),
            ]),
            // ⬇️ تیرا ب لڤین بۆ «⋯» ل خوارێ Safari (لایێ ڕاستێ)
            if (ios && !inAppBrowser && !iosNonSafari && !coach)
              Positioned(bottom: 6, right: 14, child: _Arrow(c: c, label: t('arrow'))),
            // 🧭 ڕێنمایا مەزن (پشتی لێدانا دوگمێ کەسک)
            if (coach)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => coach = false),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.9),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(children: [
                      Text(t('coach'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      const _IosDemo(),
                      const SizedBox(height: 12),
                      for (final (n, title, chip, icon) in [
                        ('1', t('s1'), '⋯', Icons.more_horiz_rounded),
                        ('2', t('s2'), _iosL['share']!, Icons.ios_share_rounded),
                        ('3', t('s3'), _iosL['add']!, Icons.add_box_outlined),
                        ('4', t('s4'), _iosL['ok']!, Icons.check_rounded),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            CircleAvatar(
                                radius: 13,
                                backgroundColor: AppColors.accent,
                                child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 10),
                            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15))),
                            _chip(chip, icon),
                          ]),
                        ),
                      const SizedBox(height: 6),
                      Text(t('close'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const Spacer(),
                      Align(alignment: Alignment.bottomRight, child: _Arrow(c: c, label: t('arrow'))),
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
        return Directionality(
          textDirection: TextDirection.ltr, // وەکی iPhone ب ئینگلیزی
          child: Container(
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
        ));
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
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
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
