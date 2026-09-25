// Concatenates supabase/migrations/*.sql (in order) into one atomic file for
// the Supabase SQL Editor: supabase/deploy/apply_all_migrations.sql
//
//   node supabase/scripts/bundle.mjs          # write the bundle
//   node supabase/scripts/bundle.mjs --check  # exit 1 if the bundle is stale
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const supabaseDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const migrationsDir = path.join(supabaseDir, 'migrations');
const outFile = path.join(supabaseDir, 'deploy', 'apply_all_migrations.sql');
// Split bundles used for a fresh project: the schema (everything except
// Storage) and Storage separately, so a Storage-permission problem on the
// hosted platform can never roll back the core schema.
const splitFiles = {
  [path.join(supabaseDir, 'deploy', '01_schema.sql')]: (f) => !f.includes('_storage'),
  [path.join(supabaseDir, 'deploy', '02_storage.sql')]: (f) => f.includes('_storage'),
};

export function buildBundle(filter = () => true, title = 'ALL MIGRATIONS IN ONE ATOMIC SCRIPT') {
  const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql') && filter(f)).sort();
  const parts = [
    '-- ═══════════════════════════════════════════════════════════════════════════',
    `-- SAWA — ${title} (generated — do not edit)`,
    '-- Source: supabase/migrations/*.sql · regenerate: node supabase/scripts/bundle.mjs',
    '--',
    '-- Supabase Dashboard → SQL Editor → New query → paste this whole file → Run.',
    '-- Runs in a single transaction: if anything fails, NOTHING is applied.',
    '-- Idempotent: safe to run again.',
    '-- Files included:',
    ...files.map((f) => `--   ${f}`),
    '-- ═══════════════════════════════════════════════════════════════════════════',
    '',
    'begin;',
    '',
  ];
  for (const f of files) {
    const sql = fs.readFileSync(path.join(migrationsDir, f), 'utf8').replace(/\r\n/g, '\n').trimEnd();
    parts.push(`-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> ${f}`, sql, `-- <<<<<<<<<<<<<<<<<<<<<<<<<<<< ${f}`, '');
  }
  parts.push('commit;', '');
  return parts.join('\n');
}

export function allBundles() {
  const out = { [outFile]: buildBundle() };
  for (const [file, filter] of Object.entries(splitFiles)) {
    out[file] = buildBundle(filter, `${path.basename(file, '.sql').toUpperCase()} — ATOMIC SCRIPT`);
  }
  return out;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const bundles = allBundles();
  if (process.argv.includes('--check')) {
    for (const [file, bundle] of Object.entries(bundles)) {
      const current = fs.existsSync(file) ? fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n') : '';
      if (current !== bundle) {
        console.error(`${path.basename(file)} is stale — run: node supabase/scripts/bundle.mjs`);
        process.exit(1);
      }
    }
    console.log('Bundles are up to date.');
  } else {
    for (const [file, bundle] of Object.entries(bundles)) {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, bundle);
      console.log(`Wrote ${path.relative(process.cwd(), file)} (${bundle.length} chars)`);
    }
  }
}
