# SAWA — Supabase

The database is defined by ordered, idempotent migrations. Security (who can
read/write what) is enforced **in Postgres** — RLS policies, guard triggers
and SECURITY DEFINER RPCs — never by client-side role checks.

## Migrations

| File | What it does |
|---|---|
| `migrations/20260924000100_core_schema.sql` | `profiles`, `categories`, `providers`, `provider_private`, `provider_field_sources`, `provider_images`, `services`, `provider_packages`, `event_inquiries`, `provider_profile_views`; signup trigger; guard triggers |
| `migrations/20260924000200_contact_requests_v2.sql` | Non-destructive upgrade of the live `contact_requests` (backup → add columns → backfill), validation, anti-spam and rate limiting |
| `migrations/20260924000300_rls_policies.sql` | Privileges + RLS for every table; removes the v1 `authenticated_read_only` hole |
| `migrations/20260924000400_rpc.sql` | `submit_contact_request`, `create_event_inquiry`, `record_provider_view`, `get_provider_stats` |
| `migrations/20260924000500_storage.sql` | `provider-media` and `avatars` buckets + ownership policies |
| `migrations/20260924000600_seed_categories.sql` | The 10 categories (no providers) |

All files are safe to run more than once.

## Apply to a NEW Supabase project (SQL Editor)

Step-by-step team guide (Arabic): [`../docs/NEW_SUPABASE_SETUP.md`](../docs/NEW_SUPABASE_SETUP.md).

| Step | File | Expected result |
|---|---|---|
| 1 | `deploy/01_schema.sql` — tables, triggers, RLS, RPCs, categories | `Success. No rows returned` |
| 2 | `deploy/02_storage.sql` — `provider-media` + `avatars` buckets and policies | `Success` |
| 3 | `deploy/seed_providers.sql` — 15 published + 2 draft listings | a 2-row table: `draft 2`, `published 15` |
| 4 | `tests/verify_schema.sql` | first row: `SUMMARY … PHASE 1 SCHEMA OK` |
| 5 | `tests/rls_test.sql` | an **error** reading `ALL_TESTS_PASSED (N checks)` (deliberate — it rolls back its fixtures) |

Each file runs in its own transaction: if one fails, nothing from that file is
applied and the earlier steps stay in place. Schema and Storage are split so a
Storage permission problem can never roll back the core schema. Every file is
idempotent (safe to run again). `deploy/apply_all_migrations.sql` (all six
migrations in one transaction) is kept for existing projects.

Generated files — never edit by hand:
- `deploy/01_schema.sql`, `deploy/02_storage.sql`, `deploy/apply_all_migrations.sql` ← `node supabase/scripts/bundle.mjs`
- `deploy/seed_providers.sql` + `sawaApp/assets/data/catalog.json` ← `node supabase/scripts/build_catalog.mjs`
  from the reviewed dataset `provider-data/catalog/providers.v2.json`.

## Verify from the public API

```bash
SUPABASE_URL=https://<project>.supabase.co \
SUPABASE_ANON_KEY=<publishable key> \
node supabase/tests/verify_live.mjs            # anon probes, writes nothing
node supabase/tests/verify_live.mjs --accounts # + real accounts / JWTs / Storage
```

Uses only the publishable key and stops before any write probe if the
migrations are not applied. `--accounts` signs up throw-away test accounts
(needs "Confirm email" off), tests every cross-account direction and real
Storage uploads, and deletes what it can; remove the test accounts afterwards
with `tests/cleanup_live_verify.sql`.

## Test locally (no cloud access)

`tests/local/run_fresh.mjs` replays the exact new-project path (steps 1–5
above) on a throw-away PostgreSQL. `tests/local/run.mjs` starts a throw-away PostgreSQL 17, emulates the
Supabase platform, recreates the live pre-v2 state (including legacy
`contact_requests` rows), applies every migration **twice**, checks the
legacy data survived, and runs `tests/rls_test.sql`.

```bash
mkdir ../sawa-db-test && (cd ../sawa-db-test && npm i embedded-postgres@17.10.0-beta.17 pg)
SAWA_TEST_DEPS=../sawa-db-test node supabase/tests/local/run.mjs
SAWA_TEST_DEPS=../sawa-db-test node supabase/tests/local/run_fresh.mjs
```

## Access model

| Actor | Can |
|---|---|
| anon (guest) | read published providers, their services/packages/images/provenance, categories; submit a contact request or planner inquiry (gets a reference code; can never read requests back) |
| customer | the above + own profile, own inquiries, own contact requests (cancel while open) |
| provider | the above + own business (draft → pending), its private contact data, services, packages, images, stats; requests **after SAWA forwards them** |
| admin | everything (set `profiles.role = 'admin'` manually — see below) |

Flow model: **Customer → SAWA → Provider.** Every request lands with the
SAWA team first; a provider sees it only once `forwarded_to_provider_at` is
set. Listings imported by SAWA (`source = 'pdf'`) have `user_id = null`
until an owner claims them (claim workflow is future work).

Provider phone numbers live in `provider_private` (owner + admin only).
Customer phone numbers are visible only to that customer, admins, and the
provider a request was forwarded to.

## Bootstrap an admin

After signing up in the app with your own account, run in SQL Editor:

```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'YOUR_EMAIL');
```

Roles can never be self-assigned from the app: signup accepts only
`customer`/`provider`, and a guard trigger blocks role changes by clients.

## Anti-spam limits (server-side)

- Same phone → same provider: once per 10 minutes
- Per network (hashed IP, raw IP never stored): 10 requests / hour
- Per phone: 5 requests / hour · per signed-in customer: 20 / hour
- Planner inquiries: 10 / hour per network or account, 5 / hour per phone

## Development settings

"Confirm email" is **off** during development/QA only. Re-enable and review
auth settings before production.
