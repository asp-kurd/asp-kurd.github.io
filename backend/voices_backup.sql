-- 💾 ASP: پاشەکەفتکرنا دەنگێن فێرخوازان (Supabase Storage)
-- Supabase ➔ SQL Editor ➔ New query ➔ ڤێ هەمیێ پێست بکە ➔ Run. (دشێی دووبارە ژی Run بکەی)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('voices', 'voices', false, 10485760, array['application/zip'])
on conflict (id) do update set file_size_limit = 10485760, allowed_mime_types = array['application/zip'];

-- هەر فێرخوازەک تنێ دشێت فایلێن خۆ ببینیت و بنڤیسیت: voices/<user id>/backup.zip
drop policy if exists "voices_own_select" on storage.objects;
drop policy if exists "voices_own_insert" on storage.objects;
drop policy if exists "voices_own_update" on storage.objects;
drop policy if exists "voices_own_delete" on storage.objects;
create policy "voices_own_select" on storage.objects for select to authenticated
  using (bucket_id = 'voices' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "voices_own_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'voices' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "voices_own_update" on storage.objects for update to authenticated
  using (bucket_id = 'voices' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "voices_own_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'voices' and (storage.foldername(name))[1] = auth.uid()::text);
