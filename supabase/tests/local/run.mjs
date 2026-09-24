// Local verification of the SAWA Supabase migrations — no cloud access needed.
//
// 1. Starts a throw-away embedded PostgreSQL 17.
// 2. Emulates the Supabase platform (supabase_stub.sql).
// 3. Recreates the LIVE pre-v2 state (legacy_v1_state.sql).
// 4. Applies every migration in supabase/migrations — TWICE (idempotency).
// 5. Verifies legacy data survived.
// 6. Runs supabase/tests/rls_test.sql (must end with ALL_TESTS_PASSED).
//
// Setup (once, anywhere — node_modules is intentionally not in the repo):
//   mkdir sawa-db-test && cd sawa-db-test && npm i embedded-postgres@17 pg
// Run:
//   SAWA_TEST_DEPS=/path/to/sawa-db-test node supabase/tests/local/run.mjs
//   (Optional: SAWA_PGDATA=/tmp/sawa-pgdata — data dir, wiped each run.)
import { createRequire } from 'node:module';
import { pathToFileURL, fileURLToPath } from 'node:url';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const here = path.dirname(fileURLToPath(import.meta.url));
const supabaseDir = path.resolve(here, '..', '..');
const depsDir = process.env.SAWA_TEST_DEPS || process.cwd();
const req = createRequire(path.join(depsDir, 'package.json'));
const { default: EmbeddedPostgres } = await import(pathToFileURL(req.resolve('embedded-postgres')).href);
const pg = req('pg');

const dataDir = process.env.SAWA_PGDATA || path.join(os.tmpdir(), 'sawa-pgdata');
fs.rmSync(dataDir, { recursive: true, force: true });

const server = new EmbeddedPostgres({
  databaseDir: dataDir,
  user: 'postgres',
  password: 'postgres',
  port: Number(process.env.SAWA_PGPORT || 54329),
  persistent: false,
  initdbFlags: ['--encoding=UTF8', '--locale=C'],
  onLog: () => {},
  onError: (e) => console.error(String(e)),
});

let failed = false;
const read = (p) => fs.readFileSync(p, 'utf8');
const migrations = fs
  .readdirSync(path.join(supabaseDir, 'migrations'))
  .filter((f) => f.endsWith('.sql'))
  .sort()
  .map((f) => path.join(supabaseDir, 'migrations', f));

async function run(client, label, sql) {
  try {
    await client.query(sql);
    console.log(`  ✓ ${label}`);
  } catch (e) {
    failed = true;
    console.error(`  ✗ ${label}\n    ${e.message}${e.where ? `\n    where: ${e.where}` : ''}`);
    throw e;
  }
}

try {
  await server.initialise();
  await server.start();
  await server.createDatabase('sawa');
  const client = new pg.Client({
    host: 'localhost', port: Number(process.env.SAWA_PGPORT || 54329),
    user: 'postgres', password: 'postgres', database: 'sawa',
  });
  client.on('error', (e) => console.error(`  connection error: ${e.message}`));
  await client.connect();
  const { rows: [{ server_version }] } = await client.query('show server_version');
  console.log(`PostgreSQL ${server_version}`);

  console.log('\n[1] Platform + live v1 state');
  await run(client, 'supabase_stub.sql', read(path.join(here, 'supabase_stub.sql')));
  await run(client, 'legacy_v1_state.sql', read(path.join(here, 'legacy_v1_state.sql')));

  for (const pass of [1, 2]) {
    console.log(`\n[2.${pass}] Migrations (pass ${pass}${pass === 2 ? ' — idempotency' : ''})`);
    for (const m of migrations) await run(client, path.basename(m), read(m));
  }

  console.log('\n[3] Legacy data preserved');
  const checks = [
    ['3 legacy contact_requests rows kept',
      `select count(*) = 3 from public.contact_requests`],
    ['backup snapshot has the 3 original rows',
      `select count(*) = 3 from sawa_private.contact_requests_backup_v1`],
    ['original columns unchanged',
      `select bool_and(c.provider_id = b.provider_id and c.user_name = b.user_name and c.user_contact = b.user_contact
                       and c.note is not distinct from b.note and c.created_at = b.created_at)
         from public.contact_requests c join sawa_private.contact_requests_backup_v1 b using (id)`],
    ['legacy rows backfilled (reference/status/channel)',
      `select bool_and(reference_code like 'SW-%' and status = 'new' and channel = 'guest' and not is_spam)
         from public.contact_requests`],
    ['legacy row with non-phone contact still updatable (admin/operator)',
      `with u as (update public.contact_requests set status = 'viewed' where user_contact = 'abc' returning 1)
       select count(*) = 1 from u`],
    ['pre-existing auth user got a profile (role from metadata)',
      `select role = 'provider' and full_name = 'Legacy Signup' from public.profiles
        where id = '00000000-0000-4000-8000-00000000f001'`],
    ['10 categories seeded',
      `select count(*) = 10 from public.categories`],
  ];
  for (const [label, sql] of checks) {
    const { rows } = await client.query(sql);
    const ok = Object.values(rows[0])[0] === true;
    if (!ok) failed = true;
    console.log(`  ${ok ? '✓' : '✗'} ${label}`);
  }

  console.log('\n[4] RLS / security suite (supabase/tests/rls_test.sql)');
  let notices = 0;
  client.on('notice', (n) => { notices++; if (process.env.VERBOSE) console.log(`    ${n.message}`); });
  try {
    await client.query(read(path.join(supabaseDir, 'tests', 'rls_test.sql')));
    failed = true;
    console.error('  ✗ suite did not raise ALL_TESTS_PASSED');
  } catch (e) {
    if (/ALL_TESTS_PASSED/.test(e.message)) {
      console.log(`  ✓ ${e.message}`);
    } else {
      failed = true;
      console.error(`  ✗ ${e.message}${e.where ? `\n    where: ${e.where}` : ''}`);
    }
  }
  await client.query('rollback').catch(() => {});

  const { rows: [{ n }] } = await client.query(
    `select count(*)::int as n from auth.users where email like 'qa.%@sawa.test'`);
  console.log(`  ${n === 0 ? '✓' : '✗'} suite left no data behind (${n} test users remain)`);
  if (n !== 0) failed = true;

  await client.end();
} catch (e) {
  failed = true;
  if (!String(e.message).includes('ALL_TESTS_PASSED')) console.error(e.message);
} finally {
  await server.stop().catch(() => {});
}

console.log(failed ? '\nRESULT: FAILED' : '\nRESULT: ALL GREEN');
process.exit(failed ? 1 : 0);
