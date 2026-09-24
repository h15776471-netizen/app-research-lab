-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — Migration 300: privileges + Row-Level Security
-- ═════════════════════════════════════════════════════════════════════════════
-- Security is enforced HERE, never by client-side role checks.
--
--   anon          → published catalogue only; may submit a contact request.
--   customer      → own profile, own inquiries, own requests.
--   provider      → own business (+ private data, services, packages,
--                   images), requests SAWA forwarded to that business.
--   admin         → everything (profiles.role = 'admin', set by an operator).
--
-- Column-level rules (what a client may change) are enforced by the guard
-- triggers in migrations 100/200.
-- Idempotent: every policy is dropped and recreated.
-- ═════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Privileges: start from nothing, grant exactly what the app needs.
--    (Supabase grants ALL to anon/authenticated by default.)
-- ─────────────────────────────────────────────────────────────────────────────
revoke all on table
  public.profiles, public.categories, public.providers, public.provider_private,
  public.provider_field_sources, public.provider_images, public.services,
  public.provider_packages, public.event_inquiries, public.contact_requests,
  public.provider_profile_views
from anon, authenticated;

-- Public catalogue (rows still filtered by RLS).
grant select on public.categories, public.providers, public.provider_field_sources,
                public.provider_images, public.services, public.provider_packages
  to anon, authenticated;

-- Authenticated writes (RLS decides whose rows; admin-only where noted).
grant insert, update, delete on public.categories, public.provider_field_sources to authenticated; -- admin only (RLS)
grant insert, update, delete on public.providers, public.provider_images,
                                public.services, public.provider_packages       to authenticated;
grant select, insert, update, delete on public.provider_private                 to authenticated;
grant select, update on public.profiles                                         to authenticated;
grant select, update on public.event_inquiries                                  to authenticated; -- inserts via RPC
grant select, update on public.contact_requests                                 to authenticated;
grant select on public.provider_profile_views                                   to authenticated; -- inserts via RPC

-- Legacy direct insert used by the v1 app (guest + signed-in). The insert
-- trigger owns every sensitive column. To be narrowed to the RPC in Phase 5.
grant insert on public.contact_requests to anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Enable RLS everywhere.
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.profiles               enable row level security;
alter table public.categories             enable row level security;
alter table public.providers              enable row level security;
alter table public.provider_private       enable row level security;
alter table public.provider_field_sources enable row level security;
alter table public.provider_images        enable row level security;
alter table public.services               enable row level security;
alter table public.provider_packages      enable row level security;
alter table public.event_inquiries        enable row level security;
alter table public.contact_requests       enable row level security;
alter table public.provider_profile_views enable row level security;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Remove v1 policies.
--    "authenticated_read_only" let ANY signed-in user read every request —
--    the Critical finding from the QA audit.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "anon_insert_only"            on public.contact_requests;
drop policy if exists "authenticated_read_only"     on public.contact_requests;
drop policy if exists "profiles_own_read"           on public.profiles;
drop policy if exists "profiles_own_write"          on public.profiles;
drop policy if exists "profiles_own_update"         on public.profiles;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Policies
-- ─────────────────────────────────────────────────────────────────────────────

-- profiles --------------------------------------------------------------------
drop policy if exists profiles_self_read   on public.profiles;
drop policy if exists profiles_self_update on public.profiles;
drop policy if exists profiles_admin_all   on public.profiles;

create policy profiles_self_read on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_self_update on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy profiles_admin_all on public.profiles
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- categories ------------------------------------------------------------------
drop policy if exists categories_public_read on public.categories;
drop policy if exists categories_admin_all   on public.categories;

create policy categories_public_read on public.categories
  for select to anon, authenticated
  using (is_active);

create policy categories_admin_all on public.categories
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- providers -------------------------------------------------------------------
drop policy if exists providers_public_read  on public.providers;
drop policy if exists providers_owner_read   on public.providers;
drop policy if exists providers_owner_insert on public.providers;
drop policy if exists providers_owner_update on public.providers;
drop policy if exists providers_owner_delete on public.providers;
drop policy if exists providers_admin_all    on public.providers;

create policy providers_public_read on public.providers
  for select to anon, authenticated
  using (status = 'published');

create policy providers_owner_read on public.providers
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy providers_owner_insert on public.providers
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy providers_owner_update on public.providers
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy providers_owner_delete on public.providers
  for delete to authenticated
  using (user_id = (select auth.uid()) and status = 'draft');

create policy providers_admin_all on public.providers
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- provider_private (owner + admin only; never public) ------------------------
drop policy if exists provider_private_owner_all on public.provider_private;
drop policy if exists provider_private_admin_all on public.provider_private;

create policy provider_private_owner_all on public.provider_private
  for all to authenticated
  using (public.owns_provider(provider_id))
  with check (public.owns_provider(provider_id));

create policy provider_private_admin_all on public.provider_private
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- provider_field_sources (public for published listings; admin writes) --------
drop policy if exists provider_field_sources_public_read on public.provider_field_sources;
drop policy if exists provider_field_sources_owner_read  on public.provider_field_sources;
drop policy if exists provider_field_sources_admin_all   on public.provider_field_sources;

create policy provider_field_sources_public_read on public.provider_field_sources
  for select to anon, authenticated
  using (public.is_public_provider(provider_id));

create policy provider_field_sources_owner_read on public.provider_field_sources
  for select to authenticated
  using (public.owns_provider(provider_id));

create policy provider_field_sources_admin_all on public.provider_field_sources
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- provider_images -------------------------------------------------------------
drop policy if exists provider_images_public_read on public.provider_images;
drop policy if exists provider_images_owner_all   on public.provider_images;
drop policy if exists provider_images_admin_all   on public.provider_images;

create policy provider_images_public_read on public.provider_images
  for select to anon, authenticated
  using (public.is_public_provider(provider_id));

create policy provider_images_owner_all on public.provider_images
  for all to authenticated
  using (public.owns_provider(provider_id))
  with check (public.owns_provider(provider_id));

create policy provider_images_admin_all on public.provider_images
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- services --------------------------------------------------------------------
drop policy if exists services_public_read on public.services;
drop policy if exists services_owner_all   on public.services;
drop policy if exists services_admin_all   on public.services;

create policy services_public_read on public.services
  for select to anon, authenticated
  using (is_active and public.is_public_provider(provider_id));

create policy services_owner_all on public.services
  for all to authenticated
  using (public.owns_provider(provider_id))
  with check (public.owns_provider(provider_id));

create policy services_admin_all on public.services
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- provider_packages -----------------------------------------------------------
drop policy if exists provider_packages_public_read on public.provider_packages;
drop policy if exists provider_packages_owner_all   on public.provider_packages;
drop policy if exists provider_packages_admin_all   on public.provider_packages;

create policy provider_packages_public_read on public.provider_packages
  for select to anon, authenticated
  using (is_active and public.is_public_provider(provider_id));

create policy provider_packages_owner_all on public.provider_packages
  for all to authenticated
  using (public.owns_provider(provider_id))
  with check (public.owns_provider(provider_id));

create policy provider_packages_admin_all on public.provider_packages
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- event_inquiries (customer's own; created via RPC) ---------------------------
drop policy if exists event_inquiries_self_read   on public.event_inquiries;
drop policy if exists event_inquiries_self_update on public.event_inquiries;
drop policy if exists event_inquiries_admin_all   on public.event_inquiries;

create policy event_inquiries_self_read on public.event_inquiries
  for select to authenticated
  using (customer_id = (select auth.uid()));

create policy event_inquiries_self_update on public.event_inquiries
  for update to authenticated
  using (customer_id = (select auth.uid()))
  with check (customer_id = (select auth.uid()));

create policy event_inquiries_admin_all on public.event_inquiries
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- contact_requests ------------------------------------------------------------
drop policy if exists contact_requests_guest_insert     on public.contact_requests;
drop policy if exists contact_requests_customer_insert  on public.contact_requests;
drop policy if exists contact_requests_customer_read    on public.contact_requests;
drop policy if exists contact_requests_customer_update  on public.contact_requests;
drop policy if exists contact_requests_provider_read    on public.contact_requests;
drop policy if exists contact_requests_provider_update  on public.contact_requests;
drop policy if exists contact_requests_admin_all        on public.contact_requests;

-- Guests: insert only, never linked to an account.
create policy contact_requests_guest_insert on public.contact_requests
  for insert to anon
  with check (customer_id is null);

-- Signed-in users: the trigger stamps customer_id = auth.uid().
create policy contact_requests_customer_insert on public.contact_requests
  for insert to authenticated
  with check (customer_id = (select auth.uid()));

create policy contact_requests_customer_read on public.contact_requests
  for select to authenticated
  using (customer_id = (select auth.uid()));

create policy contact_requests_customer_update on public.contact_requests
  for update to authenticated
  using (customer_id = (select auth.uid()))
  with check (customer_id = (select auth.uid()));

-- Providers: only requests SAWA has forwarded to a business they own.
create policy contact_requests_provider_read on public.contact_requests
  for select to authenticated
  using (forwarded_to_provider_at is not null and public.owns_provider(provider_uuid));

create policy contact_requests_provider_update on public.contact_requests
  for update to authenticated
  using (forwarded_to_provider_at is not null and public.owns_provider(provider_uuid))
  with check (forwarded_to_provider_at is not null and public.owns_provider(provider_uuid));

create policy contact_requests_admin_all on public.contact_requests
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- provider_profile_views (owner + admin read; written via RPC) ----------------
drop policy if exists provider_views_owner_read on public.provider_profile_views;
drop policy if exists provider_views_admin_read on public.provider_profile_views;

create policy provider_views_owner_read on public.provider_profile_views
  for select to authenticated
  using (public.owns_provider(provider_id));

create policy provider_views_admin_read on public.provider_profile_views
  for select to authenticated
  using ((select public.is_admin()));
