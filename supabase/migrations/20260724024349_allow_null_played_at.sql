-- Some researched historical results have a confirmed matchup/winner but no
-- confirmed exact date (e.g. several tier-cup finals). Rather than fabricate
-- a date to satisfy a not-null constraint, or drop otherwise-accurate result
-- data, played_at becomes nullable — match_date is now the authoritative
-- "do we know when this was played" field, and played_at (kept for sorting/
-- display convenience) is only populated when match_date is known.
alter table public.matches alter column played_at drop not null;
