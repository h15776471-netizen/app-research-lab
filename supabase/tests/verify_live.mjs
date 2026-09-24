// Post-deploy verification of the LIVE Supabase project through the public
// REST API, using ONLY the publishable (anon) key — exactly what the app has.
//
// Writes nothing: every write probe is designed to be rejected by the
// server-side validation, proving the triggers/policies are live.
//
//   SUPABASE_URL=https://xxxx.supabase.co SUPABASE_ANON_KEY=sb_publishable_... \
//     node supabase/tests/verify_live.mjs
//
// The authenticated / cross-account checks live in rls_test.sql (run it in
// the SQL Editor — it rolls itself back).
const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_ANON_KEY;
if (!url || !key) {
  console.error('Set SUPABASE_URL and SUPABASE_ANON_KEY.');
  process.exit(2);
}
if (/^sb_secret_|service_role/.test(key)) {
  console.error('Refusing to run with a secret/service key. Use the publishable key.');
  process.exit(2);
}

const headers = { apikey: key, 'Content-Type': 'application/json' };
// Let pending sockets close before exiting (avoids a libuv assert on Windows).
const exit = async (code) => { await new Promise((r) => setTimeout(r, 200)); process.exit(code); };
let failed = 0;

async function call(method, path, body) {
  const res = await fetch(`${url}${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
  let json = null;
  try { json = await res.json(); } catch { /* empty body */ }
  return { status: res.status, json, text: JSON.stringify(json) };
}
function check(label, ok, detail) {
  if (!ok) failed++;
  console.log(`${ok ? '✓' : '✗'} ${label}${ok ? '' : `\n    got: ${detail}`}`);
}
const denied = (r) => r.status === 401 || r.status === 403 || /42501|permission denied/.test(r.text);
const errLike = (r, s) => r.status >= 400 && r.text.includes(s);
const randomUuid = () => crypto.randomUUID();

// Catalogue ---------------------------------------------------------------------
let r = await call('GET', '/rest/v1/categories?select=id&order=sort_order');
check('categories: 10 public categories', r.status === 200 && Array.isArray(r.json) && r.json.length === 10, `${r.status} ${r.text}`);
if (failed) {
  // Before migration 300 the legacy table still accepts anon inserts, so the
  // write probes below could store junk. Stop here.
  console.error('\nMigrations do not appear to be applied — stopping before any write probe.');
  await exit(1);
}

r = await call('GET', '/rest/v1/providers?select=id,status');
check('providers: readable by anon', r.status === 200, `${r.status} ${r.text}`);
check('providers: anon sees only published', r.status === 200 && r.json.every((p) => p.status === 'published'), r.text);

for (const t of ['services', 'provider_packages', 'provider_images', 'provider_field_sources']) {
  r = await call('GET', `/rest/v1/${t}?select=id&limit=1`);
  check(`${t}: table deployed + readable by anon`, r.status === 200, `${r.status} ${r.text}`);
}

// Private data --------------------------------------------------------------------
for (const t of ['contact_requests', 'profiles', 'event_inquiries', 'provider_private', 'provider_profile_views']) {
  r = await call('GET', `/rest/v1/${t}?select=*&limit=1`);
  check(`${t}: NOT readable by anon`, denied(r), `${r.status} ${r.text}`);
}

r = await call('PATCH', '/rest/v1/providers?id=eq.00000000-0000-0000-0000-000000000000', { business_name: 'x' });
check('providers: anon cannot update', denied(r), `${r.status} ${r.text}`);

// Server-side validation is live (all rejected → nothing written) --------------
r = await call('POST', '/rest/v1/contact_requests', {
  provider_id: 'hall_ritaj_001', user_name: 'Verify', user_contact: 'abc', created_at: new Date().toISOString(),
});
check('contact_requests (v1 app path): invalid phone rejected by trigger', errLike(r, 'invalid_contact'), `${r.status} ${r.text}`);

r = await call('POST', '/rest/v1/rpc/submit_contact_request', {
  p_provider_id: randomUuid(), p_name: 'Verify', p_contact: '07700000000',
});
check('rpc submit_contact_request: deployed, rejects unknown provider', errLike(r, 'provider_not_available'), `${r.status} ${r.text}`);

r = await call('POST', '/rest/v1/rpc/create_event_inquiry', { p_event_type: 'wedding' });
check('rpc create_event_inquiry: deployed, guest needs contact', errLike(r, 'contact_required'), `${r.status} ${r.text}`);

r = await call('POST', '/rest/v1/rpc/get_provider_stats', { p_provider_id: randomUuid() });
check('rpc get_provider_stats: not callable by anon', denied(r) || r.status === 404, `${r.status} ${r.text}`);

r = await call('POST', '/rest/v1/rpc/record_provider_view', { p_provider_id: randomUuid() });
check('rpc record_provider_view: deployed (unknown provider ignored)', r.status === 204 || r.status === 200, `${r.status} ${r.text}`);

// Storage ------------------------------------------------------------------------
for (const b of ['provider-media', 'avatars']) {
  const res = await fetch(`${url}/storage/v1/object/public/${b}/__sawa_verify_missing__.jpg`, { headers });
  const body = await res.text();
  check(`storage: bucket "${b}" exists`, !/Bucket not found/i.test(body), `${res.status} ${body}`);
}

console.log(failed ? `\n${failed} check(s) FAILED` : '\nALL LIVE CHECKS PASSED');
await exit(failed ? 1 : 0);
