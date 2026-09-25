// Builds the SAWA provider catalog from the single reviewed source of truth:
//   provider-data/catalog/providers.v2.json
// into:
//   supabase/deploy/seed_providers.sql   — idempotent seed for the SQL Editor
//   sawaApp/assets/data/catalog.json     — offline catalog (published only),
//                                          same shape as the Supabase rows
//
//   node supabase/scripts/build_catalog.mjs          # write both files
//   node supabase/scripts/build_catalog.mjs --check  # exit 1 if either is stale
//
// IDs are deterministic (UUID v5-style from the legacy id), so the offline
// catalog and the database always agree on provider/service/package ids.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const srcFile = path.join(root, 'provider-data', 'catalog', 'providers.v2.json');
const seedFile = path.join(root, 'supabase', 'deploy', 'seed_providers.sql');
const catalogFile = path.join(root, 'sawaApp', 'assets', 'data', 'catalog.json');
const categoriesMigration = path.join(root, 'supabase', 'migrations', '20260924000600_seed_categories.sql');
const imagesDir = path.join(root, 'sawaApp', 'assets', 'images', 'providers');
const ASSET_PREFIX = 'assets/images/providers/';

const FIELDS = ['business_name', 'category', 'description', 'city', 'area', 'address', 'instagram_url',
  'website', 'phone', 'capacity', 'price', 'services', 'packages', 'images'];
const UNITS = new Set(['event', 'person', 'hour', 'day', 'piece', 'package']);

export function uuidFor(name) {
  const h = crypto.createHash('sha1').update('sawa:' + name).digest();
  h[6] = (h[6] & 0x0f) | 0x50;
  h[8] = (h[8] & 0x3f) | 0x80;
  const x = h.subarray(0, 16).toString('hex');
  return `${x.slice(0, 8)}-${x.slice(8, 12)}-${x.slice(12, 16)}-${x.slice(16, 20)}-${x.slice(20, 32)}`;
}

function readCategories() {
  const sql = fs.readFileSync(categoriesMigration, 'utf8');
  const re = /\('([a-z_]+)',\s*'([^']+)',\s*'([^']+)',\s*'([a-z_]+)',\s*(\d+)\)/g;
  const out = [];
  for (const m of sql.matchAll(re)) {
    out.push({ id: m[1], name_ar: m[2], name_en: m[3], icon_key: m[4], sort_order: Number(m[5]), is_active: true });
  }
  if (out.length === 0) throw new Error('No categories parsed from migration 600');
  return out;
}

function fail(msg) { throw new Error(`providers.v2.json: ${msg}`); }

function normalize(p, categoryIds) {
  const id = uuidFor(p.legacy_id);
  if (!/^[a-z_]+_\d{3}$/.test(p.legacy_id)) fail(`bad legacy_id ${p.legacy_id}`);
  if (!categoryIds.has(p.category_id)) fail(`${p.legacy_id}: unknown category ${p.category_id}`);
  if (!['published', 'draft'].includes(p.status)) fail(`${p.legacy_id}: bad status`);
  const instagram_url = p.instagram_handle ? `https://www.instagram.com/${p.instagram_handle}` : null;
  if (instagram_url && !/^https:\/\/(www\.)?instagram\.com\/[A-Za-z0-9._]{1,30}\/?$/.test(instagram_url)) fail(`${p.legacy_id}: bad instagram`);

  const assetOf = (file) => {
    if (!fs.existsSync(path.join(imagesDir, file))) fail(`${p.legacy_id}: image not found ${file}`);
    return ASSET_PREFIX + file;
  };
  const images = (p.images || []).map((im, i) => ({
    id: uuidFor(`${p.legacy_id}:image:${im.file}`),
    provider_id: id,
    url: assetOf(im.file),
    kind: im.kind,
    sort_order: i,
    alt_text: im.alt || null,
    source: 'pdf_extract',
    source_ref: p.source_ref,
  }));
  if (images.filter((i) => i.kind === 'cover').length > 1) fail(`${p.legacy_id}: more than one cover`);
  const cover = images.find((i) => i.kind === 'cover');

  const services = (p.services || []).map((s, i) => {
    if (s.unit && !UNITS.has(s.unit)) fail(`${p.legacy_id}: bad unit ${s.unit}`);
    return {
      id: uuidFor(`${p.legacy_id}:service:${i}:${s.name}`),
      provider_id: id,
      name: s.name,
      description: s.description ?? null,
      price_from: s.price_from ?? null,
      price_to: s.price_to ?? null,
      currency: 'IQD',
      unit: s.unit ?? null,
      image_url: s.image ? assetOf(s.image) : null,
      is_active: true,
      sort_order: i,
    };
  });
  const packages = (p.packages || []).map((k, i) => ({
    id: uuidFor(`${p.legacy_id}:package:${i}:${k.title}`),
    provider_id: id,
    title: k.title,
    description: k.description ?? null,
    price_from: k.price_from ?? null,
    price_to: k.price_to ?? null,
    currency: 'IQD',
    conditions: k.conditions ?? null,
    is_offer: Boolean(k.is_offer),
    valid_from: null,
    valid_until: null,
    source_ref: p.source_ref,
    is_active: true,
    sort_order: i,
  }));

  const field_sources = [];
  const f = { city: 'source_only', ...p.fields };
  for (const [field, v] of Object.entries(f)) {
    if (!FIELDS.includes(field)) fail(`${p.legacy_id}: unknown provenance field ${field}`);
    const [status, note] = Array.isArray(v) ? v : [v, null];
    if (!['verified', 'source_only', 'unverified', 'missing'].includes(status)) fail(`${p.legacy_id}: bad status ${status}`);
    field_sources.push({ provider_id: id, field, status, source_ref: p.source_ref, note: note ?? null });
  }
  // Consistency: a value must not be published with status "missing".
  const fs_ = Object.fromEntries(field_sources.map((x) => [x.field, x.status]));
  if (instagram_url && fs_.instagram_url !== 'source_only' && fs_.instagram_url !== 'verified') fail(`${p.legacy_id}: instagram shown but status ${fs_.instagram_url}`);
  if ((p.price_from ?? null) !== null && fs_.price === 'missing') fail(`${p.legacy_id}: price set but status missing`);
  if (images.length > 0 && fs_.images === 'missing') fail(`${p.legacy_id}: images present but status missing`);

  return {
    provider: {
      id,
      user_id: null,
      category_id: p.category_id,
      legacy_id: p.legacy_id,
      business_name: p.business_name,
      short_description: p.short_description ?? null,
      description: p.description ?? null,
      city: p.city || 'بغداد',
      area: p.area ?? null,
      address: p.address ?? null,
      instagram_url,
      website: null,
      logo_url: null,
      cover_image_url: cover ? cover.url : null,
      capacity: p.capacity ?? null,
      price_from: p.price_from ?? null,
      price_to: p.price_to ?? null,
      currency: 'IQD',
      price_note: p.price_note ?? null,
      status: p.status,
      source: 'pdf',
      source_ref: p.source_ref,
    },
    private: {
      provider_id: id,
      phone: (p.phones || []).join(' / ') || null,
      whatsapp: p.whatsapp ?? null,
      internal_notes: [
        p.instagram_candidate ? `Instagram candidate (unconfirmed): ${p.instagram_candidate}` : null,
        `Source: ${p.source_ref}`,
      ].filter(Boolean).join(' · '),
    },
    images, services, packages, field_sources,
  };
}

const q = (v) => {
  if (v === null || v === undefined) return 'null';
  if (typeof v === 'number') return String(v);
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  return `'${String(v).replace(/'/g, "''")}'`;
};

function insert(table, rows, cols, conflict, updateCols) {
  if (rows.length === 0) return '';
  const values = rows.map((r) => `  (${cols.map((c) => q(r[c])).join(', ')})`).join(',\n');
  const onConflict = conflict
    ? `\non conflict (${conflict}) do update set\n  ${updateCols.map((c) => `${c} = excluded.${c}`).join(',\n  ')}`
    : '';
  return `insert into ${table} (${cols.join(', ')}) values\n${values}${onConflict};\n`;
}

export function build() {
  const src = JSON.parse(fs.readFileSync(srcFile, 'utf8'));
  const categories = readCategories();
  const catIds = new Set(categories.map((c) => c.id));
  const seen = new Set();
  const all = src.providers.map((p) => {
    if (seen.has(p.legacy_id)) fail(`duplicate ${p.legacy_id}`);
    seen.add(p.legacy_id);
    return normalize(p, catIds);
  });

  // ── seed SQL ────────────────────────────────────────────────────────────
  const ids = all.map((x) => q(x.provider.id)).join(', ');
  const pCols = ['id', 'user_id', 'category_id', 'legacy_id', 'business_name', 'short_description', 'description',
    'city', 'area', 'address', 'instagram_url', 'website', 'logo_url', 'cover_image_url', 'capacity', 'price_from',
    'price_to', 'currency', 'price_note', 'status', 'source', 'source_ref'];
  const sql = [
    '-- ═══════════════════════════════════════════════════════════════════════════',
    '-- SAWA — provider catalog seed (generated — do not edit)',
    '-- Source: provider-data/catalog/providers.v2.json',
    '-- Regenerate: node supabase/scripts/build_catalog.mjs',
    '--',
    '-- Run AFTER apply_all_migrations.sql (SQL Editor → New query → paste → Run).',
    '-- Idempotent: re-running refreshes these SAWA-managed listings (source = pdf)',
    '-- and their services/packages/images/provenance. Never touches listings',
    '-- owned by provider accounts.',
    `-- Providers: ${all.length} (${all.filter((x) => x.provider.status === 'published').length} published, ` +
      `${all.filter((x) => x.provider.status !== 'published').length} draft)`,
    '-- ═══════════════════════════════════════════════════════════════════════════',
    '',
    'begin;',
    '',
    'do $$ begin',
    "  if to_regclass('public.providers') is null then",
    "    raise exception 'Run supabase/deploy/apply_all_migrations.sql first';",
    '  end if;',
    '  if exists (select 1 from public.providers where id in (' + ids + ') and source <> \'pdf\') then',
    "    raise exception 'A seeded id is used by a non-SAWA listing — aborting';",
    '  end if;',
    'end $$;',
    '',
    insert('public.providers', all.map((x) => x.provider), pCols, 'id',
      pCols.filter((c) => !['id', 'user_id', 'source'].includes(c))),
    insert('public.provider_private', all.map((x) => x.private), ['provider_id', 'phone', 'whatsapp', 'internal_notes'],
      'provider_id', ['phone', 'whatsapp', 'internal_notes']),
    `delete from public.provider_images        where provider_id in (${ids});`,
    `delete from public.services               where provider_id in (${ids});`,
    `delete from public.provider_packages      where provider_id in (${ids});`,
    `delete from public.provider_field_sources where provider_id in (${ids});`,
    '',
    insert('public.provider_images', all.flatMap((x) => x.images),
      ['id', 'provider_id', 'url', 'kind', 'sort_order', 'alt_text', 'source', 'source_ref']),
    insert('public.services', all.flatMap((x) => x.services),
      ['id', 'provider_id', 'name', 'description', 'price_from', 'price_to', 'currency', 'unit', 'image_url', 'is_active', 'sort_order']),
    insert('public.provider_packages', all.flatMap((x) => x.packages),
      ['id', 'provider_id', 'title', 'description', 'price_from', 'price_to', 'currency', 'conditions', 'is_offer',
        'valid_from', 'valid_until', 'source_ref', 'is_active', 'sort_order']),
    insert('public.provider_field_sources', all.flatMap((x) => x.field_sources),
      ['provider_id', 'field', 'status', 'source_ref', 'note']),
    '-- Link any legacy v1 contact requests to their provider.',
    'update public.contact_requests cr set provider_uuid = p.id',
    '  from public.providers p',
    ' where cr.provider_uuid is null and p.legacy_id = cr.provider_id;',
    '',
    'commit;',
    '',
    "select status, count(*) as providers from public.providers where source = 'pdf' group by status order by status;",
    '',
  ].join('\n');

  // ── offline catalog (published only; no private data) ──────────────────
  const pub = all.filter((x) => x.provider.status === 'published');
  const catalog = {
    _generated: 'node supabase/scripts/build_catalog.mjs — do not edit; source: provider-data/catalog/providers.v2.json',
    categories,
    providers: pub.map((x) => ({
      ...x.provider,
      images: x.images,
      services: x.services,
      packages: x.packages,
      field_sources: x.field_sources.map(({ field, status, note }) => ({ field, status, note })),
    })),
  };
  return { sql, json: JSON.stringify(catalog, null, 1) + '\n' };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { sql, json } = build();
  const norm = (p) => (fs.existsSync(p) ? fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n') : '');
  if (process.argv.includes('--check')) {
    const stale = [[seedFile, sql], [catalogFile, json]].filter(([p, c]) => norm(p) !== c).map(([p]) => path.relative(root, p));
    if (stale.length) { console.error('Stale: ' + stale.join(', ') + ' — run: node supabase/scripts/build_catalog.mjs'); process.exit(1); }
    console.log('Catalog outputs are up to date.');
  } else {
    fs.writeFileSync(seedFile, sql);
    fs.writeFileSync(catalogFile, json);
    console.log(`Wrote ${path.relative(root, seedFile)} and ${path.relative(root, catalogFile)}`);
  }
}
