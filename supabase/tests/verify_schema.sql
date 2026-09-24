-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — Phase 1 structural verification (read-only)
-- ═════════════════════════════════════════════════════════════════════════════
-- Paste into Supabase SQL Editor → Run. Returns one row per check:
--   status = PASS | FAIL, plus a final SUMMARY row.
-- Uses only session-temporary objects; changes nothing in the database.
-- ═════════════════════════════════════════════════════════════════════════════

create temp table if not exists _sawa_checks (n serial, area text, check_name text, status text, detail text) on commit preserve rows;
truncate _sawa_checks;

create or replace function pg_temp.chk(p_area text, p_name text, p_ok boolean, p_detail text default null)
returns void language sql as $$
  insert into _sawa_checks (area, check_name, status, detail)
  values (p_area, p_name, case when coalesce(p_ok, false) then 'PASS' else 'FAIL' end, p_detail);
$$;

do $$
declare
  t   text;
  r   record;
  v   bigint;
  v2  bigint;
  tables text[] := array['profiles','categories','providers','provider_private','provider_field_sources',
                         'provider_images','services','provider_packages','event_inquiries',
                         'contact_requests','provider_profile_views'];
  private_tables text[] := array['profiles','provider_private','event_inquiries','contact_requests','provider_profile_views'];
  public_tables  text[] := array['categories','providers','provider_field_sources','provider_images','services','provider_packages'];
begin
  -- ── Tables + RLS ─────────────────────────────────────────────────────────
  foreach t in array tables loop
    perform pg_temp.chk('tables', 'table exists: ' || t, to_regclass('public.' || t) is not null);
    perform pg_temp.chk('rls', 'RLS enabled: ' || t,
      (select relrowsecurity from pg_class where oid = to_regclass('public.' || t)));
  end loop;

  -- ── Foreign keys (column → table, delete rule) ────────────────────────────
  for r in
    select * from (values
      ('profiles',               'id',            'auth.users',             'c'),
      ('providers',              'user_id',       'public.profiles',        'n'),
      ('providers',              'category_id',   'public.categories',      'a'),
      ('provider_private',       'provider_id',   'public.providers',       'c'),
      ('provider_field_sources', 'provider_id',   'public.providers',       'c'),
      ('provider_images',        'provider_id',   'public.providers',       'c'),
      ('services',               'provider_id',   'public.providers',       'c'),
      ('provider_packages',      'provider_id',   'public.providers',       'c'),
      ('event_inquiries',        'customer_id',   'public.profiles',        'c'),
      ('provider_profile_views', 'provider_id',   'public.providers',       'c'),
      ('provider_profile_views', 'viewer_id',     'public.profiles',        'n'),
      ('contact_requests',       'customer_id',   'public.profiles',        'n'),
      ('contact_requests',       'provider_uuid', 'public.providers',       'n'),
      ('contact_requests',       'inquiry_id',    'public.event_inquiries', 'n'),
      ('contact_requests',       'service_id',    'public.services',        'n'),
      ('contact_requests',       'handled_by',    'public.profiles',        'n')
    ) as x(tbl, col, ref, del)
  loop
    perform pg_temp.chk('foreign keys',
      format('%s.%s → %s (on delete %s)', r.tbl, r.col, r.ref,
             case r.del when 'c' then 'cascade' when 'n' then 'set null' else 'no action' end),
      exists (
        select 1 from pg_constraint c
         where c.contype = 'f'
           and c.conrelid = to_regclass('public.' || r.tbl)
           and c.confrelid = to_regclass(r.ref)
           and c.confdeltype = r.del
           and array_length(c.conkey, 1) = 1
           and (select attname from pg_attribute where attrelid = c.conrelid and attnum = c.conkey[1]) = r.col));
  end loop;

  -- ── Indexes ────────────────────────────────────────────────────────────────
  for r in
    select unnest(array[
      'idx_profiles_role','uq_providers_legacy_id','uq_providers_user_id','idx_providers_status_category',
      'idx_providers_city','idx_providers_category','idx_provider_images_provider','idx_services_provider',
      'idx_provider_packages_provider','uq_event_inquiries_reference','idx_event_inquiries_customer',
      'idx_event_inquiries_status','idx_event_inquiries_ip','idx_provider_views_provider',
      'uq_contact_requests_reference','idx_contact_requests_customer','idx_contact_requests_provider_uuid',
      'idx_contact_requests_inquiry','idx_contact_requests_status','idx_contact_requests_ip',
      'idx_contact_requests_contact','idx_contact_requests_provider_id','idx_contact_requests_created_at'
    ]) as name
  loop
    perform pg_temp.chk('indexes', 'index: ' || r.name, to_regclass('public.' || r.name) is not null);
  end loop;

  -- ── Check constraints ──────────────────────────────────────────────────────
  for r in
    select unnest(array[
      'profiles_role_check','profiles_full_name_check','profiles_phone_check','categories_id_check',
      'providers_status_check','providers_source_check','providers_business_name_check',
      'providers_instagram_url_check','providers_price_check','providers_currency_check','providers_capacity_check',
      'provider_field_sources_status_check','provider_field_sources_field_check',
      'provider_images_kind_check','provider_images_source_check',
      'services_name_check','services_price_check','services_unit_check',
      'provider_packages_price_check','provider_packages_validity_check',
      'event_inquiries_event_type_check','event_inquiries_status_check','event_inquiries_owner_check',
      'event_inquiries_budget_check','contact_requests_status_check','contact_requests_channel_check'
    ]) as name
  loop
    perform pg_temp.chk('constraints', 'check: ' || r.name,
      exists (select 1 from pg_constraint where conname = r.name and contype = 'c'
                 and connamespace = 'public'::regnamespace));
  end loop;

  -- ── Triggers ───────────────────────────────────────────────────────────────
  for r in
    select * from (values
      ('auth.users',                    'on_auth_user_created'),
      ('auth.users',                    'on_auth_user_email_updated'),
      ('public.profiles',               'trg_profiles_guard'),
      ('public.providers',              'trg_providers_guard'),
      ('public.contact_requests',       'trg_contact_requests_before_insert'),
      ('public.contact_requests',       'trg_contact_requests_guard'),
      ('public.event_inquiries',        'trg_event_inquiries_before_insert'),
      ('public.event_inquiries',        'trg_event_inquiries_guard'),
      ('public.categories',             'trg_categories_touch'),
      ('public.services',               'trg_services_touch'),
      ('public.provider_packages',      'trg_provider_packages_touch'),
      ('public.provider_private',       'trg_provider_private_touch'),
      ('public.provider_field_sources', 'trg_provider_field_sources_touch')
    ) as x(tbl, trg)
  loop
    perform pg_temp.chk('triggers', format('trigger %s on %s (enabled)', r.trg, r.tbl),
      exists (select 1 from pg_trigger where tgrelid = to_regclass(r.tbl) and tgname = r.trg
                 and not tgisinternal and tgenabled <> 'D'));
  end loop;

  -- ── Policies ───────────────────────────────────────────────────────────────
  for r in
    select * from (values
      ('profiles', 3), ('categories', 2), ('providers', 6), ('provider_private', 2),
      ('provider_field_sources', 3), ('provider_images', 3), ('services', 3), ('provider_packages', 3),
      ('event_inquiries', 3), ('contact_requests', 7), ('provider_profile_views', 2)
    ) as x(tbl, expected)
  loop
    select count(*) into v from pg_policies where schemaname = 'public' and tablename = r.tbl;
    perform pg_temp.chk('rls', format('policies on %s = %s', r.tbl, r.expected), v = r.expected, 'found ' || v);
  end loop;

  perform pg_temp.chk('rls', 'v1 hole "authenticated_read_only" removed',
    not exists (select 1 from pg_policies where tablename = 'contact_requests' and policyname = 'authenticated_read_only'));
  perform pg_temp.chk('rls', 'v1 "anon_insert_only" (with check true) removed',
    not exists (select 1 from pg_policies where tablename = 'contact_requests' and policyname = 'anon_insert_only'));
  perform pg_temp.chk('rls', 'no permissive "using (true)" SELECT policy on private tables',
    not exists (select 1 from pg_policies where schemaname = 'public' and tablename = any(private_tables)
                  and cmd in ('SELECT','ALL') and qual = 'true'));

  -- ── Table privileges (public vs private) ──────────────────────────────────
  foreach t in array private_tables loop
    perform pg_temp.chk('privileges', 'anon cannot SELECT ' || t, not has_table_privilege('anon', 'public.' || t, 'SELECT'));
  end loop;
  foreach t in array public_tables loop
    perform pg_temp.chk('privileges', 'anon can SELECT ' || t || ' (RLS-filtered)', has_table_privilege('anon', 'public.' || t, 'SELECT'));
    perform pg_temp.chk('privileges', 'anon cannot write ' || t,
      not (has_table_privilege('anon', 'public.' || t, 'INSERT') or has_table_privilege('anon', 'public.' || t, 'UPDATE')
           or has_table_privilege('anon', 'public.' || t, 'DELETE')));
  end loop;
  perform pg_temp.chk('privileges', 'anon INSERT contact_requests kept (v1 app compatibility)',
    has_table_privilege('anon', 'public.contact_requests', 'INSERT'));
  perform pg_temp.chk('privileges', 'anon cannot UPDATE/DELETE contact_requests',
    not (has_table_privilege('anon', 'public.contact_requests', 'UPDATE') or has_table_privilege('anon', 'public.contact_requests', 'DELETE')));
  perform pg_temp.chk('privileges', 'authenticated cannot INSERT event_inquiries directly (RPC only)',
    not has_table_privilege('authenticated', 'public.event_inquiries', 'INSERT'));
  perform pg_temp.chk('privileges', 'authenticated cannot DELETE contact_requests',
    not has_table_privilege('authenticated', 'public.contact_requests', 'DELETE'));
  perform pg_temp.chk('privileges', 'API roles have no access to schema sawa_private',
    not has_schema_privilege('anon', 'sawa_private', 'USAGE') and not has_schema_privilege('authenticated', 'sawa_private', 'USAGE'));

  -- ── Functions ──────────────────────────────────────────────────────────────
  for r in
    select p.oid, n.nspname || '.' || p.proname as fn, p.prosecdef, p.proconfig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where (n.nspname = 'sawa_private')
        or (n.nspname = 'public' and p.proname in ('submit_contact_request','create_event_inquiry','record_provider_view',
            'get_provider_stats','is_admin','current_app_role','owns_provider','is_public_provider','owns_provider_folder'))
  loop
    perform pg_temp.chk('functions', r.fn || ': search_path pinned',
      exists (select 1 from unnest(coalesce(r.proconfig, '{}')) c where c like 'search_path=%'));
  end loop;
  select count(*) into v from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname in ('submit_contact_request','create_event_inquiry','record_provider_view','get_provider_stats');
  perform pg_temp.chk('functions', '4 RPCs deployed', v = 4, 'found ' || v);
  perform pg_temp.chk('functions', 'anon can call submit_contact_request',
    has_function_privilege('anon', 'public.submit_contact_request(uuid, text, text, text, bigint, uuid)', 'EXECUTE'));
  perform pg_temp.chk('functions', 'anon can call create_event_inquiry',
    has_function_privilege('anon', 'public.create_event_inquiry(text, int, text, text, date, numeric, numeric, text, text[], text, text, text, text)', 'EXECUTE'));
  perform pg_temp.chk('functions', 'anon cannot call get_provider_stats',
    not has_function_privilege('anon', 'public.get_provider_stats(uuid)', 'EXECUTE'));
  perform pg_temp.chk('functions', 'anon cannot call internal sawa_private.assert_rate_limit',
    not has_function_privilege('anon', 'sawa_private.assert_rate_limit(text, uuid, text, text, text)', 'EXECUTE'));

  -- ── Storage ────────────────────────────────────────────────────────────────
  perform pg_temp.chk('storage', 'bucket provider-media: public, 5MB, images only',
    exists (select 1 from storage.buckets where id = 'provider-media' and public and file_size_limit = 5242880
               and allowed_mime_types @> array['image/jpeg','image/png','image/webp']));
  perform pg_temp.chk('storage', 'bucket avatars: public, 5MB, images only',
    exists (select 1 from storage.buckets where id = 'avatars' and public and file_size_limit = 5242880
               and allowed_mime_types @> array['image/jpeg','image/png','image/webp']));
  select count(*) into v from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'sawa\_%';
  perform pg_temp.chk('storage', '8 SAWA storage policies', v = 8, 'found ' || v);

  -- ── Data ───────────────────────────────────────────────────────────────────
  select count(*) into v from public.categories where is_active;
  perform pg_temp.chk('data', '10 active categories', v = 10, 'found ' || v);
  select count(*) into v from auth.users u where not exists (select 1 from public.profiles p where p.id = u.id);
  perform pg_temp.chk('data', 'every auth user has a profile', v = 0, v || ' without profile');
  select count(*) into v from public.profiles where role = 'admin';
  perform pg_temp.chk('data', 'admin accounts (info)', true, v || ' admin(s)');

  -- ── Legacy contact_requests preserved ─────────────────────────────────────
  perform pg_temp.chk('legacy', 'backup sawa_private.contact_requests_backup_v1 exists',
    to_regclass('sawa_private.contact_requests_backup_v1') is not null);
  if to_regclass('sawa_private.contact_requests_backup_v1') is not null then
    execute 'select count(*) from sawa_private.contact_requests_backup_v1' into v;
    perform pg_temp.chk('legacy', 'backup row count (info)', true, v || ' rows snapshotted before v2');
    -- Modified = present but any original column differs. Must be 0.
    execute 'select count(*) from public.contact_requests c join sawa_private.contact_requests_backup_v1 b using (id)
              where c.provider_id  is distinct from b.provider_id  or c.user_name is distinct from b.user_name
                 or c.user_contact is distinct from b.user_contact or c.note      is distinct from b.note
                 or c.created_at   is distinct from b.created_at' into v2;
    perform pg_temp.chk('legacy', 'no pre-v2 row was modified', v2 = 0, v2 || ' modified');
    -- Missing = in backup but not in table. Must be 0, except the audit's own
    -- test row which cleanup_live_verify.sql removes on purpose.
    execute $q$select count(*) from sawa_private.contact_requests_backup_v1 b
              where not exists (select 1 from public.contact_requests c where c.id = b.id)
                and not (b.user_name = 'QA TEST - Claude audit (delete me)' and b.user_contact = '07000000000')$q$ into v2;
    perform pg_temp.chk('legacy', 'no pre-v2 row was lost', v2 = 0, v2 || ' missing');
  end if;
  select count(*) into v from public.contact_requests
   where reference_code is null or status is null or channel is null or is_spam is null or updated_at is null;
  perform pg_temp.chk('legacy', 'all rows backfilled (reference/status/channel/is_spam/updated_at)', v = 0, v || ' incomplete');
  select count(*) into v from public.contact_requests;
  perform pg_temp.chk('legacy', 'contact_requests total rows (info)', true, v || ' rows');
end $$;

-- SUMMARY first, then any FAIL rows, then PASS rows.
select area, check_name, status, detail
  from (
    select 0 as sort_key, 0 as n, 'SUMMARY' as area,
           format('%s checks', count(*)) as check_name,
           case when bool_and(status = 'PASS') then 'PHASE 1 SCHEMA OK'
                else count(*) filter (where status = 'FAIL') || ' FAILED' end as status,
           null::text as detail
      from _sawa_checks
    union all
    select case when status = 'FAIL' then 1 else 2 end, n, area, check_name, status, detail
      from _sawa_checks
  ) x
 order by sort_key, n;
