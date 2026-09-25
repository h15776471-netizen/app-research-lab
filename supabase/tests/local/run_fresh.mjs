// Fresh-project path (what a brand-new Supabase project receives):
// platform stub → deploy/01_schema.sql → 02_storage.sql → seed_providers.sql
// → verify_schema.sql → rls_test.sql. No v1 legacy state.
//   SAWA_TEST_DEPS=/path/to/sawa-db-test node supabase/tests/local/run_fresh.mjs
import { createRequire } from 'node:module';
import { pathToFileURL, fileURLToPath } from 'node:url';
import fs from 'node:fs'; import path from 'node:path'; import os from 'node:os';

const here = path.dirname(fileURLToPath(import.meta.url));
const supabaseDir = path.resolve(here, '..', '..');
const req = createRequire(path.join(process.env.SAWA_TEST_DEPS || process.cwd(), 'package.json'));
const { default: EmbeddedPostgres } = await import(pathToFileURL(req.resolve('embedded-postgres')).href);
const pg = req('pg');
const port = Number(process.env.SAWA_PGPORT || 54330);
const dataDir = (process.env.SAWA_PGDATA || path.join(os.tmpdir(), 'sawa-pgdata')) + '-fresh';
fs.rmSync(dataDir, { recursive: true, force: true });
const server = new EmbeddedPostgres({ databaseDir: dataDir, user: 'postgres', password: 'postgres', port,
  persistent: false, initdbFlags: ['--encoding=UTF8', '--locale=C'], onLog: () => {}, onError: () => {} });
const read = (p) => fs.readFileSync(path.join(supabaseDir, p), 'utf8');
let failed = false;
try {
  await server.initialise(); await server.start(); await server.createDatabase('sawa');
  const c = new pg.Client({ host: 'localhost', port, user: 'postgres', password: 'postgres', database: 'sawa' });
  await c.connect();
  for (const f of ['tests/local/supabase_stub.sql', 'deploy/01_schema.sql', 'deploy/02_storage.sql', 'deploy/seed_providers.sql']) {
    await c.query(read(f)); console.log(`  ✓ ${f}`);
  }
  const res = await c.query(read('tests/verify_schema.sql'));
  const rows = (Array.isArray(res) ? res[res.length - 1] : res).rows;
  for (const x of rows.filter((x) => x.status === 'FAIL')) console.error(`  ✗ ${x.area}: ${x.check_name} (${x.detail ?? ''})`);
  const s = rows.find((x) => x.area === 'SUMMARY');
  if (s.status !== 'PHASE 1 SCHEMA OK') failed = true;
  console.log(`  ${failed ? '✗' : '✓'} verify_schema: ${s.check_name} ${s.status}`);
  try { await c.query(read('tests/rls_test.sql')); failed = true; console.error('  ✗ rls_test did not finish'); }
  catch (e) { if (/ALL_TESTS_PASSED/.test(e.message)) console.log(`  ✓ ${e.message}`); else { failed = true; console.error(`  ✗ ${e.message}`); } }
  await c.end();
} catch (e) { failed = true; console.error('  ✗ ' + e.message); }
finally { await server.stop().catch(() => {}); }
console.log(failed ? '\nFRESH PROJECT: FAILED' : '\nFRESH PROJECT: ALL GREEN');
process.exit(failed ? 1 : 0);
