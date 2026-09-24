-- Reproduces the LIVE project as it was before v2 (verified 2026-09-24):
-- only public.contact_requests exists, with the v1 policies, indexes and a
-- few rows (including a legacy row whose contact is not a phone number).

create table public.contact_requests (
  id            bigint       generated always as identity primary key,
  provider_id   text         not null check (provider_id <> ''),
  user_name     text         not null check (user_name <> ''),
  user_contact  text         not null check (user_contact <> ''),
  note          text         check (note is null or length(trim(note)) > 0),
  created_at    timestamptz  not null default now()
);

alter table public.contact_requests enable row level security;

create policy "anon_insert_only" on public.contact_requests
  for insert to anon with check (true);
create policy "authenticated_read_only" on public.contact_requests
  for select to authenticated using (true);

create index idx_contact_requests_provider_id on public.contact_requests (provider_id);
create index idx_contact_requests_created_at  on public.contact_requests (created_at desc);

insert into public.contact_requests (provider_id, user_name, user_contact, note, created_at) values
  ('hall_ritaj_001',     'Legacy User 1', '07701234567', 'موعد العرس ١٠/١٠', now() - interval '3 days'),
  ('photo_tabarek_001',  'Legacy User 2', 'abc',         null,                now() - interval '2 days'),
  ('decor_fayrouz_001',  'Legacy User 3', '0780 000 1111', null,              now() - interval '1 day');

-- An auth user that signed up before v2 (no profile row yet).
insert into auth.users (id, email, raw_user_meta_data)
values ('00000000-0000-4000-8000-00000000f001', 'legacy@sawa.test',
        '{"display_name":"Legacy Signup","role":"provider"}');
