-- ═══════════════════════════════════════════════════════════════════════════
-- SAWA — ALL MIGRATIONS IN ONE ATOMIC SCRIPT (generated — do not edit)
-- Source: supabase/migrations/*.sql · regenerate: node supabase/scripts/bundle.mjs
--
-- Supabase Dashboard → SQL Editor → New query → paste this whole file → Run.
-- Runs in a single transaction: if anything fails, NOTHING is applied.
-- Idempotent: safe to run again.
-- Files included:
--   20260924000100_core_schema.sql
--   20260924000200_contact_requests_v2.sql
--   20260924000300_rls_policies.sql
--   20260924000400_rpc.sql
--   20260924000500_storage.sql
--   20260924000600_seed_categories.sql
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 20260924000100_core_schema.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — Migration 100: core schema
-- ═════════════════════════════════════════════════════════════════════════════
-- Tables: profiles, categories, providers, provider_private,
--         provider_field_sources, provider_images, services,
--         provider_packages, event_inquiries, provider_profile_views
--
-- Idempotent — safe to run more than once. Never drops a table that holds
-- data (see the pre-flight block below).
--
-- Run order: 100 → 200 → 300 → 400 → 500 → 600 (see supabase/README.md).
-- ═════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- Private schema for internal helpers + backups. NOT exposed by the Data API.
-- ─────────────────────────────────────────────────────────────────────────────
create schema if not exists sawa_private;
revoke all on schema sawa_private from public;

-- ─────────────────────────────────────────────────────────────────────────────
-- Pre-flight: tables from the abandoned v1 "platform redesign" schema.sql
-- (profiles/display_name, services/title, event_inquiries/user_id,
-- provider_profiles) were never applied to the live project, but if any
-- exist in an incompatible shape we drop them ONLY when empty, and abort
-- otherwise so no data is ever lost silently.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare
  v_rows bigint;
begin
  -- services (v1 shape had a "title" column and provider_id → profiles)
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'services' and column_name = 'title') then
    execute 'select count(*) from public.services' into v_rows;
    if v_rows > 0 then
      raise exception 'SAWA migration aborted: legacy public.services has % rows. Back it up and migrate manually.', v_rows;
    end if;
    drop table public.services;
  end if;

  -- event_inquiries (v1 shape had "user_id")
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'event_inquiries' and column_name = 'user_id') then
    execute 'select count(*) from public.event_inquiries' into v_rows;
    if v_rows > 0 then
      raise exception 'SAWA migration aborted: legacy public.event_inquiries has % rows. Back it up and migrate manually.', v_rows;
    end if;
    drop table public.event_inquiries;
  end if;

  -- provider_profiles (replaced by public.providers)
  if exists (select 1 from information_schema.tables
             where table_schema = 'public' and table_name = 'provider_profiles') then
    execute 'select count(*) from public.provider_profiles' into v_rows;
    if v_rows > 0 then
      raise exception 'SAWA migration aborted: legacy public.provider_profiles has % rows. Back it up and migrate manually.', v_rows;
    end if;
    drop table public.provider_profiles;
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Generic helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- True when the current statement comes from a client JWT (anon or
-- authenticated) — i.e. from the app. False for the SQL Editor, the
-- dashboard and service_role, which are trusted operators.
create or replace function sawa_private.is_client_request()
returns boolean
language sql stable
set search_path = ''
as $$
  select coalesce(auth.role(), '') in ('anon', 'authenticated')
$$;

create or replace function sawa_private.touch_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Human-friendly, non-sequential reference, e.g. "SW-3F9A1C2B".
create or replace function sawa_private.gen_reference(p_prefix text)
returns text
language sql volatile
set search_path = ''
as $$
  select p_prefix || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
$$;

-- Arabic-Indic / Persian digits → ASCII, then trim.
create or replace function sawa_private.normalize_digits(p text)
returns text
language sql immutable
set search_path = ''
as $$
  select nullif(trim(translate(p, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789')), '')
$$;

-- Digits only — used to compare phone numbers regardless of formatting.
create or replace function sawa_private.digits_only(p text)
returns text
language sql immutable
set search_path = ''
as $$
  select nullif(regexp_replace(coalesce(sawa_private.normalize_digits(p), ''), '\D', '', 'g'), '')
$$;

-- SHA-256 of the caller IP (from PostgREST request headers). The raw IP is
-- never stored. Returns NULL when no header is available (SQL Editor etc.).
create or replace function sawa_private.request_ip_hash()
returns text
language plpgsql stable
security definer
set search_path = ''
as $$
declare
  v_headers jsonb;
  v_ip text;
begin
  begin
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  exception when others then
    return null;
  end;
  if v_headers is null then
    return null;
  end if;
  v_ip := nullif(trim(split_part(coalesce(v_headers ->> 'x-forwarded-for', ''), ',', 1)), '');
  v_ip := coalesce(v_ip, nullif(trim(v_headers ->> 'cf-connecting-ip'), ''), nullif(trim(v_headers ->> 'x-real-ip'), ''));
  if v_ip is null then
    return null;
  end if;
  return encode(sha256(convert_to('sawa-rl:' || v_ip, 'UTF8')), 'hex');
end $$;

-- ═════════════════════════════════════════════════════════════════════════════
-- profiles — one row per auth user. Role is set ONLY by the signup trigger
-- (customer | provider) or by an operator (admin). Never by the client.
-- ═════════════════════════════════════════════════════════════════════════════
create table if not exists public.profiles (
  id         uuid        primary key references auth.users (id) on delete cascade,
  role       text        not null default 'customer',
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists full_name  text;
alter table public.profiles add column if not exists phone      text;
alter table public.profiles add column if not exists email      text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

-- If a v1 profiles table exists (display_name NOT NULL), keep its data but
-- stop requiring the legacy column.
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'profiles' and column_name = 'display_name') then
    execute 'alter table public.profiles alter column display_name drop not null';
    execute 'update public.profiles set full_name = display_name where full_name is null';
  end if;
end $$;

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add  constraint profiles_role_check
  check (role in ('customer', 'provider', 'admin'));
alter table public.profiles drop constraint if exists profiles_full_name_check;
alter table public.profiles add  constraint profiles_full_name_check
  check (full_name is null or char_length(full_name) between 1 and 120);
alter table public.profiles drop constraint if exists profiles_phone_check;
alter table public.profiles add  constraint profiles_phone_check
  check (phone is null or char_length(phone) <= 30);
alter table public.profiles drop constraint if exists profiles_avatar_url_check;
alter table public.profiles add  constraint profiles_avatar_url_check
  check (avatar_url is null or char_length(avatar_url) <= 1000);

create index if not exists idx_profiles_role on public.profiles (role);

comment on table public.profiles is
  'One row per Supabase Auth user. role is assigned by the signup trigger (customer/provider) or by an operator (admin) — never by the client.';

-- ═════════════════════════════════════════════════════════════════════════════
-- categories — extensible taxonomy (seeded in migration 600).
-- ═════════════════════════════════════════════════════════════════════════════
create table if not exists public.categories (
  id         text        primary key,
  name_ar    text        not null,
  name_en    text        not null,
  icon_key   text        not null default 'sparkle',
  sort_order int         not null default 0,
  is_active  boolean     not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.categories drop constraint if exists categories_id_check;
alter table public.categories add  constraint categories_id_check check (id ~ '^[a-z][a-z_]{1,39}$');

-- ═════════════════════════════════════════════════════════════════════════════
-- providers — a business entity. user_id is NULL for listings sourced by the
-- SAWA team (e.g. from PDFs) until an owner claims them (future workflow).
-- Private contact data lives in provider_private, never here.
-- ═════════════════════════════════════════════════════════════════════════════
create table if not exists public.providers (
  id                uuid          primary key default gen_random_uuid(),
  user_id           uuid          references public.profiles (id) on delete set null,
  category_id       text          not null references public.categories (id),
  legacy_id         text,
  business_name     text          not null,
  short_description text,
  description       text,
  city              text          not null default 'بغداد',
  area              text,
  address           text,
  instagram_url     text,
  website           text,
  logo_url          text,
  cover_image_url   text,
  capacity          int,
  price_from        numeric(14,2),
  price_to          numeric(14,2),
  currency          text          not null default 'IQD',
  price_note        text,
  status            text          not null default 'draft',
  source            text          not null default 'self_registered',
  source_ref        text,
  submitted_at      timestamptz,
  published_at      timestamptz,
  created_at        timestamptz   not null default now(),
  updated_at        timestamptz   not null default now()
);

alter table public.providers drop constraint if exists providers_status_check;
alter table public.providers add  constraint providers_status_check
  check (status in ('draft', 'pending', 'published', 'suspended'));
alter table public.providers drop constraint if exists providers_source_check;
alter table public.providers add  constraint providers_source_check
  check (source in ('pdf', 'self_registered', 'admin'));
alter table public.providers drop constraint if exists providers_business_name_check;
alter table public.providers add  constraint providers_business_name_check
  check (char_length(trim(business_name)) between 1 and 150);
alter table public.providers drop constraint if exists providers_text_lengths_check;
alter table public.providers add  constraint providers_text_lengths_check
  check (    (short_description is null or char_length(short_description) <= 300)
         and (description       is null or char_length(description)       <= 3000)
         and (area              is null or char_length(area)              <= 120)
         and (address           is null or char_length(address)           <= 300)
         and (price_note        is null or char_length(price_note)        <= 300)
         and char_length(city) between 1 and 80);
alter table public.providers drop constraint if exists providers_instagram_url_check;
alter table public.providers add  constraint providers_instagram_url_check
  check (instagram_url is null or instagram_url ~ '^https://(www\.)?instagram\.com/[A-Za-z0-9._]{1,30}/?$');
alter table public.providers drop constraint if exists providers_website_check;
alter table public.providers add  constraint providers_website_check
  check (website is null or (website ~ '^https?://' and char_length(website) <= 300));
alter table public.providers drop constraint if exists providers_capacity_check;
alter table public.providers add  constraint providers_capacity_check
  check (capacity is null or capacity between 1 and 100000);
alter table public.providers drop constraint if exists providers_price_check;
alter table public.providers add  constraint providers_price_check
  check (    (price_from is null or price_from >= 0)
         and (price_to   is null or price_to   >= 0)
         and (price_from is null or price_to is null or price_to >= price_from));
alter table public.providers drop constraint if exists providers_currency_check;
alter table public.providers add  constraint providers_currency_check
  check (currency in ('IQD', 'USD'));

create unique index if not exists uq_providers_legacy_id on public.providers (legacy_id) where legacy_id is not null;
-- One business per account for now (relax later if multi-business is needed).
create unique index if not exists uq_providers_user_id on public.providers (user_id) where user_id is not null;
create index if not exists idx_providers_status_category on public.providers (status, category_id);
create index if not exists idx_providers_city            on public.providers (city);
create index if not exists idx_providers_category        on public.providers (category_id);

comment on table  public.providers is
  'Business entity. Public visibility only when status = published. user_id NULL = SAWA-managed listing (source=pdf) awaiting an owner.';
comment on column public.providers.legacy_id is
  'v1 id from providers.json (e.g. hall_ritaj_001). Links legacy contact_requests.provider_id.';
comment on column public.providers.source_ref is
  'Where the listing data came from, e.g. the source PDF filename.';

-- ─────────────────────────────────────────────────────────────────────────────
-- provider_private — business phone/WhatsApp/email. Owner + admin only.
-- (Locked decision: provider phone is not shown to customers by default.)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.provider_private (
  provider_id    uuid        primary key references public.providers (id) on delete cascade,
  phone          text,
  whatsapp       text,
  email          text,
  internal_notes text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.provider_private drop constraint if exists provider_private_lengths_check;
alter table public.provider_private add  constraint provider_private_lengths_check
  check (    (phone          is null or char_length(phone)          <= 40)
         and (whatsapp       is null or char_length(whatsapp)       <= 40)
         and (email          is null or char_length(email)          <= 200)
         and (internal_notes is null or char_length(internal_notes) <= 4000));

-- ─────────────────────────────────────────────────────────────────────────────
-- provider_field_sources — data-integrity metadata per field.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.provider_field_sources (
  id          bigint      generated always as identity primary key,
  provider_id uuid        not null references public.providers (id) on delete cascade,
  field       text        not null,
  status      text        not null,
  source_ref  text,
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (provider_id, field)
);

alter table public.provider_field_sources drop constraint if exists provider_field_sources_status_check;
alter table public.provider_field_sources add  constraint provider_field_sources_status_check
  check (status in ('verified', 'source_only', 'unverified', 'missing'));
alter table public.provider_field_sources drop constraint if exists provider_field_sources_field_check;
alter table public.provider_field_sources add  constraint provider_field_sources_field_check
  check (field in ('business_name', 'category', 'description', 'city', 'area', 'address',
                   'instagram_url', 'website', 'phone', 'capacity', 'price', 'services',
                   'packages', 'images'));

comment on table public.provider_field_sources is
  'Per-field provenance: verified | source_only | unverified | missing. Every published value must be traceable.';

-- ─────────────────────────────────────────────────────────────────────────────
-- provider_images
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.provider_images (
  id           uuid        primary key default gen_random_uuid(),
  provider_id  uuid        not null references public.providers (id) on delete cascade,
  url          text        not null,
  storage_path text,
  kind         text        not null default 'gallery',
  sort_order   int         not null default 0,
  alt_text     text,
  source       text        not null default 'upload',
  source_ref   text,
  created_at   timestamptz not null default now()
);

alter table public.provider_images drop constraint if exists provider_images_kind_check;
alter table public.provider_images add  constraint provider_images_kind_check
  check (kind in ('cover', 'gallery', 'logo'));
alter table public.provider_images drop constraint if exists provider_images_source_check;
alter table public.provider_images add  constraint provider_images_source_check
  check (source in ('upload', 'pdf_extract'));
alter table public.provider_images drop constraint if exists provider_images_url_check;
alter table public.provider_images add  constraint provider_images_url_check
  check (char_length(url) between 1 and 1000);

create index if not exists idx_provider_images_provider on public.provider_images (provider_id, sort_order);

-- ─────────────────────────────────────────────────────────────────────────────
-- services
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.services (
  id          uuid          primary key default gen_random_uuid(),
  provider_id uuid          not null references public.providers (id) on delete cascade,
  name        text          not null,
  description text,
  price_from  numeric(14,2),
  price_to    numeric(14,2),
  currency    text          not null default 'IQD',
  unit        text,
  image_url   text,
  is_active   boolean       not null default true,
  sort_order  int           not null default 0,
  created_at  timestamptz   not null default now(),
  updated_at  timestamptz   not null default now()
);

alter table public.services drop constraint if exists services_name_check;
alter table public.services add  constraint services_name_check
  check (char_length(trim(name)) between 1 and 150);
alter table public.services drop constraint if exists services_description_check;
alter table public.services add  constraint services_description_check
  check (description is null or char_length(description) <= 2000);
alter table public.services drop constraint if exists services_price_check;
alter table public.services add  constraint services_price_check
  check (    (price_from is null or price_from >= 0)
         and (price_to   is null or price_to   >= 0)
         and (price_from is null or price_to is null or price_to >= price_from));
alter table public.services drop constraint if exists services_currency_check;
alter table public.services add  constraint services_currency_check
  check (currency in ('IQD', 'USD'));
alter table public.services drop constraint if exists services_unit_check;
alter table public.services add  constraint services_unit_check
  check (unit is null or unit in ('event', 'person', 'hour', 'day', 'piece', 'package'));

create index if not exists idx_services_provider on public.services (provider_id, sort_order);

-- ─────────────────────────────────────────────────────────────────────────────
-- provider_packages — packages & time-bound offers (e.g. "عرض شهري 9 و10").
-- An offer is never stored as the provider's permanent base price.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.provider_packages (
  id          uuid          primary key default gen_random_uuid(),
  provider_id uuid          not null references public.providers (id) on delete cascade,
  title       text          not null,
  description text,
  price_from  numeric(14,2),
  price_to    numeric(14,2),
  currency    text          not null default 'IQD',
  conditions  text,
  is_offer    boolean       not null default false,
  valid_from  date,
  valid_until date,
  source_ref  text,
  is_active   boolean       not null default true,
  sort_order  int           not null default 0,
  created_at  timestamptz   not null default now(),
  updated_at  timestamptz   not null default now()
);

alter table public.provider_packages drop constraint if exists provider_packages_title_check;
alter table public.provider_packages add  constraint provider_packages_title_check
  check (char_length(trim(title)) between 1 and 150);
alter table public.provider_packages drop constraint if exists provider_packages_text_check;
alter table public.provider_packages add  constraint provider_packages_text_check
  check (    (description is null or char_length(description) <= 2000)
         and (conditions  is null or char_length(conditions)  <= 1000));
alter table public.provider_packages drop constraint if exists provider_packages_price_check;
alter table public.provider_packages add  constraint provider_packages_price_check
  check (    (price_from is null or price_from >= 0)
         and (price_to   is null or price_to   >= 0)
         and (price_from is null or price_to is null or price_to >= price_from));
alter table public.provider_packages drop constraint if exists provider_packages_currency_check;
alter table public.provider_packages add  constraint provider_packages_currency_check
  check (currency in ('IQD', 'USD'));
alter table public.provider_packages drop constraint if exists provider_packages_validity_check;
alter table public.provider_packages add  constraint provider_packages_validity_check
  check (valid_from is null or valid_until is null or valid_until >= valid_from);

create index if not exists idx_provider_packages_provider on public.provider_packages (provider_id, sort_order);

-- ═════════════════════════════════════════════════════════════════════════════
-- event_inquiries — planner submissions (authenticated customer OR guest).
-- ═════════════════════════════════════════════════════════════════════════════
create table if not exists public.event_inquiries (
  id             bigint        generated always as identity primary key,
  reference_code text          not null,
  customer_id    uuid          references public.profiles (id) on delete cascade,
  guest_name     text,
  guest_contact  text,
  event_type     text          not null,
  guest_count    int,
  city           text,
  area           text,
  event_date     date,
  budget_min     numeric(14,2),
  budget_max     numeric(14,2),
  currency       text          not null default 'IQD',
  services       text[]        not null default '{}',
  style          text,
  notes          text,
  status         text          not null default 'open',
  ip_hash        text,
  created_at     timestamptz   not null default now(),
  updated_at     timestamptz   not null default now()
);

-- An inquiry belongs to its customer: deleting the account deletes it
-- (SET NULL would violate event_inquiries_owner_check for non-guest rows).
alter table public.event_inquiries drop constraint if exists event_inquiries_customer_id_fkey;
alter table public.event_inquiries add  constraint event_inquiries_customer_id_fkey
  foreign key (customer_id) references public.profiles (id) on delete cascade;

alter table public.event_inquiries drop constraint if exists event_inquiries_event_type_check;
alter table public.event_inquiries add  constraint event_inquiries_event_type_check
  check (event_type in ('wedding', 'engagement', 'birthday', 'graduation', 'corporate', 'other'));
alter table public.event_inquiries drop constraint if exists event_inquiries_status_check;
alter table public.event_inquiries add  constraint event_inquiries_status_check
  check (status in ('open', 'in_review', 'closed', 'cancelled'));
alter table public.event_inquiries drop constraint if exists event_inquiries_owner_check;
alter table public.event_inquiries add  constraint event_inquiries_owner_check
  check (customer_id is not null or guest_contact is not null);
alter table public.event_inquiries drop constraint if exists event_inquiries_guest_count_check;
alter table public.event_inquiries add  constraint event_inquiries_guest_count_check
  check (guest_count is null or guest_count between 1 and 100000);
alter table public.event_inquiries drop constraint if exists event_inquiries_budget_check;
alter table public.event_inquiries add  constraint event_inquiries_budget_check
  check (    (budget_min is null or budget_min >= 0)
         and (budget_max is null or budget_max >= 0)
         and (budget_min is null or budget_max is null or budget_max >= budget_min));
alter table public.event_inquiries drop constraint if exists event_inquiries_currency_check;
alter table public.event_inquiries add  constraint event_inquiries_currency_check
  check (currency in ('IQD', 'USD'));
alter table public.event_inquiries drop constraint if exists event_inquiries_text_check;
alter table public.event_inquiries add  constraint event_inquiries_text_check
  check (    (guest_name    is null or char_length(guest_name)    <= 100)
         and (guest_contact is null or guest_contact ~ '^[0-9+() -]{7,25}$')
         and (city          is null or char_length(city)          <= 80)
         and (area          is null or char_length(area)          <= 120)
         and (style         is null or char_length(style)         <= 500)
         and (notes         is null or char_length(notes)         <= 2000)
         and cardinality(services) <= 20);

create unique index if not exists uq_event_inquiries_reference on public.event_inquiries (reference_code);
create index if not exists idx_event_inquiries_customer on public.event_inquiries (customer_id, created_at desc);
create index if not exists idx_event_inquiries_status   on public.event_inquiries (status, created_at desc);
create index if not exists idx_event_inquiries_ip       on public.event_inquiries (ip_hash, created_at desc);

-- ═════════════════════════════════════════════════════════════════════════════
-- provider_profile_views — raw events for real (never invented) analytics.
-- Written only via public.record_provider_view().
-- ═════════════════════════════════════════════════════════════════════════════
create table if not exists public.provider_profile_views (
  id          bigint      generated always as identity primary key,
  provider_id uuid        not null references public.providers (id) on delete cascade,
  viewer_id   uuid        references public.profiles (id) on delete set null,
  viewer_hash text,
  viewed_at   timestamptz not null default now()
);

create index if not exists idx_provider_views_provider on public.provider_profile_views (provider_id, viewed_at desc);

-- ═════════════════════════════════════════════════════════════════════════════
-- Role helpers (used by RLS policies — must live in an API-visible schema
-- and be SECURITY DEFINER so they don't recurse through RLS).
-- ═════════════════════════════════════════════════════════════════════════════
create or replace function public.current_app_role()
returns text
language sql stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean
language sql stable
security definer
set search_path = ''
as $$
  select coalesce((select role = 'admin' from public.profiles where id = auth.uid()), false)
$$;

create or replace function public.owns_provider(p_provider_id uuid)
returns boolean
language sql stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.providers
    where id = p_provider_id and user_id is not null and user_id = auth.uid()
  )
$$;

create or replace function public.is_public_provider(p_provider_id uuid)
returns boolean
language sql stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.providers where id = p_provider_id and status = 'published')
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- Triggers
-- ═════════════════════════════════════════════════════════════════════════════

-- profiles: created automatically for every new auth user --------------------
create or replace function sawa_private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_role text  := v_meta ->> 'role';
  v_name text  := nullif(trim(coalesce(v_meta ->> 'full_name', v_meta ->> 'display_name', '')), '');
  v_phone text := sawa_private.normalize_digits(v_meta ->> 'phone');
begin
  -- Only customer/provider may be self-selected. 'admin' is never accepted
  -- from signup metadata.
  if v_role is null or v_role not in ('customer', 'provider') then
    v_role := 'customer';
  end if;

  insert into public.profiles (id, email, full_name, phone, role)
  values (new.id, new.email, left(v_name, 120), left(v_phone, 30), v_role)
  on conflict (id) do nothing;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function sawa_private.handle_new_user();

-- keep profiles.email in sync with auth ---------------------------------------
create or replace function sawa_private.sync_user_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is distinct from old.email then
    update public.profiles set email = new.email where id = new.id;
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_email_updated on auth.users;
create trigger on_auth_user_email_updated
  after update of email on auth.users
  for each row execute function sawa_private.sync_user_email();

-- Backfill profiles for auth users created before this migration.
insert into public.profiles (id, email, full_name, role)
select u.id,
       u.email,
       left(nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'display_name', '')), ''), 120),
       case when u.raw_user_meta_data ->> 'role' in ('customer', 'provider')
            then u.raw_user_meta_data ->> 'role' else 'customer' end
from auth.users u
on conflict (id) do nothing;

-- profiles guard: clients may only change full_name / phone / avatar_url ------
create or replace function sawa_private.profiles_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  if sawa_private.is_client_request() and not public.is_admin() then
    if (to_jsonb(new) - array['full_name', 'phone', 'avatar_url', 'updated_at'])
       is distinct from
       (to_jsonb(old) - array['full_name', 'phone', 'avatar_url', 'updated_at']) then
      raise exception 'immutable_field' using errcode = '42501',
        hint = 'Only full_name, phone and avatar_url can be changed.';
    end if;
    new.phone := left(sawa_private.normalize_digits(new.phone), 30);
  end if;
  return new;
end $$;

drop trigger if exists trg_profiles_guard on public.profiles;
create trigger trg_profiles_guard
  before update on public.profiles
  for each row execute function sawa_private.profiles_guard();

-- providers guard: ownership, source and status workflow ----------------------
create or replace function sawa_private.providers_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();

  -- Trusted operators (SQL Editor / service role) and admins.
  if not sawa_private.is_client_request() or public.is_admin() then
    if new.status = 'published' and (tg_op = 'INSERT' or old.status is distinct from 'published') then
      new.published_at := coalesce(new.published_at, now());
    end if;
    if new.status = 'pending' and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
      new.submitted_at := coalesce(new.submitted_at, now());
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if coalesce(public.current_app_role(), '') <> 'provider' then
      raise exception 'provider_account_required' using errcode = '42501';
    end if;
    if new.status not in ('draft', 'pending') then
      raise exception 'invalid_status_transition' using errcode = '42501';
    end if;
    new.user_id      := auth.uid();
    new.source       := 'self_registered';
    new.source_ref   := null;
    new.legacy_id    := null;
    new.published_at := null;
    new.submitted_at := case when new.status = 'pending' then now() else null end;
    new.created_at   := now();
    return new;
  end if;

  -- UPDATE by the owner
  if    new.id           is distinct from old.id
     or new.user_id      is distinct from old.user_id
     or new.source       is distinct from old.source
     or new.source_ref   is distinct from old.source_ref
     or new.legacy_id    is distinct from old.legacy_id
     or new.published_at is distinct from old.published_at
     or new.created_at   is distinct from old.created_at then
    raise exception 'immutable_field' using errcode = '42501';
  end if;

  if old.status = 'suspended' then
    raise exception 'provider_suspended' using errcode = '42501';
  end if;

  if new.status is distinct from old.status then
    if not (   (old.status = 'draft'   and new.status = 'pending')
            or (old.status = 'pending' and new.status = 'draft')) then
      raise exception 'invalid_status_transition' using errcode = '42501';
    end if;
    new.submitted_at := case when new.status = 'pending' then now() else null end;
  else
    new.submitted_at := old.submitted_at;
  end if;

  return new;
end $$;

drop trigger if exists trg_providers_guard on public.providers;
create trigger trg_providers_guard
  before insert or update on public.providers
  for each row execute function sawa_private.providers_guard();

-- updated_at on the simple tables --------------------------------------------
drop trigger if exists trg_categories_touch on public.categories;
create trigger trg_categories_touch before update on public.categories
  for each row execute function sawa_private.touch_updated_at();

drop trigger if exists trg_provider_private_touch on public.provider_private;
create trigger trg_provider_private_touch before update on public.provider_private
  for each row execute function sawa_private.touch_updated_at();

drop trigger if exists trg_provider_field_sources_touch on public.provider_field_sources;
create trigger trg_provider_field_sources_touch before update on public.provider_field_sources
  for each row execute function sawa_private.touch_updated_at();

drop trigger if exists trg_services_touch on public.services;
create trigger trg_services_touch before update on public.services
  for each row execute function sawa_private.touch_updated_at();

drop trigger if exists trg_provider_packages_touch on public.provider_packages;
create trigger trg_provider_packages_touch before update on public.provider_packages
  for each row execute function sawa_private.touch_updated_at();

-- event_inquiries: insert defaults + validation + rate limit, update guard ----
-- (sawa_private.assert_rate_limit is defined in migration 200; plpgsql
-- resolves it at call time, so creation order is fine.)
create or replace function sawa_private.event_inquiries_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.guest_name    := nullif(left(trim(coalesce(new.guest_name, '')), 100), '');
  new.guest_contact := sawa_private.normalize_digits(new.guest_contact);
  new.city          := nullif(trim(coalesce(new.city, '')), '');
  new.area          := nullif(trim(coalesce(new.area, '')), '');
  new.style         := nullif(trim(coalesce(new.style, '')), '');
  new.notes         := nullif(trim(coalesce(new.notes, '')), '');
  new.services      := coalesce(new.services, '{}');

  if sawa_private.is_client_request() then
    new.customer_id    := auth.uid();
    new.status         := 'open';
    new.reference_code := sawa_private.gen_reference('EV');
    new.ip_hash        := sawa_private.request_ip_hash();
    new.created_at     := now();
    new.updated_at     := now();

    if new.customer_id is null and new.guest_contact is null then
      raise exception 'contact_required' using errcode = '22023';
    end if;
    if new.event_date is not null and new.event_date < current_date then
      raise exception 'event_date_in_past' using errcode = '22023';
    end if;

    perform sawa_private.assert_rate_limit('inquiry', new.customer_id, new.guest_contact, new.ip_hash, null);
  else
    new.reference_code := coalesce(new.reference_code, sawa_private.gen_reference('EV'));
  end if;

  if exists (select 1 from unnest(new.services) s
             where not exists (select 1 from public.categories c where c.id = s)) then
    raise exception 'unknown_service_category' using errcode = '22023';
  end if;

  return new;
end $$;

drop trigger if exists trg_event_inquiries_before_insert on public.event_inquiries;
create trigger trg_event_inquiries_before_insert
  before insert on public.event_inquiries
  for each row execute function sawa_private.event_inquiries_before_insert();

create or replace function sawa_private.event_inquiries_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  if sawa_private.is_client_request() and not public.is_admin() then
    if (to_jsonb(new) - array['status', 'updated_at']) is distinct from (to_jsonb(old) - array['status', 'updated_at']) then
      raise exception 'immutable_field' using errcode = '42501';
    end if;
    if new.status is distinct from old.status
       and not (new.status = 'cancelled' and old.status in ('open', 'in_review')) then
      raise exception 'invalid_status_transition' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_event_inquiries_guard on public.event_inquiries;
create trigger trg_event_inquiries_guard
  before update on public.event_inquiries
  for each row execute function sawa_private.event_inquiries_guard();

-- Internal helpers are not callable by API roles.
revoke all on all functions in schema sawa_private from public;
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<< 20260924000100_core_schema.sql

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 20260924000200_contact_requests_v2.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — Migration 200: contact_requests v2 (non-destructive upgrade)
-- ═════════════════════════════════════════════════════════════════════════════
-- The live table already holds real submissions. This migration:
--   1. snapshots it into sawa_private (once),
--   2. only ADDS columns (all existing columns and rows are kept),
--   3. backfills the new NOT NULL columns for existing rows,
--   4. adds server-side defaults, validation, anti-spam and rate limiting.
--
-- Backward compatible: the v1 Flutter app keeps inserting
--   { provider_id, user_name, user_contact, note, created_at }
-- as anon and keeps working. Everything else is filled in by the trigger.
--
-- Flow model (locked decision): Customer → SAWA → Provider.
-- A provider sees a request only after the SAWA team forwards it
-- (forwarded_to_provider_at). Guests can submit but never read requests.
-- ═════════════════════════════════════════════════════════════════════════════

-- The original v1 table (no-op on the live project, where it already exists).
create table if not exists public.contact_requests (
  id           bigint       generated always as identity primary key,
  provider_id  text         not null check (provider_id <> ''),
  user_name    text         not null check (user_name <> ''),
  user_contact text         not null check (user_contact <> ''),
  note         text         check (note is null or length(trim(note)) > 0),
  created_at   timestamptz  not null default now()
);

-- 1. One-time snapshot of the pre-v2 data ------------------------------------
create table if not exists sawa_private.contact_requests_backup_v1
  as table public.contact_requests;

comment on table sawa_private.contact_requests_backup_v1 is
  'Snapshot of public.contact_requests taken before the v2 migration. Not exposed via the API.';

-- 2. New columns (additive only) ----------------------------------------------
alter table public.contact_requests add column if not exists reference_code           text;
alter table public.contact_requests add column if not exists customer_id              uuid;
alter table public.contact_requests add column if not exists provider_uuid            uuid;
alter table public.contact_requests add column if not exists inquiry_id               bigint;
alter table public.contact_requests add column if not exists service_id               uuid;
alter table public.contact_requests add column if not exists status                   text;
alter table public.contact_requests add column if not exists channel                  text;
alter table public.contact_requests add column if not exists ip_hash                  text;
alter table public.contact_requests add column if not exists is_spam                  boolean;
alter table public.contact_requests add column if not exists forwarded_to_provider_at timestamptz;
alter table public.contact_requests add column if not exists handled_by               uuid;
alter table public.contact_requests add column if not exists admin_notes              text;
alter table public.contact_requests add column if not exists updated_at               timestamptz;

comment on column public.contact_requests.provider_id is
  'v1 text key (legacy providers.json id). For v2 rows it mirrors providers.legacy_id or providers.id.';
comment on column public.contact_requests.note is
  'The customer message (optional).';
comment on column public.contact_requests.user_contact is
  'Customer phone/WhatsApp. Private: visible only to the customer, SAWA admins, and the provider after SAWA forwards the request.';

-- 3. Backfill existing rows ---------------------------------------------------
update public.contact_requests
   set reference_code = sawa_private.gen_reference('SW')
 where reference_code is null;
update public.contact_requests set status     = 'new'                              where status is null;
update public.contact_requests set channel    = case when customer_id is null then 'guest' else 'customer' end
                                                                                    where channel is null;
update public.contact_requests set is_spam    = false                              where is_spam is null;
update public.contact_requests set updated_at = created_at                         where updated_at is null;

alter table public.contact_requests alter column reference_code set not null;
alter table public.contact_requests alter column status         set not null;
alter table public.contact_requests alter column status         set default 'new';
alter table public.contact_requests alter column channel        set not null;
alter table public.contact_requests alter column channel        set default 'guest';
alter table public.contact_requests alter column is_spam        set not null;
alter table public.contact_requests alter column is_spam        set default false;
alter table public.contact_requests alter column updated_at     set not null;
alter table public.contact_requests alter column updated_at     set default now();

-- Link legacy rows to providers once providers are seeded (no-op until then;
-- also re-run by the seed migration in Phase 7).
update public.contact_requests cr
   set provider_uuid = p.id
  from public.providers p
 where cr.provider_uuid is null
   and p.legacy_id = cr.provider_id;

-- 4. Constraints --------------------------------------------------------------
alter table public.contact_requests drop constraint if exists contact_requests_status_check;
alter table public.contact_requests add  constraint contact_requests_status_check
  check (status in ('new', 'viewed', 'contacted', 'completed', 'cancelled'));
alter table public.contact_requests drop constraint if exists contact_requests_channel_check;
alter table public.contact_requests add  constraint contact_requests_channel_check
  check (channel in ('guest', 'customer'));

-- Input rules for NEW rows (name/phone/message format) are enforced in the
-- insert trigger below rather than as CHECK constraints: a CHECK — even
-- NOT VALID — is re-evaluated on every UPDATE, which would block status
-- changes on legacy rows that pre-date these rules.
alter table public.contact_requests drop constraint if exists contact_requests_input_check;
alter table public.contact_requests drop constraint if exists contact_requests_admin_notes_check;
alter table public.contact_requests add  constraint contact_requests_admin_notes_check
  check (admin_notes is null or char_length(admin_notes) <= 4000);

alter table public.contact_requests drop constraint if exists contact_requests_customer_fk;
alter table public.contact_requests add  constraint contact_requests_customer_fk
  foreign key (customer_id) references public.profiles (id) on delete set null;
alter table public.contact_requests drop constraint if exists contact_requests_provider_fk;
alter table public.contact_requests add  constraint contact_requests_provider_fk
  foreign key (provider_uuid) references public.providers (id) on delete set null;
alter table public.contact_requests drop constraint if exists contact_requests_inquiry_fk;
alter table public.contact_requests add  constraint contact_requests_inquiry_fk
  foreign key (inquiry_id) references public.event_inquiries (id) on delete set null;
alter table public.contact_requests drop constraint if exists contact_requests_service_fk;
alter table public.contact_requests add  constraint contact_requests_service_fk
  foreign key (service_id) references public.services (id) on delete set null;
alter table public.contact_requests drop constraint if exists contact_requests_handled_by_fk;
alter table public.contact_requests add  constraint contact_requests_handled_by_fk
  foreign key (handled_by) references public.profiles (id) on delete set null;

-- 5. Indexes ------------------------------------------------------------------
create unique index if not exists uq_contact_requests_reference on public.contact_requests (reference_code);
create index if not exists idx_contact_requests_customer      on public.contact_requests (customer_id, created_at desc);
create index if not exists idx_contact_requests_provider_uuid on public.contact_requests (provider_uuid, created_at desc);
create index if not exists idx_contact_requests_inquiry       on public.contact_requests (inquiry_id);
create index if not exists idx_contact_requests_status        on public.contact_requests (status, created_at desc);
create index if not exists idx_contact_requests_ip            on public.contact_requests (ip_hash, created_at desc);
create index if not exists idx_contact_requests_contact       on public.contact_requests (user_contact, created_at desc);
-- (idx_contact_requests_provider_id / _created_at from v1 are kept as-is.)

-- ═════════════════════════════════════════════════════════════════════════════
-- Rate limiting / anti-spam (server-side, applies to every insert path)
-- ═════════════════════════════════════════════════════════════════════════════
create or replace function sawa_private.assert_rate_limit(
  p_kind         text,
  p_customer_id  uuid,
  p_contact      text,
  p_ip_hash      text,
  p_provider_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_digits text := sawa_private.digits_only(p_contact);
  v_n      int;
begin
  if p_kind = 'contact' then
    -- Same person asking the same provider again within 10 minutes.
    if v_digits is not null and p_provider_key is not null and exists (
         select 1 from public.contact_requests
          where provider_id = p_provider_key
            and regexp_replace(user_contact, '\D', '', 'g') = v_digits
            and created_at > now() - interval '10 minutes') then
      raise exception 'duplicate_request' using errcode = 'P0001',
        hint = 'A request to this provider was already sent a few minutes ago.';
    end if;

    if p_ip_hash is not null then
      select count(*) into v_n from public.contact_requests
       where ip_hash = p_ip_hash and created_at > now() - interval '1 hour';
      if v_n >= 10 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;

    if v_digits is not null then
      select count(*) into v_n from public.contact_requests
       where regexp_replace(user_contact, '\D', '', 'g') = v_digits
         and created_at > now() - interval '1 hour';
      if v_n >= 5 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;

    if p_customer_id is not null then
      select count(*) into v_n from public.contact_requests
       where customer_id = p_customer_id and created_at > now() - interval '1 hour';
      if v_n >= 20 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;

  elsif p_kind = 'inquiry' then
    if p_ip_hash is not null then
      select count(*) into v_n from public.event_inquiries
       where ip_hash = p_ip_hash and created_at > now() - interval '1 hour';
      if v_n >= 10 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;

    if v_digits is not null then
      select count(*) into v_n from public.event_inquiries
       where regexp_replace(guest_contact, '\D', '', 'g') = v_digits
         and created_at > now() - interval '1 hour';
      if v_n >= 5 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;

    if p_customer_id is not null then
      select count(*) into v_n from public.event_inquiries
       where customer_id = p_customer_id and created_at > now() - interval '1 hour';
      if v_n >= 10 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;
  end if;
end $$;

-- ═════════════════════════════════════════════════════════════════════════════
-- Insert trigger: server owns every sensitive column for client inserts.
-- ═════════════════════════════════════════════════════════════════════════════
create or replace function sawa_private.contact_requests_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider public.providers%rowtype;
  v_inquiry  public.event_inquiries%rowtype;
begin
  -- Normalise input for every insert path.
  new.user_name    := trim(coalesce(new.user_name, ''));
  new.user_contact := sawa_private.normalize_digits(new.user_contact);
  new.note         := nullif(trim(coalesce(new.note, '')), '');

  -- Resolve the provider from either key.
  if new.provider_uuid is not null then
    select * into v_provider from public.providers where id = new.provider_uuid;
  elsif new.provider_id is not null then
    select * into v_provider from public.providers
     where legacy_id = new.provider_id or id::text = new.provider_id
     limit 1;
  end if;

  if v_provider.id is not null then
    new.provider_uuid := v_provider.id;
    new.provider_id   := coalesce(v_provider.legacy_id, v_provider.id::text);
  end if;

  if not sawa_private.is_client_request() then
    new.reference_code := coalesce(new.reference_code, sawa_private.gen_reference('SW'));
    new.channel        := coalesce(new.channel, case when new.customer_id is null then 'guest' else 'customer' end);
    return new;
  end if;

  -- ── Client (anon / authenticated) insert ───────────────────────────────
  if new.user_name = '' or char_length(new.user_name) > 100 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if new.user_contact is null
     or new.user_contact !~ '^[0-9+() -]{7,25}$'
     or char_length(regexp_replace(new.user_contact, '\D', '', 'g')) not between 7 and 15 then
    raise exception 'invalid_contact' using errcode = '22023';
  end if;
  if new.note is not null and char_length(new.note) > 2000 then
    raise exception 'message_too_long' using errcode = '22023';
  end if;

  if new.provider_id is null or new.provider_id = '' then
    raise exception 'provider_required' using errcode = '22023';
  end if;
  -- A known provider must be publicly listed. (Unknown legacy ids are still
  -- accepted so the v1 app keeps working until providers are seeded.)
  if v_provider.id is not null and v_provider.status <> 'published' then
    raise exception 'provider_not_available' using errcode = '22023';
  end if;
  if new.provider_uuid is not null and v_provider.id is null then
    raise exception 'provider_not_available' using errcode = '22023';
  end if;

  new.customer_id              := auth.uid();
  new.channel                  := case when new.customer_id is null then 'guest' else 'customer' end;
  new.reference_code           := sawa_private.gen_reference('SW');
  new.status                   := 'new';
  new.is_spam                  := false;
  new.forwarded_to_provider_at := null;
  new.handled_by               := null;
  new.admin_notes              := null;
  new.ip_hash                  := sawa_private.request_ip_hash();
  new.created_at               := now();
  new.updated_at               := now();

  -- Optional links must belong to this request.
  if new.service_id is not null and not exists (
       select 1 from public.services s
        where s.id = new.service_id and s.provider_id = new.provider_uuid and s.is_active) then
    raise exception 'invalid_service' using errcode = '22023';
  end if;

  if new.inquiry_id is not null then
    select * into v_inquiry from public.event_inquiries where id = new.inquiry_id;
    if v_inquiry.id is null then
      raise exception 'invalid_inquiry' using errcode = '22023';
    end if;
    if v_inquiry.customer_id is not null then
      if v_inquiry.customer_id is distinct from new.customer_id then
        raise exception 'invalid_inquiry' using errcode = '22023';
      end if;
    else
      -- Guest inquiry: only the same guest (same phone), shortly after.
      if new.customer_id is not null
         or sawa_private.digits_only(v_inquiry.guest_contact) is distinct from sawa_private.digits_only(new.user_contact)
         or v_inquiry.created_at < now() - interval '24 hours' then
        raise exception 'invalid_inquiry' using errcode = '22023';
      end if;
    end if;
  end if;

  perform sawa_private.assert_rate_limit('contact', new.customer_id, new.user_contact, new.ip_hash, new.provider_id);
  return new;
end $$;

drop trigger if exists trg_contact_requests_before_insert on public.contact_requests;
create trigger trg_contact_requests_before_insert
  before insert on public.contact_requests
  for each row execute function sawa_private.contact_requests_before_insert();

-- ═════════════════════════════════════════════════════════════════════════════
-- Update guard: clients may only move `status`, within their own role.
-- ═════════════════════════════════════════════════════════════════════════════
create or replace function sawa_private.contact_requests_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();

  if not sawa_private.is_client_request() or public.is_admin() then
    return new;
  end if;

  if (to_jsonb(new) - array['status', 'updated_at']) is distinct from (to_jsonb(old) - array['status', 'updated_at']) then
    raise exception 'immutable_field' using errcode = '42501';
  end if;

  if new.status is not distinct from old.status then
    return new;
  end if;

  -- The customer who sent it may cancel it while it is still open.
  if old.customer_id is not null and old.customer_id = auth.uid() then
    if new.status = 'cancelled' and old.status in ('new', 'viewed') then
      return new;
    end if;
    raise exception 'invalid_status_transition' using errcode = '42501';
  end if;

  -- The owning provider may progress a request SAWA forwarded to them.
  if old.forwarded_to_provider_at is not null and public.owns_provider(old.provider_uuid) then
    if new.status in ('viewed', 'contacted', 'completed', 'cancelled') then
      return new;
    end if;
    raise exception 'invalid_status_transition' using errcode = '42501';
  end if;

  raise exception 'not_allowed' using errcode = '42501';
end $$;

drop trigger if exists trg_contact_requests_guard on public.contact_requests;
create trigger trg_contact_requests_guard
  before update on public.contact_requests
  for each row execute function sawa_private.contact_requests_guard();

revoke all on all functions in schema sawa_private from public;
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<< 20260924000200_contact_requests_v2.sql

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 20260924000300_rls_policies.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — Migration 300: privileges + Row-Level Security
-- ═════════════════════════════════════════════════════════════════════════════
-- Security is enforced HERE, never by client-side role checks.
--
--   anon          → published catalogue only; may submit a contact request.
--   customer      → own profile, own inquiries, own requests.
--   provider      → own business (+ private data, services, packages,
--                   images), requests SAWA forwarded to that business.
--   admin         → everything (profiles.role = 'admin', set by an operator).
--
-- Column-level rules (what a client may change) are enforced by the guard
-- triggers in migrations 100/200.
-- Idempotent: every policy is dropped and recreated.
-- ═════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Privileges: start from nothing, grant exactly what the app needs.
--    (Supabase grants ALL to anon/authenticated by default.)
-- ─────────────────────────────────────────────────────────────────────────────
revoke all on table
  public.profiles, public.categories, public.providers, public.provider_private,
  public.provider_field_sources, public.provider_images, public.services,
  public.provider_packages, public.event_inquiries, public.contact_requests,
  public.provider_profile_views
from anon, authenticated;

-- Public catalogue (rows still filtered by RLS).
grant select on public.categories, public.providers, public.provider_field_sources,
                public.provider_images, public.services, public.provider_packages
  to anon, authenticated;

-- Authenticated writes (RLS decides whose rows; admin-only where noted).
grant insert, update, delete on public.categories, public.provider_field_sources to authenticated; -- admin only (RLS)
grant insert, update, delete on public.providers, public.provider_images,
                                public.services, public.provider_packages       to authenticated;
grant select, insert, update, delete on public.provider_private                 to authenticated;
grant select, update on public.profiles                                         to authenticated;
grant select, update on public.event_inquiries                                  to authenticated; -- inserts via RPC
grant select, update on public.contact_requests                                 to authenticated;
grant select on public.provider_profile_views                                   to authenticated; -- inserts via RPC

-- Legacy direct insert used by the v1 app (guest + signed-in). The insert
-- trigger owns every sensitive column. To be narrowed to the RPC in Phase 5.
grant insert on public.contact_requests to anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Enable RLS everywhere.
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.profiles               enable row level security;
alter table public.categories             enable row level security;
alter table public.providers              enable row level security;
alter table public.provider_private       enable row level security;
alter table public.provider_field_sources enable row level security;
alter table public.provider_images        enable row level security;
alter table public.services               enable row level security;
alter table public.provider_packages      enable row level security;
alter table public.event_inquiries        enable row level security;
alter table public.contact_requests       enable row level security;
alter table public.provider_profile_views enable row level security;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Remove v1 policies.
--    "authenticated_read_only" let ANY signed-in user read every request —
--    the Critical finding from the QA audit.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "anon_insert_only"            on public.contact_requests;
drop policy if exists "authenticated_read_only"     on public.contact_requests;
drop policy if exists "profiles_own_read"           on public.profiles;
drop policy if exists "profiles_own_write"          on public.profiles;
drop policy if exists "profiles_own_update"         on public.profiles;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Policies
-- ─────────────────────────────────────────────────────────────────────────────

-- profiles --------------------------------------------------------------------
drop policy if exists profiles_self_read   on public.profiles;
drop policy if exists profiles_self_update on public.profiles;
drop policy if exists profiles_admin_all   on public.profiles;

create policy profiles_self_read on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_self_update on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy profiles_admin_all on public.profiles
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- categories ------------------------------------------------------------------
drop policy if exists categories_public_read on public.categories;
drop policy if exists categories_admin_all   on public.categories;

create policy categories_public_read on public.categories
  for select to anon, authenticated
  using (is_active);

create policy categories_admin_all on public.categories
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- providers -------------------------------------------------------------------
drop policy if exists providers_public_read  on public.providers;
drop policy if exists providers_owner_read   on public.providers;
drop policy if exists providers_owner_insert on public.providers;
drop policy if exists providers_owner_update on public.providers;
drop policy if exists providers_owner_delete on public.providers;
drop policy if exists providers_admin_all    on public.providers;

create policy providers_public_read on public.providers
  for select to anon, authenticated
  using (status = 'published');

create policy providers_owner_read on public.providers
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy providers_owner_insert on public.providers
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy providers_owner_update on public.providers
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy providers_owner_delete on public.providers
  for delete to authenticated
  using (user_id = (select auth.uid()) and status = 'draft');

create policy providers_admin_all on public.providers
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- provider_private (owner + admin only; never public) ------------------------
drop policy if exists provider_private_owner_all on public.provider_private;
drop policy if exists provider_private_admin_all on public.provider_private;

create policy provider_private_owner_all on public.provider_private
  for all to authenticated
  using (public.owns_provider(provider_id))
  with check (public.owns_provider(provider_id));

create policy provider_private_admin_all on public.provider_private
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- provider_field_sources (public for published listings; admin writes) --------
drop policy if exists provider_field_sources_public_read on public.provider_field_sources;
drop policy if exists provider_field_sources_owner_read  on public.provider_field_sources;
drop policy if exists provider_field_sources_admin_all   on public.provider_field_sources;

create policy provider_field_sources_public_read on public.provider_field_sources
  for select to anon, authenticated
  using (public.is_public_provider(provider_id));

create policy provider_field_sources_owner_read on public.provider_field_sources
  for select to authenticated
  using (public.owns_provider(provider_id));

create policy provider_field_sources_admin_all on public.provider_field_sources
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- provider_images -------------------------------------------------------------
drop policy if exists provider_images_public_read on public.provider_images;
drop policy if exists provider_images_owner_all   on public.provider_images;
drop policy if exists provider_images_admin_all   on public.provider_images;

create policy provider_images_public_read on public.provider_images
  for select to anon, authenticated
  using (public.is_public_provider(provider_id));

create policy provider_images_owner_all on public.provider_images
  for all to authenticated
  using (public.owns_provider(provider_id))
  with check (public.owns_provider(provider_id));

create policy provider_images_admin_all on public.provider_images
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- services --------------------------------------------------------------------
drop policy if exists services_public_read on public.services;
drop policy if exists services_owner_all   on public.services;
drop policy if exists services_admin_all   on public.services;

create policy services_public_read on public.services
  for select to anon, authenticated
  using (is_active and public.is_public_provider(provider_id));

create policy services_owner_all on public.services
  for all to authenticated
  using (public.owns_provider(provider_id))
  with check (public.owns_provider(provider_id));

create policy services_admin_all on public.services
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- provider_packages -----------------------------------------------------------
drop policy if exists provider_packages_public_read on public.provider_packages;
drop policy if exists provider_packages_owner_all   on public.provider_packages;
drop policy if exists provider_packages_admin_all   on public.provider_packages;

create policy provider_packages_public_read on public.provider_packages
  for select to anon, authenticated
  using (is_active and public.is_public_provider(provider_id));

create policy provider_packages_owner_all on public.provider_packages
  for all to authenticated
  using (public.owns_provider(provider_id))
  with check (public.owns_provider(provider_id));

create policy provider_packages_admin_all on public.provider_packages
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- event_inquiries (customer's own; created via RPC) ---------------------------
drop policy if exists event_inquiries_self_read   on public.event_inquiries;
drop policy if exists event_inquiries_self_update on public.event_inquiries;
drop policy if exists event_inquiries_admin_all   on public.event_inquiries;

create policy event_inquiries_self_read on public.event_inquiries
  for select to authenticated
  using (customer_id = (select auth.uid()));

create policy event_inquiries_self_update on public.event_inquiries
  for update to authenticated
  using (customer_id = (select auth.uid()))
  with check (customer_id = (select auth.uid()));

create policy event_inquiries_admin_all on public.event_inquiries
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- contact_requests ------------------------------------------------------------
drop policy if exists contact_requests_guest_insert     on public.contact_requests;
drop policy if exists contact_requests_customer_insert  on public.contact_requests;
drop policy if exists contact_requests_customer_read    on public.contact_requests;
drop policy if exists contact_requests_customer_update  on public.contact_requests;
drop policy if exists contact_requests_provider_read    on public.contact_requests;
drop policy if exists contact_requests_provider_update  on public.contact_requests;
drop policy if exists contact_requests_admin_all        on public.contact_requests;

-- Guests: insert only, never linked to an account.
create policy contact_requests_guest_insert on public.contact_requests
  for insert to anon
  with check (customer_id is null);

-- Signed-in users: the trigger stamps customer_id = auth.uid().
create policy contact_requests_customer_insert on public.contact_requests
  for insert to authenticated
  with check (customer_id = (select auth.uid()));

create policy contact_requests_customer_read on public.contact_requests
  for select to authenticated
  using (customer_id = (select auth.uid()));

create policy contact_requests_customer_update on public.contact_requests
  for update to authenticated
  using (customer_id = (select auth.uid()))
  with check (customer_id = (select auth.uid()));

-- Providers: only requests SAWA has forwarded to a business they own.
create policy contact_requests_provider_read on public.contact_requests
  for select to authenticated
  using (forwarded_to_provider_at is not null and public.owns_provider(provider_uuid));

create policy contact_requests_provider_update on public.contact_requests
  for update to authenticated
  using (forwarded_to_provider_at is not null and public.owns_provider(provider_uuid))
  with check (forwarded_to_provider_at is not null and public.owns_provider(provider_uuid));

create policy contact_requests_admin_all on public.contact_requests
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- provider_profile_views (owner + admin read; written via RPC) ----------------
drop policy if exists provider_views_owner_read on public.provider_profile_views;
drop policy if exists provider_views_admin_read on public.provider_profile_views;

create policy provider_views_owner_read on public.provider_profile_views
  for select to authenticated
  using (public.owns_provider(provider_id));

create policy provider_views_admin_read on public.provider_profile_views
  for select to authenticated
  using ((select public.is_admin()));
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<< 20260924000300_rls_policies.sql

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 20260924000400_rpc.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — Migration 400: RPC functions (the v2 app's write API)
-- ═════════════════════════════════════════════════════════════════════════════
-- SECURITY DEFINER functions with an empty search_path. They never trust the
-- caller for identity: customer_id always comes from auth.uid() (enforced by
-- the insert triggers, which also run inside these functions).
-- ═════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- submit_contact_request — guest or signed-in customer → a published provider.
-- Returns the reference so the guest gets a real confirmation without any
-- read access to the table.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.submit_contact_request(
  p_provider_id uuid,
  p_name        text,
  p_contact     text,
  p_message     text   default null,
  p_inquiry_id  bigint default null,
  p_service_id  uuid   default null
)
returns table (reference_code text, created_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if p_provider_id is null then
    raise exception 'provider_required' using errcode = '22023';
  end if;

  return query
  insert into public.contact_requests as cr
    (provider_id, provider_uuid, user_name, user_contact, note, inquiry_id, service_id)
  values
    (p_provider_id::text, p_provider_id, p_name, p_contact, p_message, p_inquiry_id, p_service_id)
  returning cr.reference_code, cr.created_at;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- create_event_inquiry — planner submission (guest needs a contact number).
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.create_event_inquiry(
  p_event_type    text,
  p_guest_count   int           default null,
  p_city          text          default null,
  p_area          text          default null,
  p_event_date    date          default null,
  p_budget_min    numeric       default null,
  p_budget_max    numeric       default null,
  p_currency      text          default 'IQD',
  p_services      text[]        default '{}',
  p_style         text          default null,
  p_notes         text          default null,
  p_guest_name    text          default null,
  p_guest_contact text          default null
)
returns table (id bigint, reference_code text, created_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  return query
  insert into public.event_inquiries as ei
    (event_type, guest_count, city, area, event_date, budget_min, budget_max,
     currency, services, style, notes, guest_name, guest_contact, reference_code)
  values
    (p_event_type, p_guest_count, p_city, p_area, p_event_date, p_budget_min, p_budget_max,
     coalesce(p_currency, 'IQD'), coalesce(p_services, '{}'), p_style, p_notes,
     p_guest_name, p_guest_contact, null)   -- reference_code is generated by the trigger
  returning ei.id, ei.reference_code, ei.created_at;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- record_provider_view — real profile-view events, de-duplicated per viewer
-- (account or hashed network) for 30 minutes. Owners viewing themselves are
-- not counted.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.record_provider_view(p_provider_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_hash text := sawa_private.request_ip_hash();
begin
  if not exists (select 1 from public.providers where id = p_provider_id and status = 'published') then
    return;
  end if;
  if v_uid is not null and exists (select 1 from public.providers where id = p_provider_id and user_id = v_uid) then
    return;
  end if;
  if exists (
       select 1 from public.provider_profile_views v
        where v.provider_id = p_provider_id
          and v.viewed_at > now() - interval '30 minutes'
          and (   (v_uid is not null and v.viewer_id = v_uid)
               or (v_uid is null and v_hash is not null and v.viewer_id is null and v.viewer_hash = v_hash))) then
    return;
  end if;

  insert into public.provider_profile_views (provider_id, viewer_id, viewer_hash)
  values (p_provider_id, v_uid, v_hash);
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- get_provider_stats — dashboard numbers computed from real rows only.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.get_provider_stats(p_provider_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.owns_provider(p_provider_id) or public.is_admin()) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'status',             (select status from public.providers where id = p_provider_id),
    'views_total',        (select count(*) from public.provider_profile_views where provider_id = p_provider_id),
    'views_last_30_days', (select count(*) from public.provider_profile_views
                            where provider_id = p_provider_id and viewed_at > now() - interval '30 days'),
    'requests_total',     (select count(*) from public.contact_requests
                            where provider_uuid = p_provider_id and forwarded_to_provider_at is not null),
    'requests_new',       (select count(*) from public.contact_requests
                            where provider_uuid = p_provider_id and forwarded_to_provider_at is not null
                              and status = 'new'),
    'services_active',    (select count(*) from public.services where provider_id = p_provider_id and is_active),
    'services_total',     (select count(*) from public.services where provider_id = p_provider_id)
  );
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Grants
-- ─────────────────────────────────────────────────────────────────────────────
-- Supabase's default privileges grant EXECUTE on new public functions
-- directly to anon/authenticated, so revoking from PUBLIC alone is not
-- enough — revoke from the API roles explicitly, then grant exactly.
revoke all on function public.submit_contact_request(uuid, text, text, text, bigint, uuid) from public, anon, authenticated;
revoke all on function public.create_event_inquiry(text, int, text, text, date, numeric, numeric, text, text[], text, text, text, text) from public, anon, authenticated;
revoke all on function public.record_provider_view(uuid) from public, anon, authenticated;
revoke all on function public.get_provider_stats(uuid) from public, anon, authenticated;

grant execute on function public.submit_contact_request(uuid, text, text, text, bigint, uuid) to anon, authenticated;
grant execute on function public.create_event_inquiry(text, int, text, text, date, numeric, numeric, text, text[], text, text, text, text) to anon, authenticated;
grant execute on function public.record_provider_view(uuid) to anon, authenticated;
grant execute on function public.get_provider_stats(uuid) to authenticated;

-- Policy helpers must stay callable by API roles (they only reveal facts
-- about the caller or about public rows).
grant execute on function public.is_admin()                  to anon, authenticated;
grant execute on function public.current_app_role()          to anon, authenticated;
grant execute on function public.owns_provider(uuid)         to anon, authenticated;
grant execute on function public.is_public_provider(uuid)    to anon, authenticated;
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<< 20260924000400_rpc.sql

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

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 20260924000600_seed_categories.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — Migration 600: category taxonomy
-- ═════════════════════════════════════════════════════════════════════════════
-- Categories may exist with zero providers — the app shows an honest empty
-- state. No providers are created here (real listings arrive in Phase 7).
-- Re-running updates names/icons/order but never re-activates a category an
-- operator has deactivated.
-- ═════════════════════════════════════════════════════════════════════════════

insert into public.categories (id, name_ar, name_en, icon_key, sort_order)
values
  ('halls',       'قاعات المناسبات',   'Wedding & Event Halls', 'building',    10),
  ('photography', 'التصوير',            'Photography',           'camera',      20),
  ('flowers',     'الورد والزهور',      'Flowers',               'flower',      30),
  ('decoration',  'الديكور والتنسيق',   'Decoration',            'sparkle',     40),
  ('beauty',      'التجميل',            'Beauty',                'makeup',      50),
  ('catering',    'الضيافة والطعام',    'Catering',              'fork_knife',  60),
  ('music',       'الموسيقى والفرق',    'Music & Bands',         'music',       70),
  ('cars',        'سيارات المناسبات',   'Event Cars',            'car',         80),
  ('invitations', 'الدعوات',            'Invitations',           'envelope',    90),
  ('other',       'خدمات أخرى',         'Other Event Services',  'dots',       100)
on conflict (id) do update
  set name_ar    = excluded.name_ar,
      name_en    = excluded.name_en,
      icon_key   = excluded.icon_key,
      sort_order = excluded.sort_order;
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<< 20260924000600_seed_categories.sql

commit;
