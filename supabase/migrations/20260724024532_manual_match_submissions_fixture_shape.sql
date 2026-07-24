-- Bring manual_match_submissions in line with the richer matches schema
-- (competition_id/season/round/match_date/throw_in_time) so every provider,
-- including hand-entered rows, feeds the same shape. Table has no real rows
-- yet (only a test row, already removed), so this is a straight redefinition
-- rather than a data migration.
alter table public.manual_match_submissions
  add column season int,
  add column round text,
  add column match_date date,
  add column throw_in_time time;

update public.manual_match_submissions set match_date = played_at::date, throw_in_time = played_at::time, season = extract(year from played_at)::int;

alter table public.manual_match_submissions
  alter column match_date set not null,
  alter column season set not null,
  drop column played_at;
