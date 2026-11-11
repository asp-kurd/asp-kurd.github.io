-- 🛡️ ASP — ئامرازێن ئەدمینی (خەلەتیێن فێرخوازان، دینار، بابەتێن لاواز)
-- ئێک جار: Supabase ➔ SQL Editor ➔ New query ➔ ڤێ هەمیێ بنڤیسە ➔ Run. (دووبارە Run کرن زیانێ ناکەت)
-- ئەدمین دشێت پێشکەفتنا فێرخوازان بخوینیت (تنێ خواندن، نە گوهۆڕین).
drop policy if exists progress_admin_read on public.progress;
create policy progress_admin_read on public.progress for select using (public.is_admin());
