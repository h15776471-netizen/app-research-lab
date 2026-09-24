-- SAWA — contact_requests schema
-- Source: sawa-technical-architecture.md §8, SAWA_FINAL_MASTER_SPEC.md §24/§26
--
-- ─────────────────────────────────────────────────────────────────────────────
-- SETUP INSTRUCTIONS
-- ─────────────────────────────────────────────────────────────────────────────
--
-- 1. Create a free Supabase project at https://supabase.com (no card required).
--
-- 2. In Project Settings → API, copy:
--    • Project URL  →  use as SUPABASE_URL
--    • anon public  →  use as SUPABASE_ANON_KEY
--
-- 3. Open SQL Editor, paste and run this entire file.
--
-- 4. Run the smoke test at the bottom to verify RLS is correct.
--
-- 5. Pass the credentials at build/run time:
--
--    flutter run \
--      --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
--      --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
--
--    For release build:
--    flutter build web --release \
--      --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
--      --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
--
--    The app browses fully offline without these — only contact submission
--    requires them.  See sawaApp/lib/core/config/supabase_config.dart.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- SECURITY MODEL  (Master Spec §26)
-- ─────────────────────────────────────────────────────────────────────────────
--
-- Row-Level Security (RLS) is a whitelist: only operations that match an
-- explicit policy are allowed.  Every other operation is denied by default.
--
-- With the policies below:
--   anon  role  → INSERT only.  SELECT / UPDATE / DELETE → denied.
--   authenticated role  → SELECT only (team reads from Supabase dashboard).
--   service_role key    → bypasses RLS (never in the client app; only on
--                          the server side if needed later).
--
-- The anon key (SUPABASE_ANON_KEY) is safe to embed in the Flutter web bundle
-- because the RLS policy limits it to INSERT on this one table.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- DART MODEL ALIGNMENT
-- ─────────────────────────────────────────────────────────────────────────────
--
-- Dart ContactRequest.toJson() sends:
--   { "provider_id", "user_name", "user_contact", "note"?, "created_at" }
--
-- Column names below match exactly.  The "id" column is server-generated
-- (generated always as identity) — the client never sends it.

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.contact_requests (
  id            bigint       generated always as identity primary key,
  provider_id   text         not null check (provider_id <> ''),
  user_name     text         not null check (user_name <> ''),
  user_contact  text         not null check (user_contact <> ''),
  note          text         check (note is null or length(trim(note)) > 0),
  created_at    timestamptz  not null default now()
);

comment on table public.contact_requests is
  'Insert-only contact requests submitted by sawa users. '
  'Each row links a user to a provider they want to reach. '
  'The sawa team reads this via the Supabase dashboard; no client read access.';

comment on column public.contact_requests.provider_id  is 'Matches SawaProvider.id from providers.json.';
comment on column public.contact_requests.user_name    is 'User-supplied display name — never the provider name.';
comment on column public.contact_requests.user_contact is 'User phone / WhatsApp — how the sawa team reaches the user.';
comment on column public.contact_requests.note         is 'Optional free-text note (date, guest count, etc.). NULL when the user left the field blank.';

-- ─────────────────────────────────────────────────────────────────────────────
-- ROW-LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.contact_requests enable row level security;

-- Anon (Flutter app): INSERT only.
-- with check (true) means any row the app tries to insert passes the policy
-- check; the NOT NULL + CHECK constraints above are the real data guards.
drop policy if exists "anon_insert_only" on public.contact_requests;
create policy "anon_insert_only"
  on  public.contact_requests
  for insert
  to  anon
  with check (true);

-- Authenticated (Supabase dashboard / team): SELECT only.
-- No insert/update/delete policy for authenticated means those are also
-- denied for authenticated users via PostgREST (not just anon).
drop policy if exists "authenticated_read_only" on public.contact_requests;
create policy "authenticated_read_only"
  on  public.contact_requests
  for select
  to  authenticated
  using (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- INDEXES
-- ─────────────────────────────────────────────────────────────────────────────

create index if not exists idx_contact_requests_provider_id
  on public.contact_requests (provider_id);

create index if not exists idx_contact_requests_created_at
  on public.contact_requests (created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- SMOKE TEST  (run after setup)
-- ─────────────────────────────────────────────────────────────────────────────
--
-- Step 1 — Insert a test row (run from SQL Editor, authenticated):
--
--   insert into public.contact_requests (provider_id, user_name, user_contact, note)
--   values ('hall_ritaj_001', 'Test User', '07700000000', 'Smoke test — delete me');
--
-- Step 2 — Verify it appears:
--
--   select * from public.contact_requests order by created_at desc limit 5;
--
-- Step 3 — Delete the test row:
--
--   delete from public.contact_requests where note = 'Smoke test — delete me';
--
-- Step 4 — Verify anon cannot SELECT (optional, proves RLS blocks it):
--   Use the REST API with the anon key:
--     curl "https://xxxx.supabase.co/rest/v1/contact_requests" \
--       -H "apikey: YOUR_ANON_KEY" \
--       -H "Authorization: Bearer YOUR_ANON_KEY"
--   Expected: empty array [] (RLS blocks anon SELECT, returns 0 rows).
--
-- If step 4 returns actual rows, your RLS policy is misconfigured — do NOT
-- continue to demo until this is resolved.

-- ─────────────────────────────────────────────────────────────────────────────
-- PHASE 2 TABLES  (sawa platform redesign)
-- ─────────────────────────────────────────────────────────────────────────────

-- profiles: one row per Supabase Auth user; role = 'customer' | 'provider'
create table if not exists public.profiles (
  id           uuid         not null references auth.users(id) on delete cascade primary key,
  role         text         not null check (role in ('customer', 'provider')),
  display_name text         not null check (display_name <> ''),
  created_at   timestamptz  not null default now()
);

comment on table public.profiles is
  'One row per Supabase Auth user. Role drives routing (customer vs provider shell).';

alter table public.profiles enable row level security;

-- Each user can only read/write their own profile row.
drop policy if exists "profiles_own_read"  on public.profiles;
drop policy if exists "profiles_own_write" on public.profiles;

create policy "profiles_own_read"
  on  public.profiles for select
  to  authenticated
  using (id = auth.uid());

create policy "profiles_own_write"
  on  public.profiles for insert
  to  authenticated
  with check (id = auth.uid());

create policy "profiles_own_update"
  on  public.profiles for update
  to  authenticated
  using (id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────

-- provider_profiles: extended info for provider users
create table if not exists public.provider_profiles (
  id           uuid         not null references public.profiles(id) on delete cascade primary key,
  category     text         not null check (category in ('hall', 'photography', 'decor')),
  bio          text,
  city         text         not null default 'بغداد',
  created_at   timestamptz  not null default now()
);

comment on table public.provider_profiles is
  'Extended profile for users with role=provider.';

alter table public.provider_profiles enable row level security;

drop policy if exists "provider_profiles_own_read"   on public.provider_profiles;
drop policy if exists "provider_profiles_own_write"  on public.provider_profiles;
drop policy if exists "provider_profiles_own_update" on public.provider_profiles;

create policy "provider_profiles_own_read"
  on  public.provider_profiles for select
  to  authenticated
  using (id = auth.uid());

create policy "provider_profiles_own_write"
  on  public.provider_profiles for insert
  to  authenticated
  with check (id = auth.uid());

create policy "provider_profiles_own_update"
  on  public.provider_profiles for update
  to  authenticated
  using (id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────

-- services: services offered by a provider
create table if not exists public.services (
  id           uuid         not null default gen_random_uuid() primary key,
  provider_id  uuid         not null references public.profiles(id) on delete cascade,
  title        text         not null check (title <> ''),
  description  text         not null check (description <> ''),
  price_text   text,
  is_active    boolean      not null default true,
  created_at   timestamptz  not null default now()
);

comment on table public.services is
  'Services listed by a provider. provider_id = profiles.id of the provider user.';

create index if not exists idx_services_provider_id on public.services (provider_id);

alter table public.services enable row level security;

drop policy if exists "services_own_read"   on public.services;
drop policy if exists "services_own_insert" on public.services;
drop policy if exists "services_own_delete" on public.services;
drop policy if exists "services_public_read" on public.services;

-- Providers manage their own services.
create policy "services_own_read"
  on  public.services for select
  to  authenticated
  using (provider_id = auth.uid());

create policy "services_own_insert"
  on  public.services for insert
  to  authenticated
  with check (provider_id = auth.uid());

create policy "services_own_delete"
  on  public.services for delete
  to  authenticated
  using (provider_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────

-- event_inquiries: customer event planner submissions (for future use)
create table if not exists public.event_inquiries (
  id           bigint       generated always as identity primary key,
  user_id      uuid         references public.profiles(id) on delete set null,
  event_type   text         not null,
  services     text[]       not null default '{}',
  guest_count  int,
  notes        text,
  created_at   timestamptz  not null default now()
);

comment on table public.event_inquiries is
  'Customer event planner wizard submissions. user_id may be null for guests.';

alter table public.event_inquiries enable row level security;

drop policy if exists "event_inquiries_insert_anon"        on public.event_inquiries;
drop policy if exists "event_inquiries_insert_auth"        on public.event_inquiries;
drop policy if exists "event_inquiries_own_read"           on public.event_inquiries;

-- Guests can submit.
create policy "event_inquiries_insert_anon"
  on  public.event_inquiries for insert
  to  anon
  with check (user_id is null);

-- Authenticated users can submit.
create policy "event_inquiries_insert_auth"
  on  public.event_inquiries for insert
  to  authenticated
  with check (true);

-- Users can read their own inquiries.
create policy "event_inquiries_own_read"
  on  public.event_inquiries for select
  to  authenticated
  using (user_id = auth.uid());
