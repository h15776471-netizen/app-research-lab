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
