-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — RLS / security test suite
-- ═════════════════════════════════════════════════════════════════════════════
-- Runs in ONE transaction and always rolls back: it ends by raising
--   ALL_TESTS_PASSED (N checks)
-- on success, or
--   FAIL: <what broke>
-- on the first failing check. Either way NOTHING is left in the database.
--
-- Supabase: paste the whole file into SQL Editor → Run. The expected
-- "error" message is ALL_TESTS_PASSED.
-- Locally:  node supabase/tests/local/run.cjs
--
-- All fixture ids/phones are test-only and scoped to this transaction.
-- ═════════════════════════════════════════════════════════════════════════════

begin;

create schema sawa_test;
grant usage on schema sawa_test to anon, authenticated;

-- Switch identity: 'anon' | 'authenticated' | 'operator' (SQL Editor / owner).
create function sawa_test.act_as(p_uid uuid, p_role text) returns void
language plpgsql as $$
begin
  execute 'reset role';
  if p_role = 'operator' then
    perform set_config('request.jwt.claims', '{}', true);
    return;
  end if;
  perform set_config('request.jwt.claims',
                     json_build_object('sub', p_uid, 'role', p_role)::text, true);
  execute format('set local role %I', p_role);
end $$;

create function sawa_test.set_ip(p_ip text) returns void
language plpgsql as $$
begin
  perform set_config('request.headers', json_build_object('x-forwarded-for', p_ip)::text, true);
end $$;

create function sawa_test.ok(p_cond boolean, p_label text) returns void
language plpgsql as $$
begin
  if not coalesce(p_cond, false) then
    raise exception 'FAIL: %', p_label;
  end if;
  perform set_config('sawa_test.n', (coalesce(nullif(current_setting('sawa_test.n', true), ''), '0')::int + 1)::text, true);
  raise notice 'ok - %', p_label;
end $$;

create function sawa_test.expect_error(p_sql text, p_pattern text, p_label text) returns void
language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlerrm ilike '%' || p_pattern || '%' then
      perform sawa_test.ok(true, p_label);
      return;
    end if;
    raise exception 'FAIL: % — expected error like "%", got "%"', p_label, p_pattern, sqlerrm;
  end;
  raise exception 'FAIL: % — expected an error, statement succeeded', p_label;
end $$;

create function sawa_test.exec_count(p_sql text) returns int
language plpgsql as $$
declare v int;
begin
  execute p_sql;
  get diagnostics v = row_count;
  return v;
end $$;

do $$
declare
  u_ca  uuid := 'aaaaaaaa-0000-4000-8000-0000000000a1';
  u_cb  uuid := 'aaaaaaaa-0000-4000-8000-0000000000a2';
  u_pa  uuid := 'aaaaaaaa-0000-4000-8000-0000000000b1';
  u_pb  uuid := 'aaaaaaaa-0000-4000-8000-0000000000b2';
  u_adm uuid := 'aaaaaaaa-0000-4000-8000-0000000000c1';
  p0    uuid := 'bbbbbbbb-0000-4000-8000-000000000000';   -- SAWA-managed (pdf) listing
  biz_a uuid;
  biz_b uuid;
  s_act uuid;
  s_off uuid;
  v_ref text;
  v_id  bigint;
  req_a1 bigint;
  req_a2 bigint;
  req_b1 bigint;
  inq_a bigint;
  inq_g bigint;
  v_stats jsonb;
  i int;
begin
  -- ── Fixtures (operator) ──────────────────────────────────────────────────
  perform sawa_test.act_as(null, 'operator');

  insert into auth.users (id, email, raw_user_meta_data, aud, role) values
    (u_ca,  'qa.customer.a@sawa.test', '{"full_name":"QA Customer A","role":"customer"}', 'authenticated', 'authenticated'),
    (u_cb,  'qa.customer.b@sawa.test', '{"full_name":"QA Customer B"}',                   'authenticated', 'authenticated'),
    (u_pa,  'qa.provider.a@sawa.test', '{"full_name":"QA Provider A","role":"provider"}', 'authenticated', 'authenticated'),
    (u_pb,  'qa.provider.b@sawa.test', '{"full_name":"QA Provider B","role":"provider"}', 'authenticated', 'authenticated'),
    (u_adm, 'qa.admin@sawa.test',      '{"full_name":"QA Admin","role":"admin"}',         'authenticated', 'authenticated');

  -- 1. Signup trigger / roles ------------------------------------------------
  perform sawa_test.ok((select role from public.profiles where id = u_ca) = 'customer', 'signup: customer role stored');
  perform sawa_test.ok((select role from public.profiles where id = u_cb) = 'customer', 'signup: missing role defaults to customer');
  perform sawa_test.ok((select role from public.profiles where id = u_pa) = 'provider', 'signup: provider role stored');
  perform sawa_test.ok((select role from public.profiles where id = u_adm) = 'customer', 'signup: "admin" in metadata is NOT granted');
  perform sawa_test.ok((select full_name from public.profiles where id = u_ca) = 'QA Customer A', 'signup: full_name copied');
  perform sawa_test.ok((select email from public.profiles where id = u_ca) = 'qa.customer.a@sawa.test', 'signup: email copied');

  update public.profiles set role = 'admin' where id = u_adm;   -- operator bootstrap

  -- SAWA-managed published listing + 5 more for rate-limit tests
  insert into public.providers (id, category_id, business_name, status, source, source_ref, legacy_id)
  values (p0, 'halls', 'QA Legacy Hall', 'published', 'pdf', 'qa.pdf', 'qa_legacy_001');
  for i in 1..5 loop
    insert into public.providers (id, category_id, business_name, status, source)
    values (('bbbbbbbb-0000-4000-8000-00000000000' || i)::uuid, 'photography', 'QA Listing ' || i, 'published', 'pdf');
  end loop;
  insert into public.provider_private (provider_id, phone) values (p0, '07700000001');
  insert into public.services (provider_id, name, is_active) values (p0, 'QA active service', true)  returning id into s_act;
  insert into public.services (provider_id, name, is_active) values (p0, 'QA hidden service', false) returning id into s_off;
  insert into public.provider_field_sources (provider_id, field, status, source_ref) values (p0, 'price', 'missing', 'qa.pdf');
  perform sawa_test.ok((select published_at from public.providers where id = p0) is not null, 'operator publish sets published_at');

  -- 2. Anonymous: public catalogue only --------------------------------------
  perform sawa_test.act_as(null, 'anon');
  perform sawa_test.ok((select count(*) from public.categories
                         where id in ('halls','photography','flowers','decoration','beauty',
                                      'catering','music','cars','invitations','other')) = 10,
                       'anon: reads the 10 categories');
  perform sawa_test.ok((select count(*) from public.providers where id = p0) = 1, 'anon: reads published provider');
  perform sawa_test.ok((select count(*) from public.services where id = s_act) = 1, 'anon: reads active service of published provider');
  perform sawa_test.ok((select count(*) from public.services where id = s_off) = 0, 'anon: inactive service hidden');
  perform sawa_test.ok((select count(*) from public.provider_field_sources where provider_id = p0) = 1, 'anon: reads provenance of published provider');
  perform sawa_test.expect_error('select * from public.provider_private', 'permission denied', 'anon: provider_private blocked');
  perform sawa_test.expect_error('select * from public.contact_requests', 'permission denied', 'anon: contact_requests unreadable');
  perform sawa_test.expect_error('select * from public.profiles', 'permission denied', 'anon: profiles unreadable');
  perform sawa_test.expect_error('select * from public.event_inquiries', 'permission denied', 'anon: event_inquiries unreadable');
  perform sawa_test.expect_error($q$insert into public.categories (id, name_ar, name_en) values ('qa_cat','x','x')$q$, 'permission denied', 'anon: cannot write categories');
  perform sawa_test.expect_error($q$update public.providers set business_name = 'hacked'$q$, 'permission denied', 'anon: cannot update providers');

  -- 3. Provider onboarding / ownership ---------------------------------------
  perform sawa_test.act_as(u_pa, 'authenticated');
  insert into public.providers (category_id, business_name, status, user_id, source)
  values ('photography', 'QA Studio A', 'draft', u_cb, 'pdf')      -- spoofed owner/source are ignored
  returning id into biz_a;
  perform sawa_test.act_as(null, 'operator');
  perform sawa_test.ok((select user_id from public.providers where id = biz_a) = u_pa, 'provider: owner forced to auth.uid()');
  perform sawa_test.ok((select source from public.providers where id = biz_a) = 'self_registered', 'provider: source forced to self_registered');

  perform sawa_test.act_as(u_pa, 'authenticated');
  perform sawa_test.expect_error($q$insert into public.providers (category_id, business_name) values ('halls','Second biz')$q$,
                                 'uq_providers_user_id', 'provider: one business per account');
  perform sawa_test.expect_error($q$update public.providers set status = 'published' where user_id = auth.uid()$q$,
                                 'invalid_status_transition', 'provider: cannot self-publish');
  perform sawa_test.expect_error($q$update public.providers set user_id = 'aaaaaaaa-0000-4000-8000-0000000000b2' where user_id = auth.uid()$q$,
                                 'immutable_field', 'provider: cannot transfer ownership');
  perform sawa_test.ok(sawa_test.exec_count($q$update public.providers set status = 'pending' where user_id = auth.uid()$q$) = 1,
                       'provider: can submit for review (draft → pending)');
  perform sawa_test.ok((select submitted_at from public.providers where id = biz_a) is not null, 'provider: submitted_at stamped');

  perform sawa_test.act_as(u_ca, 'authenticated');
  perform sawa_test.expect_error($q$insert into public.providers (category_id, business_name) values ('halls','Customer biz')$q$,
                                 'provider_account_required', 'customer: cannot create a business');

  perform sawa_test.act_as(u_pb, 'authenticated');
  insert into public.providers (category_id, business_name) values ('flowers', 'QA Flowers B') returning id into biz_b;
  perform sawa_test.ok((select count(*) from public.providers where id = biz_a) = 0, 'provider B: cannot see provider A draft/pending');
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.providers set business_name = 'hacked' where id = %L$q$, biz_a)) = 0,
                       'provider B: cannot edit provider A');
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.providers set business_name = 'hacked' where id = %L$q$, p0)) = 0,
                       'provider B: cannot edit SAWA-managed listing');

  perform sawa_test.act_as(u_pa, 'authenticated');
  insert into public.provider_private (provider_id, phone) values (biz_a, '07711111111');
  insert into public.services (provider_id, name, price_from) values (biz_a, 'QA Wedding Coverage', 500000);
  perform sawa_test.ok((select count(*) from public.provider_private where provider_id = biz_a) = 1, 'provider: reads own private data');
  perform sawa_test.ok((select count(*) from public.provider_private where provider_id = p0) = 0, 'provider: cannot read another business private data');
  perform sawa_test.expect_error(format($q$insert into public.services (provider_id, name) values (%L, 'x')$q$, biz_b),
                                 'row-level security', 'provider: cannot add service to another business');
  perform sawa_test.expect_error(format($q$insert into public.services (provider_id, name) values (%L, 'x')$q$, p0),
                                 'row-level security', 'provider: cannot add service to SAWA-managed listing');
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.services set name = 'hacked' where provider_id = %L$q$, p0)) = 0,
                       'provider: cannot edit another business services');

  perform sawa_test.act_as(u_pb, 'authenticated');
  perform sawa_test.ok((select count(*) from public.provider_private where provider_id = biz_a) = 0, 'provider B: provider A private data hidden');
  perform sawa_test.ok((select count(*) from public.services where provider_id = biz_a) = 0, 'provider B: pending business services hidden');

  perform sawa_test.act_as(null, 'anon');
  perform sawa_test.ok((select count(*) from public.providers where id in (biz_a, biz_b)) = 0, 'anon: unpublished businesses hidden');

  -- admin review → publish
  perform sawa_test.act_as(u_adm, 'authenticated');
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.providers set status = 'published' where id = %L$q$, biz_a)) = 1,
                       'admin: can publish a business');
  perform sawa_test.act_as(u_pa, 'authenticated');
  perform sawa_test.expect_error($q$update public.providers set status = 'draft' where user_id = auth.uid()$q$,
                                 'invalid_status_transition', 'provider: cannot unpublish/alter status after publish');
  perform sawa_test.ok(sawa_test.exec_count($q$update public.providers set short_description = 'Updated' where user_id = auth.uid()$q$) = 1,
                       'provider: can edit content of own published business');
  perform sawa_test.act_as(null, 'anon');
  perform sawa_test.ok((select count(*) from public.providers where id = biz_a) = 1, 'anon: sees business after publish');

  -- 4. Contact requests ------------------------------------------------------
  perform sawa_test.set_ip('10.0.0.1');
  perform sawa_test.act_as(null, 'anon');
  -- v1 app payload (direct insert, legacy text id, client created_at)
  insert into public.contact_requests (provider_id, user_name, user_contact, note, created_at)
  values ('qa_legacy_001', 'Guest QA', '07701112233', 'hello', '2000-01-01');
  -- spoof attempts
  insert into public.contact_requests (provider_id, user_name, user_contact, customer_id, status, forwarded_to_provider_at, is_spam)
  values ('qa_legacy_001', 'Spoofer', '07701112234', u_ca, 'completed', now(), true);
  insert into public.contact_requests (provider_id, user_name, user_contact)
  values ('qa_legacy_001', 'Arabic Digits', '٠٧٧٠١١١٢٢٣٥');

  perform sawa_test.act_as(null, 'operator');
  perform sawa_test.ok((select provider_uuid from public.contact_requests where user_contact = '07701112233') = p0, 'guest v1 insert: legacy id resolved to provider');
  perform sawa_test.ok((select channel from public.contact_requests where user_contact = '07701112233') = 'guest', 'guest v1 insert: channel = guest');
  perform sawa_test.ok((select created_at > now() - interval '1 minute' from public.contact_requests where user_contact = '07701112233'), 'guest v1 insert: client created_at ignored');
  perform sawa_test.ok((select reference_code like 'SW-%' from public.contact_requests where user_contact = '07701112233'), 'guest v1 insert: reference generated');
  perform sawa_test.ok((select customer_id is null and status = 'new' and forwarded_to_provider_at is null and not is_spam
                          from public.contact_requests where user_contact = '07701112234'), 'guest insert: spoofed customer/status/forward ignored');
  perform sawa_test.ok((select count(*) from public.contact_requests where user_contact = '07701112235') = 1, 'guest insert: Arabic-Indic digits normalised');

  perform sawa_test.act_as(null, 'anon');
  perform sawa_test.expect_error($q$insert into public.contact_requests (provider_id, user_name, user_contact) values ('qa_legacy_001','Bad','abc')$q$,
                                 'invalid_contact', 'guest insert: invalid phone rejected');
  perform sawa_test.expect_error($q$insert into public.contact_requests (provider_id, user_name, user_contact) values ('qa_legacy_001','   ','07701119999')$q$,
                                 'invalid_name', 'guest insert: blank name rejected');
  select r.reference_code into v_ref from public.submit_contact_request(p0, 'Guest RPC', '07701112236', 'via rpc') r;
  perform sawa_test.ok(v_ref like 'SW-%', 'guest RPC: returns reference code');
  perform sawa_test.expect_error(format($q$select * from public.submit_contact_request(%L, 'Guest RPC', '07701112236')$q$, p0),
                                 'duplicate_request', 'anti-spam: duplicate request within 10 min rejected');
  perform sawa_test.expect_error(format($q$select * from public.submit_contact_request(%L, 'Guest', '07701112237')$q$, biz_b),
                                 'provider_not_available', 'guest RPC: unpublished provider rejected');
  perform sawa_test.expect_error(format($q$select * from public.submit_contact_request(%L, 'Guest', '07701112238', null, null, %L)$q$, p0, s_off),
                                 'invalid_service', 'guest RPC: inactive/foreign service rejected');

  -- signed-in customers
  perform sawa_test.act_as(u_ca, 'authenticated');
  perform public.submit_contact_request(p0, 'Cust A', '07702223344', 'first');
  -- v1 app while signed in (direct insert, no customer_id sent)
  insert into public.contact_requests (provider_id, user_name, user_contact) values (biz_a::text, 'Cust A', '07702223346');
  select id into req_a1 from public.contact_requests where user_contact = '07702223344';
  select id into req_a2 from public.contact_requests where user_contact = '07702223346';
  perform sawa_test.ok(req_a1 is not null and req_a2 is not null, 'customer: sees own requests');
  perform sawa_test.ok((select bool_and(customer_id = u_ca) from public.contact_requests), 'customer: sees ONLY own requests');
  perform sawa_test.ok((select channel from public.contact_requests where id = req_a2) = 'customer', 'customer: v1 insert linked to account');

  perform sawa_test.act_as(u_cb, 'authenticated');
  select r.reference_code into v_ref from public.submit_contact_request(p0, 'Cust B', '07703334455') r;
  select id into req_b1 from public.contact_requests where reference_code = v_ref;
  perform sawa_test.ok((select count(*) from public.contact_requests where customer_id = u_ca) = 0, 'customer B: cannot read customer A requests');
  perform sawa_test.ok((select count(*) from public.contact_requests where customer_id is null) = 0, 'customer B: cannot read guest requests');
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.contact_requests set status = 'cancelled' where id = %s$q$, req_a1)) = 0,
                       'customer B: cannot modify customer A request');

  perform sawa_test.act_as(u_ca, 'authenticated');
  perform sawa_test.expect_error(format($q$update public.contact_requests set status = 'completed' where id = %s$q$, req_a1),
                                 'invalid_status_transition', 'customer: cannot mark own request completed');
  perform sawa_test.expect_error(format($q$update public.contact_requests set user_contact = '07709999999' where id = %s$q$, req_a1),
                                 'immutable_field', 'customer: cannot edit request contents');
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.contact_requests set status = 'cancelled' where id = %s$q$, req_a1)) = 1,
                       'customer: can cancel own open request');

  -- provider visibility: only after SAWA forwards
  perform sawa_test.act_as(u_pa, 'authenticated');
  perform sawa_test.ok((select count(*) from public.contact_requests) = 0, 'provider: sees no requests before SAWA forwards');

  perform sawa_test.act_as(u_adm, 'authenticated');
  perform sawa_test.ok((select count(*) from public.contact_requests where id in (req_a1, req_a2, req_b1)) = 3, 'admin: reads all requests');
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.contact_requests set forwarded_to_provider_at = now(), handled_by = auth.uid() where id = %s$q$, req_a2)) = 1,
                       'admin: forwards request to provider');

  perform sawa_test.act_as(u_pa, 'authenticated');
  perform sawa_test.ok((select count(*) from public.contact_requests) = 1, 'provider: sees exactly the forwarded request');
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.contact_requests set status = 'contacted' where id = %s$q$, req_a2)) = 1,
                       'provider: updates status of forwarded request');
  perform sawa_test.expect_error(format($q$update public.contact_requests set note = 'x' where id = %s$q$, req_a2),
                                 'immutable_field', 'provider: cannot edit request contents');
  perform sawa_test.expect_error(format($q$update public.contact_requests set status = 'new' where id = %s$q$, req_a2),
                                 'invalid_status_transition', 'provider: cannot reset status to new');

  perform sawa_test.act_as(u_pb, 'authenticated');
  perform sawa_test.ok((select count(*) from public.contact_requests) = 0, 'provider B: sees none of provider A requests');
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.contact_requests set status = 'completed' where id = %s$q$, req_a2)) = 0,
                       'provider B: cannot modify provider A request');

  -- rate limiting: 10 per network per hour
  perform sawa_test.set_ip('10.9.9.9');
  perform sawa_test.act_as(null, 'anon');
  for i in 1..10 loop
    perform public.submit_contact_request(p0, 'Flood', '0771000' || lpad(i::text, 4, '0'));
  end loop;
  perform sawa_test.expect_error(format($q$select * from public.submit_contact_request(%L, 'Flood', '07710009999')$q$, p0),
                                 'rate_limited', 'anti-spam: 11th request from same network blocked');
  -- rate limiting: 5 per phone per hour (different networks, different providers)
  for i in 1..5 loop
    perform sawa_test.set_ip('10.8.8.' || i);
    perform public.submit_contact_request(('bbbbbbbb-0000-4000-8000-00000000000' || i)::uuid, 'Same Phone', '07720000000');
  end loop;
  perform sawa_test.set_ip('10.8.8.99');
  perform sawa_test.expect_error(format($q$select * from public.submit_contact_request(%L, 'Same Phone', '07720000000')$q$, p0),
                                 'rate_limited', 'anti-spam: 6th request from same phone blocked');

  -- 5. Event inquiries -------------------------------------------------------
  perform sawa_test.set_ip('10.7.7.7');
  perform sawa_test.act_as(null, 'anon');
  perform sawa_test.expect_error($q$select * from public.create_event_inquiry('wedding', 200, 'بغداد')$q$,
                                 'contact_required', 'guest inquiry: contact number required');
  perform sawa_test.expect_error($q$select * from public.create_event_inquiry('wedding', p_services => array['spaceships'], p_guest_contact => '07730000000')$q$,
                                 'unknown_service_category', 'inquiry: unknown service category rejected');
  perform sawa_test.expect_error($q$select * from public.create_event_inquiry('wedding', p_event_date => date '2000-01-01', p_guest_contact => '07730000000')$q$,
                                 'event_date_in_past', 'inquiry: past event date rejected');
  select r.id, r.reference_code into inq_g, v_ref
    from public.create_event_inquiry('engagement', 80, 'بغداد', 'الكرادة', null, 1000000, 3000000, 'IQD',
                                     array['halls', 'photography'], 'كلاسيكي', 'QA guest', 'QA Guest', '07731112222') r;
  perform sawa_test.ok(v_ref like 'EV-%', 'guest inquiry: created with reference');
  -- guest links a contact request to their own fresh inquiry (same phone)
  perform public.submit_contact_request(p0, 'QA Guest', '07731112222', 'from planner', inq_g);
  perform sawa_test.expect_error(format($q$select * from public.submit_contact_request(%L, 'Other', '07731119999', null, %s)$q$, p0, inq_g),
                                 'invalid_inquiry', 'guest: cannot attach someone else''s inquiry');

  perform sawa_test.act_as(u_ca, 'authenticated');
  select r.id into inq_a from public.create_event_inquiry('wedding', 300, 'بغداد', p_services => array['halls']) r;
  perform sawa_test.ok((select customer_id from public.event_inquiries where id = inq_a) = u_ca, 'customer inquiry: linked to account');
  perform sawa_test.expect_error($q$insert into public.event_inquiries (event_type, reference_code, guest_contact) values ('wedding','x','07730000001')$q$,
                                 'permission denied', 'inquiry: direct insert blocked (RPC only)');
  perform sawa_test.expect_error(format($q$update public.event_inquiries set notes = 'x' where id = %s$q$, inq_a),
                                 'immutable_field', 'customer: cannot edit inquiry contents');
  perform public.submit_contact_request(p0, 'Cust A', '07702223399', 'about my wedding', inq_a);
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.event_inquiries set status = 'cancelled' where id = %s$q$, inq_a)) = 1,
                       'customer: can cancel own inquiry');

  perform sawa_test.act_as(u_cb, 'authenticated');
  perform sawa_test.ok((select count(*) from public.event_inquiries where id in (inq_a, inq_g)) = 0, 'customer B: cannot read others'' inquiries');
  perform sawa_test.expect_error(format($q$select * from public.submit_contact_request(%L, 'Cust B', '07703330000', null, %s)$q$, p0, inq_a),
                                 'invalid_inquiry', 'customer B: cannot attach customer A inquiry');

  -- 6. Profiles ----------------------------------------------------------------
  perform sawa_test.act_as(u_ca, 'authenticated');
  perform sawa_test.ok(sawa_test.exec_count($q$update public.profiles set full_name = 'QA A Renamed', phone = '٠٧٧٠٠٠٠٠٠٠٩' where id = auth.uid()$q$) = 1,
                       'profile: can edit own name/phone');
  perform sawa_test.ok((select phone from public.profiles where id = u_ca) = '07700000009', 'profile: phone digits normalised');
  perform sawa_test.expect_error($q$update public.profiles set role = 'admin' where id = auth.uid()$q$,
                                 'immutable_field', 'profile: cannot escalate own role');
  perform sawa_test.expect_error($q$update public.profiles set role = 'provider' where id = auth.uid()$q$,
                                 'immutable_field', 'profile: cannot switch own role');
  perform sawa_test.ok((select count(*) from public.profiles where id <> u_ca) = 0, 'profile: cannot read other profiles');
  perform sawa_test.ok(sawa_test.exec_count(format($q$update public.profiles set full_name = 'x' where id = %L$q$, u_cb)) = 0,
                       'profile: cannot edit other profiles');
  perform sawa_test.expect_error($q$insert into public.categories (id, name_ar, name_en) values ('qa_cat','x','x')$q$,
                                 'row-level security', 'customer: cannot write categories');

  -- 7. Views + dashboard stats (real rows only) -----------------------------
  perform sawa_test.set_ip('10.6.6.6');
  perform sawa_test.act_as(null, 'anon');
  perform public.record_provider_view(biz_a);
  perform public.record_provider_view(biz_a);                       -- de-duplicated
  perform public.record_provider_view(biz_b);                       -- unpublished → ignored

  perform sawa_test.act_as(u_pa, 'authenticated');
  perform public.record_provider_view(biz_a);                       -- owner → not counted
  v_stats := public.get_provider_stats(biz_a);
  perform sawa_test.ok((v_stats ->> 'views_total')::int = 1, 'stats: views counted once, owner excluded');
  perform sawa_test.ok((v_stats ->> 'requests_total')::int = 1, 'stats: only forwarded requests counted');
  perform sawa_test.ok((v_stats ->> 'services_active')::int = 1, 'stats: active services counted');
  perform sawa_test.ok((select count(*) from public.provider_profile_views) = 1, 'provider: reads own view events');

  perform sawa_test.act_as(u_pb, 'authenticated');
  perform sawa_test.expect_error(format($q$select public.get_provider_stats(%L)$q$, biz_a), 'not_allowed', 'provider B: cannot read provider A stats');
  perform sawa_test.ok((select count(*) from public.provider_profile_views) = 0, 'provider B: cannot read provider A view events');

  -- 8. Storage ownership predicates ------------------------------------------
  perform sawa_test.act_as(u_pa, 'authenticated');
  perform sawa_test.ok(public.owns_provider_folder(biz_a::text || '/cover.jpg'), 'storage: owner may write in own business folder');
  perform sawa_test.ok(not public.owns_provider_folder(biz_b::text || '/cover.jpg'), 'storage: cannot write in another business folder');
  perform sawa_test.ok(not public.owns_provider_folder(p0::text || '/cover.jpg'), 'storage: cannot write in SAWA-managed listing folder');
  perform sawa_test.act_as(null, 'operator');
  perform sawa_test.ok((select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects'
                         and policyname like 'sawa\_%') = 8, 'storage: 8 SAWA policies installed');
  perform sawa_test.ok((select count(*) from storage.buckets where id in ('provider-media', 'avatars') and public) = 2,
                       'storage: buckets exist');

  -- 9. Legacy hole closed ------------------------------------------------------
  perform sawa_test.ok(not exists (select 1 from pg_policies where tablename = 'contact_requests'
                                   and policyname = 'authenticated_read_only'),
                       'v1 policy "authenticated_read_only" removed');
  perform sawa_test.ok(exists (select 1 from information_schema.tables
                               where table_schema = 'sawa_private' and table_name = 'contact_requests_backup_v1'),
                       'contact_requests v1 backup exists');

  -- 10. Account deletion cascades cleanly ------------------------------------
  perform sawa_test.act_as(null, 'operator');
  delete from auth.users where id = u_ca;             -- has inquiries + requests
  perform sawa_test.ok(not exists (select 1 from public.profiles where id = u_ca), 'delete account: profile removed');
  perform sawa_test.ok(not exists (select 1 from public.event_inquiries where id = inq_a), 'delete account: own inquiries removed');
  perform sawa_test.ok((select customer_id is null from public.contact_requests where id = req_a2), 'delete account: requests kept for SAWA, unlinked');
  delete from auth.users where id = u_pa;             -- owns a published business
  perform sawa_test.ok((select user_id is null from public.providers where id = biz_a), 'delete provider account: business kept, ownerless');

  raise exception 'ALL_TESTS_PASSED (% checks)', current_setting('sawa_test.n');
end $$;
