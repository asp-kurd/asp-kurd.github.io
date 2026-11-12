-- 🛡️ ASP 2.22 — ژێبرنا هەژماران (ئەدمین) + 💬 گفتوگۆیا راستەوخۆ دگەل ئەدمینی
-- ئێک جار: Supabase ➔ SQL Editor ➔ New query ➔ ڤێ هەمیێ بنڤیسە ➔ Run. (دووبارە Run کرن زیانێ ناکەت)

-- ───────── 💬 گفتوگۆ ─────────
alter table public.messages add column if not exists from_learner boolean not null default false;
create index if not exists messages_chat_idx on public.messages (learner_id, created_at desc) where kind = 'chat';

-- فێرخواز تنێ دشێت نامەیان بۆ ئەدمینی بهنێریت (ب ناڤێ خۆ، نە بۆ کەسێن دی)
drop policy if exists messages_learner_send on public.messages;
create policy messages_learner_send on public.messages for insert
  with check (learner_id = auth.uid() and kind = 'chat' and from_learner = true and length(body) <= 2000);

-- 🔒 کەس نەشێت نڤیسینا نامەیان بگوهۆڕیت — تنێ «هاتە خواندن» (read_at)
revoke update on public.messages from anon, authenticated;
grant update (read_at) on public.messages to authenticated;

-- 🗑️ ژێبرن: تنێ ئەدمین (policy ـا messages_admin_del یا هەی)
drop policy if exists messages_admin_del on public.messages;
create policy messages_admin_del on public.messages for delete using (public.is_admin());

-- ───────── 🗑️ ژێبرنا هەژمارەکێ ژ بنی (ئەدمین) ─────────
-- هەمی داتا دهێتە ژێبرن (پێشکەفتن، نامە، ئەزموون، چالاکی، دەنگ، هەژمار)؛
-- پاشان هەمان ئیمەیل دشێت ژ نوو هەژمارەکێ دروست بکەت.
create or replace function public.admin_delete_user(p_id uuid) returns text
language plpgsql security definer set search_path = public, auth, storage as $$
begin
  if not public.is_admin() then
    raise exception 'not admin';
  end if;
  if p_id = auth.uid() then
    raise exception 'cannot delete yourself';
  end if;
  begin delete from public.progress where user_id = p_id; exception when others then null; end;
  begin delete from public.messages where learner_id = p_id; exception when others then null; end;
  begin delete from public.exam_results where learner_id = p_id; exception when others then null; end;
  begin delete from public.activity where learner_id = p_id; exception when others then null; end;
  begin delete from public.learners where id = p_id; exception when others then null; end;
  begin delete from storage.objects where bucket_id = 'voices' and name like p_id::text || '/%'; exception when others then null; end;
  delete from auth.users where id = p_id;
  return 'ok';
end $$;
revoke all on function public.admin_delete_user(uuid) from public, anon;
grant execute on function public.admin_delete_user(uuid) to authenticated;
