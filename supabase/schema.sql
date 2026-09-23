-- SAWA — contact_requests table
-- Source: sawa-technical-architecture.md §8, SAWA_FINAL_MASTER_SPEC.md §24/§26
--
-- Setup steps:
--   1. Create a new Supabase project at https://supabase.com (free tier, no card required)
--   2. In the SQL Editor, run this entire file
--   3. Verify: run the smoke-test query at the bottom
--   4. Copy your project URL and anon key from Project Settings → API
--   5. Pass them at build/run time:
--        flutter run \
--          --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
--          --dart-define=SUPABASE_ANON_KEY=xxxx
--      (or add them to a local .env file and use flutter_dotenv / your preferred tooling)
--
-- Security model (Master Spec §26):
--   - Client can only INSERT — no SELECT, UPDATE, or DELETE from the client
--   - RLS enabled; insert-only policy for the anon role
--   - User contact info (name, phone) is only readable from the Supabase dashboard

-- ─────────────────────────────────────────────────────────────────────────────
-- Table
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.contact_requests (
  id            bigint        generated always as identity primary key,
  provider_id   text          not null,
  user_name     text          not null,
  user_contact  text          not null,
  note          text,
  created_at    timestamptz   not null default now()
);

comment on table public.contact_requests is
  'Insert-only contact requests submitted by sawa users. '
  'Each row links a user (name + contact) to a provider they want to reach. '
  'Team reads this from the Supabase dashboard; client has no read access.';

-- ─────────────────────────────────────────────────────────────────────────────
-- Row-Level Security
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.contact_requests enable row level security;

-- Anon role: insert only — no read, no update, no delete
create policy "anon_insert_only"
  on public.contact_requests
  for insert
  to anon
  with check (true);

-- Authenticated role (team dashboard): full read access, no client writes
-- The team reads rows via the Supabase Table Editor (authenticated session),
-- not through the app client.
create policy "service_read"
  on public.contact_requests
  for select
  to authenticated
  using (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- Index
-- ─────────────────────────────────────────────────────────────────────────────

create index if not exists idx_contact_requests_provider_id
  on public.contact_requests (provider_id);

create index if not exists idx_contact_requests_created_at
  on public.contact_requests (created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- Smoke test (run after setup to verify RLS is correct)
-- ─────────────────────────────────────────────────────────────────────────────
--
-- From a psql shell or the SQL Editor (authenticated):
--
--   INSERT INTO public.contact_requests (provider_id, user_name, user_contact, note)
--   VALUES ('hall_ritaj_001', 'Test User', '07700000000', 'Smoke test — delete me');
--
--   SELECT * FROM public.contact_requests ORDER BY created_at DESC LIMIT 5;
--
-- Expected: the row appears. Delete it after verifying.
--
-- To verify the anon policy is INSERT-only (no leak):
--   From the anon key context, a SELECT should return 0 rows (RLS blocks it).
--   The app's ContactRequestRepository never issues a SELECT, so this is
--   purely a defense-in-depth check.
