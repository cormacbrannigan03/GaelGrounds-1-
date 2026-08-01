-- Three more fabricated 2026 demo fixtures, caught the same way as the
-- "Ulster Senior Football League" row in the previous migration: plausible-
-- looking placeholders seeded early in this project, contradicted once
-- checked against what actually happened in the real 2026 championship.
-- Real replacements are inserted in
-- 20260724024433_seed_leagues_tiers_and_provincial_championships.sql.
-- Verified to have zero user_match_attendance rows before removal.
delete from public.matches
where source_provider = 'manual'
  and source_ref is null
  and competition in (
    'All-Ireland Senior Football Championship Final',
    'All-Ireland Senior Football Championship Semi-Final',
    'All-Ireland Senior Hurling Championship Final'
  )
  and season = 2026
  and status = 'scheduled';
