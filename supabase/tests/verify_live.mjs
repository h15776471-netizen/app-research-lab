// Post-deploy verification of the LIVE Supabase project through the public
// API, using ONLY the publishable (anon) key — exactly what the app has.
//
//   SUPABASE_URL=https://xxxx.supabase.co SUPABASE_ANON_KEY=sb_publishable_... \
//     node supabase/tests/verify_live.mjs [--accounts]
//
// Default mode writes NOTHING: every write probe is designed to be rejected.
//
// --accounts  Real end-to-end RLS test with real JWTs: signs up 2 customers,
//             2 providers and 1 account that asks for "admin", then probes
//             every cross-account direction, Storage uploads, the v1 contact
//             path and the RPCs. It removes everything it is allowed to
//             remove; the test auth accounts (+ one tagged v1 contact
//             request) are removed by supabase/tests/cleanup_live_verify.sql.
//             Requires "Confirm email" OFF (development setting).
//
// Complements tests/verify_schema.sql (structure) and tests/rls_test.sql
// (admin + forwarding flows) which run in the SQL Editor.
const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_ANON_KEY;
const withAccounts = process.argv.includes('--accounts');
const emailDomain = process.env.SAWA_VERIFY_EMAIL_DOMAIN || 'sawa-qa.test';

if (!url || !key) {
  console.error('Set SUPABASE_URL and SUPABASE_ANON_KEY.');
  process.exit(2);
}
if (/^sb_secret_|service_role/.test(key)) {
  console.error('Refusing to run with a secret/service key. Use the publishable key.');
  process.exit(2);
}

// Let pending sockets close before exiting (avoids a libuv assert on Windows).
const exit = async (code) => { await new Promise((r) => setTimeout(r, 200)); process.exit(code); };
let failed = 0;
let passed = 0;

async function call(method, path, body, { token, prefer, raw, contentType } = {}) {
  const headers = { apikey: key };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (prefer) headers.Prefer = prefer;
  if (body !== undefined) headers['Content-Type'] = contentType || 'application/json';
  const res = await fetch(`${url}${path}`, {
    method, headers,
    body: body === undefined ? undefined : raw ? body : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* not json */ }
  return { status: res.status, json, text: text || '' };
}
function check(label, ok, r) {
  if (ok) passed++; else failed++;
  const detail = r && typeof r === 'object' ? `${r.status} ${r.text.slice(0, 300)}` : String(r ?? '');
  console.log(`${ok ? '✓' : '✗'} ${label}${ok ? '' : `\n    got: ${detail}`}`);
}
const section = (t) => console.log(`\n── ${t}`);
const denied = (r) => r.status === 401 || r.status === 403 || /42501|permission denied/.test(r.text);
const errLike = (r, s) => r.status >= 400 && r.text.includes(s);
const isEmptyArray = (r) => r.status === 200 && Array.isArray(r.json) && r.json.length === 0;
const randomUuid = () => crypto.randomUUID();

// ═══════════════════════════════════════════════════════════════════════════════
// Part A — anonymous (no writes)
// ═══════════════════════════════════════════════════════════════════════════════
section('A. Anonymous — public catalogue');
let r = await call('GET', '/rest/v1/categories?select=id&order=sort_order');
check('categories: 10 public categories', r.status === 200 && Array.isArray(r.json) && r.json.length === 10, r);
if (failed) {
  // Before migration 300 the legacy table still accepts anon inserts, so the
  // write probes below could store junk. Stop here.
  console.error('\nMigrations do not appear to be applied — stopping before any write probe.');
  await exit(1);
}

r = await call('GET', '/rest/v1/providers?select=id,status');
check('providers: readable by anon', r.status === 200, r);
check('providers: anon sees only published', r.status === 200 && r.json.every((p) => p.status === 'published'), r);
for (const t of ['services', 'provider_packages', 'provider_images', 'provider_field_sources']) {
  r = await call('GET', `/rest/v1/${t}?select=id&limit=1`);
  check(`${t}: deployed + readable by anon`, r.status === 200, r);
}

section('A. Anonymous — private data');
for (const t of ['contact_requests', 'profiles', 'event_inquiries', 'provider_private', 'provider_profile_views']) {
  r = await call('GET', `/rest/v1/${t}?select=*&limit=1`);
  check(`${t}: NOT readable by anon`, denied(r), r);
}
r = await call('PATCH', '/rest/v1/providers?id=eq.00000000-0000-0000-0000-000000000000', { business_name: 'x' });
check('providers: anon cannot update', denied(r), r);
r = await call('POST', '/rest/v1/categories', { id: 'hacked', name_ar: 'x', name_en: 'x' });
check('categories: anon cannot insert', denied(r), r);
r = await call('POST', '/rest/v1/event_inquiries', { event_type: 'wedding', reference_code: 'x', guest_contact: '07700000000' });
check('event_inquiries: anon cannot insert directly (RPC only)', denied(r), r);

section('A. Server-side validation (all rejected → nothing written)');
r = await call('POST', '/rest/v1/contact_requests', {
  provider_id: 'hall_ritaj_001', user_name: 'Verify', user_contact: 'abc', created_at: new Date().toISOString(),
});
check('contact_requests (v1 app path): invalid phone rejected', errLike(r, 'invalid_contact'), r);
r = await call('POST', '/rest/v1/rpc/submit_contact_request', { p_provider_id: randomUuid(), p_name: 'Verify', p_contact: '07700000000' });
check('rpc submit_contact_request: unknown provider rejected', errLike(r, 'provider_not_available'), r);
r = await call('POST', '/rest/v1/rpc/submit_contact_request', { p_provider_id: randomUuid(), p_name: '  ', p_contact: '07700000000' });
check('rpc submit_contact_request: blank name rejected', errLike(r, 'invalid_name'), r);
r = await call('POST', '/rest/v1/rpc/create_event_inquiry', { p_event_type: 'wedding' });
check('rpc create_event_inquiry: guest needs contact', errLike(r, 'contact_required'), r);
r = await call('POST', '/rest/v1/rpc/get_provider_stats', { p_provider_id: randomUuid() });
check('rpc get_provider_stats: not callable by anon', denied(r) || r.status === 404, r);
r = await call('POST', '/rest/v1/rpc/record_provider_view', { p_provider_id: randomUuid() });
check('rpc record_provider_view: deployed (unknown provider ignored)', r.status === 204 || r.status === 200, r);

section('A. Storage');
for (const b of ['provider-media', 'avatars']) {
  const res = await fetch(`${url}/storage/v1/object/public/${b}/__sawa_verify_missing__.jpg`, { headers: { apikey: key } });
  const body = await res.text();
  check(`storage: bucket "${b}" exists`, !/Bucket not found/i.test(body), `${res.status} ${body}`);
}
const PNG = Uint8Array.from(atob('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='), (c) => c.charCodeAt(0));
r = await call('POST', `/storage/v1/object/provider-media/${randomUuid()}/anon.png`, PNG, { raw: true, contentType: 'image/png' });
check('storage: anon cannot upload', r.status >= 400, r);

// ═══════════════════════════════════════════════════════════════════════════════
// Part B — real accounts (opt-in)
// ═══════════════════════════════════════════════════════════════════════════════
if (withAccounts) {
  const run = Date.now().toString(36);
  const password = `Verify-${run}-Pw!9`;
  const email = (tag) => `sawa-verify-${run}-${tag}@${emailDomain}`;
  const created = { businesses: [], files: [] };

  async function signup(tag, meta) {
    const res = await call('POST', '/auth/v1/signup', { email: email(tag), password, data: meta });
    return { id: res.json?.user?.id ?? res.json?.id, token: res.json?.access_token, res };
  }

  section('B1. Auth + roles');
  const c1 = await signup('cust1', { role: 'customer', full_name: 'Verify Customer 1' });
  const c2 = await signup('cust2', { full_name: 'Verify Customer 2' });
  const p1 = await signup('prov1', { role: 'provider', full_name: 'Verify Provider 1' });
  const p2 = await signup('prov2', { role: 'provider', full_name: 'Verify Provider 2' });
  const ad = await signup('admin', { role: 'admin', full_name: 'Verify Wannabe Admin' });
  const all = [c1, c2, p1, p2, ad];
  check('signup returns a session for every account ("Confirm email" is OFF)', all.every((a) => a.token && a.id),
        all.find((a) => !a.token)?.res);
  if (!all.every((a) => a.token)) {
    console.error('\nCannot continue account tests without sessions. Turn "Confirm email" off, or set SAWA_VERIFY_EMAIL_DOMAIN if the domain was rejected.');
    await exit(1);
  }

  r = await call('POST', '/auth/v1/token?grant_type=password', { email: email('cust1'), password: 'wrong-password' });
  check('login with wrong password is rejected', r.status === 400, r);
  r = await call('POST', '/auth/v1/token?grant_type=password', { email: email('cust1'), password });
  check('login with correct password returns a session', r.status === 200 && !!r.json?.access_token, r);

  const me = async (a) => (await call('GET', '/rest/v1/profiles?select=id,role,full_name,email', undefined, { token: a.token }));
  r = await me(c1);
  check('customer: sees exactly one profile — their own', r.status === 200 && r.json.length === 1 && r.json[0].id === c1.id, r);
  check('customer: role = customer', r.json?.[0]?.role === 'customer', r);
  check('signup trigger copied full_name', r.json?.[0]?.full_name === 'Verify Customer 1', r);
  check('missing role defaults to customer', (await me(c2)).json?.[0]?.role === 'customer');
  check('provider signup → role provider', (await me(p1)).json?.[0]?.role === 'provider');
  check('"admin" requested at signup is NOT granted', (await me(ad)).json?.[0]?.role === 'customer');

  r = await call('PATCH', `/rest/v1/profiles?id=eq.${c1.id}`, { role: 'admin' }, { token: c1.token });
  check('customer cannot escalate own role', errLike(r, 'immutable_field'), r);
  r = await call('PATCH', `/rest/v1/profiles?id=eq.${c1.id}`, { role: 'provider' }, { token: c1.token });
  check('customer cannot switch own role to provider', errLike(r, 'immutable_field'), r);
  r = await call('PATCH', `/rest/v1/profiles?id=eq.${c1.id}`, { full_name: 'Verify C1 Renamed', phone: '٠٧٧٠٠٠٠٠٠٠٩' },
                 { token: c1.token, prefer: 'return=representation' });
  check('customer can edit own name/phone (digits normalised)', r.status === 200 && r.json?.[0]?.phone === '07700000009', r);
  r = await call('GET', `/rest/v1/profiles?id=eq.${c2.id}`, undefined, { token: c1.token });
  check('cross-user: customer cannot read another profile', isEmptyArray(r), r);
  r = await call('PATCH', `/rest/v1/profiles?id=eq.${c2.id}`, { full_name: 'hacked' }, { token: c1.token, prefer: 'return=representation' });
  check('cross-user: customer cannot edit another profile', isEmptyArray(r), r);

  section('B2. Provider business ownership');
  r = await call('POST', '/rest/v1/providers', { category_id: 'photography', business_name: 'SAWA VERIFY Studio 1', city: 'بغداد',
                                                 user_id: c2.id, source: 'pdf', status: 'draft' },
                 { token: p1.token, prefer: 'return=representation' });
  const biz1 = r.json?.[0]?.id;
  check('provider: creates own draft business', r.status === 201 && !!biz1, r);
  check('provider: owner forced to self (spoofed user_id ignored)', r.json?.[0]?.user_id === p1.id, r);
  check('provider: source forced to self_registered', r.json?.[0]?.source === 'self_registered', r);
  if (biz1) created.businesses.push([p1, biz1]);

  r = await call('POST', '/rest/v1/providers', { category_id: 'halls', business_name: 'SAWA VERIFY second' }, { token: p1.token });
  check('provider: only one business per account', errLike(r, 'uq_providers_user_id'), r);
  r = await call('POST', '/rest/v1/providers', { category_id: 'halls', business_name: 'SAWA VERIFY customer biz' }, { token: c1.token });
  check('customer cannot create a business', errLike(r, 'provider_account_required'), r);
  r = await call('PATCH', `/rest/v1/providers?id=eq.${biz1}`, { status: 'published' }, { token: p1.token });
  check('provider cannot self-publish', errLike(r, 'invalid_status_transition'), r);

  r = await call('POST', '/rest/v1/providers', { category_id: 'flowers', business_name: 'SAWA VERIFY Flowers 2' },
                 { token: p2.token, prefer: 'return=representation' });
  const biz2 = r.json?.[0]?.id;
  check('provider 2: creates own business', r.status === 201 && !!biz2, r);
  if (biz2) created.businesses.push([p2, biz2]);

  r = await call('GET', `/rest/v1/providers?id=eq.${biz1}`, undefined, { token: p2.token });
  check('cross-provider: cannot read another draft business', isEmptyArray(r), r);
  r = await call('PATCH', `/rest/v1/providers?id=eq.${biz1}`, { business_name: 'hacked' }, { token: p2.token, prefer: 'return=representation' });
  check('cross-provider: cannot edit another business', isEmptyArray(r), r);
  r = await call('DELETE', `/rest/v1/providers?id=eq.${biz1}`, undefined, { token: p2.token, prefer: 'return=representation' });
  check('cross-provider: cannot delete another business', isEmptyArray(r), r);
  r = await call('GET', `/rest/v1/providers?id=eq.${biz1}`, undefined, { token: c1.token });
  check('customer cannot see an unpublished business', isEmptyArray(r), r);
  r = await call('GET', `/rest/v1/providers?id=eq.${biz1}`);
  check('anon cannot see an unpublished business', isEmptyArray(r), r);

  r = await call('POST', '/rest/v1/provider_private', { provider_id: biz1, phone: '07711111111' }, { token: p1.token });
  check('provider: stores own private phone', r.status === 201, r);
  r = await call('GET', `/rest/v1/provider_private?provider_id=eq.${biz1}`, undefined, { token: p1.token });
  check('provider: reads own private phone', r.status === 200 && r.json?.length === 1, r);
  r = await call('GET', `/rest/v1/provider_private?provider_id=eq.${biz1}`, undefined, { token: p2.token });
  check('cross-provider: private phone hidden', isEmptyArray(r), r);
  r = await call('GET', `/rest/v1/provider_private?provider_id=eq.${biz1}`, undefined, { token: c1.token });
  check('customer: provider private phone hidden', isEmptyArray(r), r);

  r = await call('POST', '/rest/v1/services', { provider_id: biz1, name: 'SAWA VERIFY coverage', price_from: 500000 }, { token: p1.token });
  check('provider: adds service to own business', r.status === 201, r);
  r = await call('POST', '/rest/v1/services', { provider_id: biz1, name: 'intruder' }, { token: p2.token });
  check('cross-provider: cannot add service to another business', r.status >= 400 && /row-level security/.test(r.text), r);
  r = await call('GET', `/rest/v1/services?provider_id=eq.${biz1}`, undefined, { token: p2.token });
  check('cross-provider: cannot read services of unpublished business', isEmptyArray(r), r);

  r = await call('PATCH', `/rest/v1/providers?id=eq.${biz1}`, { status: 'pending' }, { token: p1.token, prefer: 'return=representation' });
  check('provider: submits for review (draft → pending)', r.status === 200 && r.json?.[0]?.status === 'pending' && !!r.json?.[0]?.submitted_at, r);
  r = await call('PATCH', `/rest/v1/providers?id=eq.${biz1}`, { status: 'draft' }, { token: p1.token, prefer: 'return=representation' });
  check('provider: withdraws submission (pending → draft)', r.status === 200 && r.json?.[0]?.status === 'draft', r);

  r = await call('POST', '/rest/v1/rpc/get_provider_stats', { p_provider_id: biz1 }, { token: p1.token });
  check('provider: reads own real stats', r.status === 200 && r.json?.services_total === 1 && r.json?.views_total === 0, r);
  r = await call('POST', '/rest/v1/rpc/get_provider_stats', { p_provider_id: biz1 }, { token: p2.token });
  check('cross-provider: stats denied', errLike(r, 'not_allowed'), r);
  r = await call('POST', '/rest/v1/rpc/get_provider_stats', { p_provider_id: biz1 }, { token: c1.token });
  check('customer: provider stats denied', errLike(r, 'not_allowed'), r);

  section('B3. Inquiries + requests');
  r = await call('POST', '/rest/v1/rpc/create_event_inquiry',
                 { p_event_type: 'wedding', p_guest_count: 250, p_city: 'بغداد', p_services: ['halls', 'photography'], p_notes: 'SAWA VERIFY' },
                 { token: c1.token });
  const inq = r.json?.[0]?.id;
  check('customer: creates inquiry via RPC (reference EV-…)', r.status === 200 && /^EV-/.test(r.json?.[0]?.reference_code ?? ''), r);
  r = await call('GET', `/rest/v1/event_inquiries?id=eq.${inq}`, undefined, { token: c1.token });
  check('customer: reads own inquiry', r.status === 200 && r.json?.length === 1 && r.json[0].customer_id === c1.id, r);
  r = await call('GET', `/rest/v1/event_inquiries?id=eq.${inq}`, undefined, { token: c2.token });
  check('cross-user: cannot read another customer inquiry', isEmptyArray(r), r);
  r = await call('GET', `/rest/v1/event_inquiries?id=eq.${inq}`, undefined, { token: p1.token });
  check('provider: cannot read customer inquiries', isEmptyArray(r), r);
  r = await call('PATCH', `/rest/v1/event_inquiries?id=eq.${inq}`, { notes: 'edited' }, { token: c1.token });
  check('customer: cannot edit inquiry contents', errLike(r, 'immutable_field'), r);
  r = await call('PATCH', `/rest/v1/event_inquiries?id=eq.${inq}`, { status: 'cancelled' }, { token: c2.token, prefer: 'return=representation' });
  check('cross-user: cannot cancel another customer inquiry', isEmptyArray(r), r);
  r = await call('PATCH', `/rest/v1/event_inquiries?id=eq.${inq}`, { status: 'cancelled' }, { token: c1.token, prefer: 'return=representation' });
  check('customer: cancels own inquiry', r.status === 200 && r.json?.[0]?.status === 'cancelled', r);
  r = await call('POST', '/rest/v1/rpc/create_event_inquiry', { p_event_type: 'wedding', p_services: ['spaceships'] }, { token: c1.token });
  check('inquiry: unknown service category rejected', errLike(r, 'unknown_service_category'), r);

  r = await call('GET', '/rest/v1/contact_requests?select=id,customer_id', undefined, { token: c1.token });
  check('customer: contact_requests returns only own rows', r.status === 200 && r.json.every((x) => x.customer_id === c1.id), r);
  r = await call('GET', '/rest/v1/contact_requests?select=id', undefined, { token: p1.token });
  check('provider: sees no requests unless SAWA forwarded them', isEmptyArray(r), r);
  r = await call('DELETE', '/rest/v1/contact_requests?id=gt.0', undefined, { token: c1.token });
  check('customer: cannot delete requests', denied(r), r);

  // v1 app compatibility — the exact payload the current Flutter app sends.
  // Creates ONE tagged row (deleted by cleanup_live_verify.sql).
  r = await call('POST', '/rest/v1/contact_requests', {
    provider_id: 'sawa_verify_legacy', user_name: 'SAWA VERIFY (delete me)', user_contact: '07000000001',
    note: 'verify_live.mjs legacy-path probe', created_at: '2000-01-01T00:00:00Z',
  });
  check('v1 app contact path still works for guests (201)', r.status === 201, r);
  r = await call('POST', '/rest/v1/contact_requests', {
    provider_id: 'sawa_verify_legacy', user_name: 'SAWA VERIFY (delete me)', user_contact: '07000000001',
  });
  check('anti-spam: same phone → same provider within 10 min rejected', errLike(r, 'duplicate_request'), r);

  section('B4. Storage ownership (real uploads)');
  const up = (token, bucket, path, body = PNG, type = 'image/png') =>
    call('POST', `/storage/v1/object/${bucket}/${path}`, body, { token, raw: true, contentType: type });
  r = await up(p1.token, 'provider-media', `${biz1}/verify.png`);
  check('provider: uploads into own business folder', r.status === 200, r);
  if (r.status === 200) created.files.push([p1, 'provider-media', `${biz1}/verify.png`]);
  r = await up(p2.token, 'provider-media', `${biz1}/intruder.png`);
  check('cross-provider: cannot upload into another business folder', r.status >= 400, r);
  r = await up(c1.token, 'provider-media', `${biz1}/customer.png`);
  check('customer: cannot upload provider media', r.status >= 400, r);
  r = await up(p1.token, 'provider-media', `${biz1}/note.txt`, new TextEncoder().encode('hello'), 'text/plain');
  check('storage: non-image upload rejected by bucket rules', r.status >= 400, r);
  const pub = await fetch(`${url}/storage/v1/object/public/provider-media/${biz1}/verify.png`);
  check('storage: uploaded media publicly readable', pub.status === 200, `${pub.status}`);
  r = await up(c1.token, 'avatars', `${c1.id}/avatar.png`);
  check('customer: uploads own avatar', r.status === 200, r);
  if (r.status === 200) created.files.push([c1, 'avatars', `${c1.id}/avatar.png`]);
  r = await up(c1.token, 'avatars', `${c2.id}/avatar.png`);
  check('cross-user: cannot upload into another user avatar folder', r.status >= 400, r);
  r = await call('DELETE', `/storage/v1/object/provider-media/${biz1}/verify.png`, undefined, { token: p2.token });
  const stillThere = await fetch(`${url}/storage/v1/object/public/provider-media/${biz1}/verify.png`);
  check('cross-provider: cannot delete another business media', stillThere.status === 200, `${r.status} ${r.text}`);

  section('B5. Clean-up (everything the accounts are allowed to remove)');
  for (const [a, bucket, path] of created.files) {
    r = await call('DELETE', `/storage/v1/object/${bucket}/${path}`, undefined, { token: a.token });
    check(`removed ${bucket}/${path.split('/').pop()}`, r.status === 200, r);
  }
  for (const [a, id] of created.businesses) {
    r = await call('DELETE', `/rest/v1/providers?id=eq.${id}`, undefined, { token: a.token, prefer: 'return=representation' });
    check(`owner deleted own draft business (cascades services/private)`, r.status === 200 && r.json?.length === 1, r);
  }
  console.log(`\nTest accounts to remove with supabase/tests/cleanup_live_verify.sql: sawa-verify-${run}-*@${emailDomain}`);
}

console.log(`\n${passed} passed, ${failed} failed`);
console.log(failed ? `${failed} check(s) FAILED` : 'ALL LIVE CHECKS PASSED');
await exit(failed ? 1 : 0);
