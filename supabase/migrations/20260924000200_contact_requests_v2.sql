-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — Migration 200: contact_requests v2 (non-destructive upgrade)
-- ═════════════════════════════════════════════════════════════════════════════
-- The live table already holds real submissions. This migration:
--   1. snapshots it into sawa_private (once),
--   2. only ADDS columns (all existing columns and rows are kept),
--   3. backfills the new NOT NULL columns for existing rows,
--   4. adds server-side defaults, validation, anti-spam and rate limiting.
--
-- Backward compatible: the v1 Flutter app keeps inserting
--   { provider_id, user_name, user_contact, note, created_at }
-- as anon and keeps working. Everything else is filled in by the trigger.
--
-- Flow model (locked decision): Customer → SAWA → Provider.
-- A provider sees a request only after the SAWA team forwards it
-- (forwarded_to_provider_at). Guests can submit but never read requests.
-- ═════════════════════════════════════════════════════════════════════════════

-- The original v1 table (no-op on the live project, where it already exists).
create table if not exists public.contact_requests (
  id           bigint       generated always as identity primary key,
  provider_id  text         not null check (provider_id <> ''),
  user_name    text         not null check (user_name <> ''),
  user_contact text         not null check (user_contact <> ''),
  note         text         check (note is null or length(trim(note)) > 0),
  created_at   timestamptz  not null default now()
);

-- 1. One-time snapshot of the pre-v2 data ------------------------------------
create table if not exists sawa_private.contact_requests_backup_v1
  as table public.contact_requests;

comment on table sawa_private.contact_requests_backup_v1 is
  'Snapshot of public.contact_requests taken before the v2 migration. Not exposed via the API.';

-- 2. New columns (additive only) ----------------------------------------------
alter table public.contact_requests add column if not exists reference_code           text;
alter table public.contact_requests add column if not exists customer_id              uuid;
alter table public.contact_requests add column if not exists provider_uuid            uuid;
alter table public.contact_requests add column if not exists inquiry_id               bigint;
alter table public.contact_requests add column if not exists service_id               uuid;
alter table public.contact_requests add column if not exists status                   text;
alter table public.contact_requests add column if not exists channel                  text;
alter table public.contact_requests add column if not exists ip_hash                  text;
alter table public.contact_requests add column if not exists is_spam                  boolean;
alter table public.contact_requests add column if not exists forwarded_to_provider_at timestamptz;
alter table public.contact_requests add column if not exists handled_by               uuid;
alter table public.contact_requests add column if not exists admin_notes              text;
alter table public.contact_requests add column if not exists updated_at               timestamptz;

comment on column public.contact_requests.provider_id is
  'v1 text key (legacy providers.json id). For v2 rows it mirrors providers.legacy_id or providers.id.';
comment on column public.contact_requests.note is
  'The customer message (optional).';
comment on column public.contact_requests.user_contact is
  'Customer phone/WhatsApp. Private: visible only to the customer, SAWA admins, and the provider after SAWA forwards the request.';

-- 3. Backfill existing rows ---------------------------------------------------
update public.contact_requests
   set reference_code = sawa_private.gen_reference('SW')
 where reference_code is null;
update public.contact_requests set status     = 'new'                              where status is null;
update public.contact_requests set channel    = case when customer_id is null then 'guest' else 'customer' end
                                                                                    where channel is null;
update public.contact_requests set is_spam    = false                              where is_spam is null;
update public.contact_requests set updated_at = created_at                         where updated_at is null;

alter table public.contact_requests alter column reference_code set not null;
alter table public.contact_requests alter column status         set not null;
alter table public.contact_requests alter column status         set default 'new';
alter table public.contact_requests alter column channel        set not null;
alter table public.contact_requests alter column channel        set default 'guest';
alter table public.contact_requests alter column is_spam        set not null;
alter table public.contact_requests alter column is_spam        set default false;
alter table public.contact_requests alter column updated_at     set not null;
alter table public.contact_requests alter column updated_at     set default now();

-- Link legacy rows to providers once providers are seeded (no-op until then;
-- also re-run by the seed migration in Phase 7).
update public.contact_requests cr
   set provider_uuid = p.id
  from public.providers p
 where cr.provider_uuid is null
   and p.legacy_id = cr.provider_id;

-- 4. Constraints --------------------------------------------------------------
alter table public.contact_requests drop constraint if exists contact_requests_status_check;
alter table public.contact_requests add  constraint contact_requests_status_check
  check (status in ('new', 'viewed', 'contacted', 'completed', 'cancelled'));
alter table public.contact_requests drop constraint if exists contact_requests_channel_check;
alter table public.contact_requests add  constraint contact_requests_channel_check
  check (channel in ('guest', 'customer'));

-- Input rules for NEW rows (name/phone/message format) are enforced in the
-- insert trigger below rather than as CHECK constraints: a CHECK — even
-- NOT VALID — is re-evaluated on every UPDATE, which would block status
-- changes on legacy rows that pre-date these rules.
alter table public.contact_requests drop constraint if exists contact_requests_input_check;
alter table public.contact_requests drop constraint if exists contact_requests_admin_notes_check;
alter table public.contact_requests add  constraint contact_requests_admin_notes_check
  check (admin_notes is null or char_length(admin_notes) <= 4000);

alter table public.contact_requests drop constraint if exists contact_requests_customer_fk;
alter table public.contact_requests add  constraint contact_requests_customer_fk
  foreign key (customer_id) references public.profiles (id) on delete set null;
alter table public.contact_requests drop constraint if exists contact_requests_provider_fk;
alter table public.contact_requests add  constraint contact_requests_provider_fk
  foreign key (provider_uuid) references public.providers (id) on delete set null;
alter table public.contact_requests drop constraint if exists contact_requests_inquiry_fk;
alter table public.contact_requests add  constraint contact_requests_inquiry_fk
  foreign key (inquiry_id) references public.event_inquiries (id) on delete set null;
alter table public.contact_requests drop constraint if exists contact_requests_service_fk;
alter table public.contact_requests add  constraint contact_requests_service_fk
  foreign key (service_id) references public.services (id) on delete set null;
alter table public.contact_requests drop constraint if exists contact_requests_handled_by_fk;
alter table public.contact_requests add  constraint contact_requests_handled_by_fk
  foreign key (handled_by) references public.profiles (id) on delete set null;

-- 5. Indexes ------------------------------------------------------------------
create unique index if not exists uq_contact_requests_reference on public.contact_requests (reference_code);
create index if not exists idx_contact_requests_customer      on public.contact_requests (customer_id, created_at desc);
create index if not exists idx_contact_requests_provider_uuid on public.contact_requests (provider_uuid, created_at desc);
create index if not exists idx_contact_requests_inquiry       on public.contact_requests (inquiry_id);
create index if not exists idx_contact_requests_status        on public.contact_requests (status, created_at desc);
create index if not exists idx_contact_requests_ip            on public.contact_requests (ip_hash, created_at desc);
create index if not exists idx_contact_requests_contact       on public.contact_requests (user_contact, created_at desc);
-- v1 indexes: kept as-is where they exist; created on a fresh project.
create index if not exists idx_contact_requests_provider_id   on public.contact_requests (provider_id);
create index if not exists idx_contact_requests_created_at    on public.contact_requests (created_at desc);

-- ═════════════════════════════════════════════════════════════════════════════
-- Rate limiting / anti-spam (server-side, applies to every insert path)
-- ═════════════════════════════════════════════════════════════════════════════
create or replace function sawa_private.assert_rate_limit(
  p_kind         text,
  p_customer_id  uuid,
  p_contact      text,
  p_ip_hash      text,
  p_provider_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_digits text := sawa_private.digits_only(p_contact);
  v_n      int;
begin
  if p_kind = 'contact' then
    -- Same person asking the same provider again within 10 minutes.
    if v_digits is not null and p_provider_key is not null and exists (
         select 1 from public.contact_requests
          where provider_id = p_provider_key
            and regexp_replace(user_contact, '\D', '', 'g') = v_digits
            and created_at > now() - interval '10 minutes') then
      raise exception 'duplicate_request' using errcode = 'P0001',
        hint = 'A request to this provider was already sent a few minutes ago.';
    end if;

    if p_ip_hash is not null then
      select count(*) into v_n from public.contact_requests
       where ip_hash = p_ip_hash and created_at > now() - interval '1 hour';
      if v_n >= 10 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;

    if v_digits is not null then
      select count(*) into v_n from public.contact_requests
       where regexp_replace(user_contact, '\D', '', 'g') = v_digits
         and created_at > now() - interval '1 hour';
      if v_n >= 5 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;

    if p_customer_id is not null then
      select count(*) into v_n from public.contact_requests
       where customer_id = p_customer_id and created_at > now() - interval '1 hour';
      if v_n >= 20 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;

  elsif p_kind = 'inquiry' then
    if p_ip_hash is not null then
      select count(*) into v_n from public.event_inquiries
       where ip_hash = p_ip_hash and created_at > now() - interval '1 hour';
      if v_n >= 10 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;

    if v_digits is not null then
      select count(*) into v_n from public.event_inquiries
       where regexp_replace(guest_contact, '\D', '', 'g') = v_digits
         and created_at > now() - interval '1 hour';
      if v_n >= 5 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;

    if p_customer_id is not null then
      select count(*) into v_n from public.event_inquiries
       where customer_id = p_customer_id and created_at > now() - interval '1 hour';
      if v_n >= 10 then
        raise exception 'rate_limited' using errcode = 'P0001';
      end if;
    end if;
  end if;
end $$;

-- ═════════════════════════════════════════════════════════════════════════════
-- Insert trigger: server owns every sensitive column for client inserts.
-- ═════════════════════════════════════════════════════════════════════════════
create or replace function sawa_private.contact_requests_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider public.providers%rowtype;
  v_inquiry  public.event_inquiries%rowtype;
begin
  -- Normalise input for every insert path.
  new.user_name    := trim(coalesce(new.user_name, ''));
  new.user_contact := sawa_private.normalize_digits(new.user_contact);
  new.note         := nullif(trim(coalesce(new.note, '')), '');

  -- Resolve the provider from either key.
  if new.provider_uuid is not null then
    select * into v_provider from public.providers where id = new.provider_uuid;
  elsif new.provider_id is not null then
    select * into v_provider from public.providers
     where legacy_id = new.provider_id or id::text = new.provider_id
     limit 1;
  end if;

  if v_provider.id is not null then
    new.provider_uuid := v_provider.id;
    new.provider_id   := coalesce(v_provider.legacy_id, v_provider.id::text);
  end if;

  if not sawa_private.is_client_request() then
    new.reference_code := coalesce(new.reference_code, sawa_private.gen_reference('SW'));
    new.channel        := coalesce(new.channel, case when new.customer_id is null then 'guest' else 'customer' end);
    return new;
  end if;

  -- ── Client (anon / authenticated) insert ───────────────────────────────
  if new.user_name = '' or char_length(new.user_name) > 100 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if new.user_contact is null
     or new.user_contact !~ '^[0-9+() -]{7,25}$'
     or char_length(regexp_replace(new.user_contact, '\D', '', 'g')) not between 7 and 15 then
    raise exception 'invalid_contact' using errcode = '22023';
  end if;
  if new.note is not null and char_length(new.note) > 2000 then
    raise exception 'message_too_long' using errcode = '22023';
  end if;

  if new.provider_id is null or new.provider_id = '' then
    raise exception 'provider_required' using errcode = '22023';
  end if;
  -- A known provider must be publicly listed. (Unknown legacy ids are still
  -- accepted so the v1 app keeps working until providers are seeded.)
  if v_provider.id is not null and v_provider.status <> 'published' then
    raise exception 'provider_not_available' using errcode = '22023';
  end if;
  if new.provider_uuid is not null and v_provider.id is null then
    raise exception 'provider_not_available' using errcode = '22023';
  end if;

  new.customer_id              := auth.uid();
  new.channel                  := case when new.customer_id is null then 'guest' else 'customer' end;
  new.reference_code           := sawa_private.gen_reference('SW');
  new.status                   := 'new';
  new.is_spam                  := false;
  new.forwarded_to_provider_at := null;
  new.handled_by               := null;
  new.admin_notes              := null;
  new.ip_hash                  := sawa_private.request_ip_hash();
  new.created_at               := now();
  new.updated_at               := now();

  -- Optional links must belong to this request.
  if new.service_id is not null and not exists (
       select 1 from public.services s
        where s.id = new.service_id and s.provider_id = new.provider_uuid and s.is_active) then
    raise exception 'invalid_service' using errcode = '22023';
  end if;

  if new.inquiry_id is not null then
    select * into v_inquiry from public.event_inquiries where id = new.inquiry_id;
    if v_inquiry.id is null then
      raise exception 'invalid_inquiry' using errcode = '22023';
    end if;
    if v_inquiry.customer_id is not null then
      if v_inquiry.customer_id is distinct from new.customer_id then
        raise exception 'invalid_inquiry' using errcode = '22023';
      end if;
    else
      -- Guest inquiry: only the same guest (same phone), shortly after.
      if new.customer_id is not null
         or sawa_private.digits_only(v_inquiry.guest_contact) is distinct from sawa_private.digits_only(new.user_contact)
         or v_inquiry.created_at < now() - interval '24 hours' then
        raise exception 'invalid_inquiry' using errcode = '22023';
      end if;
    end if;
  end if;

  perform sawa_private.assert_rate_limit('contact', new.customer_id, new.user_contact, new.ip_hash, new.provider_id);
  return new;
end $$;

drop trigger if exists trg_contact_requests_before_insert on public.contact_requests;
create trigger trg_contact_requests_before_insert
  before insert on public.contact_requests
  for each row execute function sawa_private.contact_requests_before_insert();

-- ═════════════════════════════════════════════════════════════════════════════
-- Update guard: clients may only move `status`, within their own role.
-- ═════════════════════════════════════════════════════════════════════════════
create or replace function sawa_private.contact_requests_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();

  if not sawa_private.is_client_request() or public.is_admin() then
    return new;
  end if;

  if (to_jsonb(new) - array['status', 'updated_at']) is distinct from (to_jsonb(old) - array['status', 'updated_at']) then
    raise exception 'immutable_field' using errcode = '42501';
  end if;

  if new.status is not distinct from old.status then
    return new;
  end if;

  -- The customer who sent it may cancel it while it is still open.
  if old.customer_id is not null and old.customer_id = auth.uid() then
    if new.status = 'cancelled' and old.status in ('new', 'viewed') then
      return new;
    end if;
    raise exception 'invalid_status_transition' using errcode = '42501';
  end if;

  -- The owning provider may progress a request SAWA forwarded to them.
  if old.forwarded_to_provider_at is not null and public.owns_provider(old.provider_uuid) then
    if new.status in ('viewed', 'contacted', 'completed', 'cancelled') then
      return new;
    end if;
    raise exception 'invalid_status_transition' using errcode = '42501';
  end if;

  raise exception 'not_allowed' using errcode = '42501';
end $$;

drop trigger if exists trg_contact_requests_guard on public.contact_requests;
create trigger trg_contact_requests_guard
  before update on public.contact_requests
  for each row execute function sawa_private.contact_requests_guard();

revoke all on all functions in schema sawa_private from public;
