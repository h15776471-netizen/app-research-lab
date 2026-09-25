-- ═══════════════════════════════════════════════════════════════════════════
-- SAWA — 02_STORAGE — ATOMIC SCRIPT (generated — do not edit)
-- Source: supabase/migrations/*.sql · regenerate: node supabase/scripts/bundle.mjs
--
-- Supabase Dashboard → SQL Editor → New query → paste this whole file → Run.
-- Runs in a single transaction: if anything fails, NOTHING is applied.
-- Idempotent: safe to run again.
-- Files included:
--   20260924000500_storage.sql
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 20260924000500_storage.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — Migration 500: Storage buckets + policies
-- ═════════════════════════════════════════════════════════════════════════════
-- provider-media  public read (via public URL); writes only inside
--                 "<provider_id>/..." for a business the caller owns, or admin.
-- avatars         public read; writes only inside "<auth.uid()>/...".
-- Limits: 5 MB per file, JPEG / PNG / WebP only.
-- ═════════════════════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('provider-media', 'provider-media', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('avatars',        'avatars',        true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- First path segment must be a provider the caller owns.
create or replace function public.owns_provider_folder(p_object_name text)
returns boolean
language sql stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.providers p
     where p.user_id is not null
       and p.user_id = auth.uid()
       and p.id::text = split_part(p_object_name, '/', 1)
  )
$$;

grant execute on function public.owns_provider_folder(text) to anon, authenticated;

-- provider-media ---------------------------------------------------------------
drop policy if exists sawa_provider_media_owner_select on storage.objects;
drop policy if exists sawa_provider_media_owner_insert on storage.objects;
drop policy if exists sawa_provider_media_owner_update on storage.objects;
drop policy if exists sawa_provider_media_owner_delete on storage.objects;

create policy sawa_provider_media_owner_select on storage.objects
  for select to authenticated
  using (bucket_id = 'provider-media' and (public.owns_provider_folder(name) or public.is_admin()));

create policy sawa_provider_media_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'provider-media' and (public.owns_provider_folder(name) or public.is_admin()));

create policy sawa_provider_media_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'provider-media' and (public.owns_provider_folder(name) or public.is_admin()))
  with check (bucket_id = 'provider-media' and (public.owns_provider_folder(name) or public.is_admin()));

create policy sawa_provider_media_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'provider-media' and (public.owns_provider_folder(name) or public.is_admin()));

-- avatars ------------------------------------------------------------------------
drop policy if exists sawa_avatars_owner_select on storage.objects;
drop policy if exists sawa_avatars_owner_insert on storage.objects;
drop policy if exists sawa_avatars_owner_update on storage.objects;
drop policy if exists sawa_avatars_owner_delete on storage.objects;

create policy sawa_avatars_owner_select on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and split_part(name, '/', 1) = (select auth.uid())::text);

create policy sawa_avatars_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and split_part(name, '/', 1) = (select auth.uid())::text);

create policy sawa_avatars_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and split_part(name, '/', 1) = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and split_part(name, '/', 1) = (select auth.uid())::text);

create policy sawa_avatars_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and split_part(name, '/', 1) = (select auth.uid())::text);
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<< 20260924000500_storage.sql

commit;
