-- Two small honesty fixes made right after the fixture-schema backfill:
-- 1. The backfill set throw_in_time = '00:00:00' for every row that only
--    ever had a date-only played_at — midnight isn't a real throw-in time,
--    it's a placeholder artifact, so treat it as "not confirmed" instead.
update public.matches set throw_in_time = null where throw_in_time = '00:00:00';

-- 2. "Ulster Senior Football League" was a plausible-sounding demo fixture
--    seeded early in this project, not a real researched competition/match —
--    removed once "all fixture match ups must be correct" became the bar.
delete from public.matches where competition = 'Ulster Senior Football League';
