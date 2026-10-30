/// ڕێکخستنێن سێرڤەری (Supabase). ئەگەر ڤالا بن، ئەپ بێ هەژمار و بێ ئەدمین کار دکەت.
/// anon key ئاشکەرایە (public) — پاراستن ب RLS د داتابەیسێ دا دهێتە کرن.
class AppConfig {
  static const supabaseUrl = 'https://pecnuohpxraoxvfjsngm.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_btfzw-7Kc7ZJmfqvhPYr5w_ybgL55CJ';

  /// کلیلا گشتی یا Web Push (VAPID). کلیلا تایبەت د داتابەیسێ دایە (app_secrets).
  static const vapidPublicKey = 'BKA7MxlgyAAeqpH2XfLsbFtw2qRCdqwJB0InMLm3i8o8Kcux8O55-G5N9dHO8x5GwZA0ewGzia18f8yqWd6yERo';

  static bool get backendEnabled => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
