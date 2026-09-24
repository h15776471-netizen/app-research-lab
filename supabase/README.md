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

## Apply (Supabase Dashboard → SQL Editor)

For **each file in order** (100 → 600):

1. SQL Editor → **New query**
2. Paste the whole file → **Run**
3. Expect `Success. No rows returned` (600 may show rows affected).

If any file errors, stop and keep the error text — nothing after it should be run.

Then run the security suite:

4. New query → paste `tests/rls_test.sql` → **Run**
5. The expected result is an **error** that reads `ALL_TESTS_PASSED (N checks)`.
   That error is deliberate: it rolls back every fixture, so nothing is left behind.
   Anything that starts with `FAIL:` is a real problem.

## Verify from the public API

```bash
SUPABASE_URL=https://<project>.supabase.co \
SUPABASE_ANON_KEY=<publishable key> \
node supabase/tests/verify_live.mjs
```

Uses only the publishable key, writes nothing, and stops before any write
probe if the migrations are not applied yet.

## Test locally (no cloud access)

`tests/local/run.mjs` starts a throw-away PostgreSQL 17, emulates the
Supabase platform, recreates the live pre-v2 state (including legacy
`contact_requests` rows), applies every migration **twice**, checks the
legacy data survived, and runs `tests/rls_test.sql`.

```bash
mkdir ../sawa-db-test && (cd ../sawa-db-test && npm i embedded-postgres@17 pg)
SAWA_TEST_DEPS=../sawa-db-test node supabase/tests/local/run.mjs
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
