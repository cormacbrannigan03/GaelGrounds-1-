-- Public waiting-list signups from the marketing website (no auth --
-- anyone can submit an email). Insert-only for the anon role: no select,
-- update, or delete policy at all, so a submitted email can never be read
-- back through the public API -- only through the Studio Table Editor or
-- the API with the service_role key, same "no built admin UI" pattern as
-- match_reports and manual_match_submissions.
create table public.waitlist_signups (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  created_at timestamptz not null default now()
);

alter table public.waitlist_signups enable row level security;

create policy "anyone can join the waiting list"
  on public.waitlist_signups for insert
  to anon, authenticated
  with check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$');

-- The default table grant includes SELECT for anon/authenticated even
-- with no matching RLS policy (RLS still blocks the rows, but the
-- table stays visible in GraphQL introspection). Revoke it outright so
-- this table is insert-only at the grant level too, not just via RLS.
revoke select on public.waitlist_signups from anon, authenticated;
