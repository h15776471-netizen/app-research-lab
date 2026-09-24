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

export function buildBundle() {
  const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
  const parts = [
    '-- ═══════════════════════════════════════════════════════════════════════════',
    '-- SAWA — ALL MIGRATIONS IN ONE ATOMIC SCRIPT (generated — do not edit)',
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

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const bundle = buildBundle();
  if (process.argv.includes('--check')) {
    const current = fs.existsSync(outFile) ? fs.readFileSync(outFile, 'utf8').replace(/\r\n/g, '\n') : '';
    if (current !== bundle) {
      console.error('Bundle is stale — run: node supabase/scripts/bundle.mjs');
      process.exit(1);
    }
    console.log('Bundle is up to date.');
  } else {
    fs.mkdirSync(path.dirname(outFile), { recursive: true });
    fs.writeFileSync(outFile, bundle);
    console.log(`Wrote ${path.relative(process.cwd(), outFile)} (${bundle.length} chars)`);
  }
}
