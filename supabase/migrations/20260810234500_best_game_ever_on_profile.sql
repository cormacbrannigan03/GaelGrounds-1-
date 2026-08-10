-- A single "best game you've ever attended" pick per user, shown with a
-- blue star (distinct from the gold star used for favourited achievements)
-- and its own tab on the profile screen. Stored as a single nullable
-- pointer on user_profiles rather than a per-row flag (like
-- user_achievements.pinned) since exactly one is a natural fit for a
-- scalar column -- picking a new one automatically un-picks the old one,
-- no extra "clear the others" step needed.
-- No new RLS policy needed: "users can update their own profile" and
-- "signed-in users can view profiles" already cover this column with no
-- restrictions.
alter table public.user_profiles
  add column if not exists best_match_id uuid references public.matches(id) on delete set null;
