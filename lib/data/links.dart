import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/backend.dart';

/// 🔗 جۆرێن لینکان (ئەدمین ئێکێ هەلدبژێریت و لینکی ددانیت)
class LinkKind {
  final String id, name;
  final IconData? icon;
  final String? glyph; // ئەگەر ئایکۆنەکا ئامادە نەبیت: نڤیسین (X · in)
  final List<Color> colors;
  final String hint;
  const LinkKind(this.id, this.name, this.colors, this.hint, {this.icon, this.glyph});
}

const linkKinds = <LinkKind>[
  LinkKind('facebook', 'Facebook', [Color(0xFF1877F2), Color(0xFF0C5DC7)], 'https://facebook.com/…', icon: Icons.facebook),
  LinkKind('instagram', 'Instagram', [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)], 'https://instagram.com/…', icon: Icons.camera_alt_rounded),
  LinkKind('tiktok', 'TikTok', [Color(0xFF111111), Color(0xFF2B2B2B)], 'https://tiktok.com/@…', icon: Icons.tiktok),
  LinkKind('youtube', 'YouTube', [Color(0xFFFF0000), Color(0xFFC40000)], 'https://youtube.com/@…', icon: Icons.play_arrow_rounded),
  LinkKind('whatsapp', 'WhatsApp', [Color(0xFF25D366), Color(0xFF128C7E)], 'https://wa.me/964…', icon: Icons.chat_rounded),
  LinkKind('telegram', 'Telegram', [Color(0xFF2AABEE), Color(0xFF1C8ACB)], 'https://t.me/…', icon: Icons.telegram),
  LinkKind('snapchat', 'Snapchat', [Color(0xFFFFE600), Color(0xFFFFC800)], 'https://snapchat.com/add/…', icon: Icons.snapchat),
  LinkKind('x', 'X', [Color(0xFF000000), Color(0xFF222222)], 'https://x.com/…', glyph: 'X'),
  LinkKind('linkedin', 'LinkedIn', [Color(0xFF0A66C2), Color(0xFF084E96)], 'https://linkedin.com/in/…', glyph: 'in'),
  LinkKind('discord', 'Discord', [Color(0xFF5865F2), Color(0xFF3E48C9)], 'https://discord.gg/…', icon: Icons.discord),
  LinkKind('website', 'مالپەڕ', [Color(0xFF0EA5A4), Color(0xFF0B7C7B)], 'https://…', icon: Icons.language_rounded),
  LinkKind('email', 'ئیمەیل', [Color(0xFFEA4335), Color(0xFFB9291D)], 'name@example.com', icon: Icons.email_rounded),
  LinkKind('phone', 'تەلەفۆن', [Color(0xFF34A853), Color(0xFF1F7A38)], '+964 …', icon: Icons.phone_rounded),
];

LinkKind linkKind(String id) => linkKinds.firstWhere((k) => k.id == id, orElse: () => linkKinds[10]);

class SocialLink {
  final String kind, url, label;
  const SocialLink(this.kind, this.url, [this.label = '']);
  Map<String, dynamic> toJson() => {'k': kind, 'u': url, if (label.isNotEmpty) 't': label};

  /// لینکێ دروست بۆ ڤەکرنێ (ئیمەیل ➔ mailto: · تەلەفۆن ➔ tel:)
  String get href {
    final u = url.trim();
    if (kind == 'email' && !u.startsWith('mailto:')) return 'mailto:$u';
    if (kind == 'phone' && !u.startsWith('tel:')) return 'tel:${u.replaceAll(RegExp(r'[^0-9+]'), '')}';
    if (kind != 'email' && kind != 'phone' && !u.contains('://')) return 'https://$u';
    return u;
  }
}

/// 🔗 لینکێن پەیوەندیێ یێن ئەدمینی (خشتا content، کلیل: links)
class SocialLinks {
  static List<SocialLink> items = const [];

  static void _parse(String? raw) {
    if (raw == null) {
      items = const [];
      return;
    }
    try {
      items = [
        for (final e in jsonDecode(raw) as List)
          if (e is Map && '${e['u'] ?? ''}'.trim().isNotEmpty) SocialLink('${e['k']}', '${e['u']}', '${e['t'] ?? ''}'),
      ];
    } catch (_) {}
  }

  /// ل دەستپێکا ئەپێ: ئێکسەر یا پاشەکەفتکری
  static Future<void> load() async => _parse(await Backend.instance.contentOverride('links', fresh: false));

  /// نوی ژ سێرڤەری (پرۆفایل / ئەدمین)
  static Future<void> refresh() async => _parse(await Backend.instance.contentOverride('links'));

  static Future<String?> save(List<SocialLink> list) async {
    final err = await Backend.instance.saveContent('links', [for (final l in list) l.toJson()]);
    if (err == null) items = List.of(list);
    return err;
  }
}
