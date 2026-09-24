-- ═════════════════════════════════════════════════════════════════════════════
-- Remove the test data created by `node supabase/tests/verify_live.mjs --accounts`
-- (and the one audit test row from 2026-09-24). Run in SQL Editor.
-- Only rows carrying the explicit test markers below are touched.
-- ═════════════════════════════════════════════════════════════════════════════
begin;

-- Test auth accounts → cascades to profiles and their inquiries; any business
-- they still own becomes ownerless and is removed right after.
with gone as (
  delete from auth.users
   where email like 'sawa-verify-%@sawa-qa.test'
  returning id
)
select count(*) as test_accounts_deleted from gone;

delete from public.providers
 where business_name like 'SAWA VERIFY %' and user_id is null and source = 'self_registered';

-- The tagged v1-path contact request written by the verifier.
delete from public.contact_requests
 where provider_id = 'sawa_verify_legacy' and user_name = 'SAWA VERIFY (delete me)';

-- The QA row created during the audit on 2026-09-24.
delete from public.contact_requests
 where user_name = 'QA TEST - Claude audit (delete me)' and user_contact = '07000000000';

commit;
