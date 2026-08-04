-- Lets a signed-in user flag that a match's venue/date/time/score looks
-- wrong, with optional free-text detail. There's no admin UI for this in
-- the app -- same pattern as manual_match_submissions in the sync-matches
-- pipeline: triage happens directly against this table (Studio's Table
-- Editor, or the API with the service_role key), not through a built
-- screen.
create table public.match_reports (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  issue_types text[] not null,
  details text,
  status text not null default 'open' check (status in ('open', 'reviewed', 'resolved', 'dismissed')),
  created_at timestamptz not null default now()
);

alter table public.match_reports enable row level security;

create policy "users can view their own match reports"
  on public.match_reports for select
  to authenticated
  using (auth.uid() = user_id);

create policy "users can submit match reports"
  on public.match_reports for insert
  to authenticated
  with check (auth.uid() = user_id and cardinality(issue_types) > 0);
