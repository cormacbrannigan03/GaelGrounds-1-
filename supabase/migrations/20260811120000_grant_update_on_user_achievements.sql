-- The RLS UPDATE policy added in 20260808120000_pin_achievements_for_home_screen.sql
-- ("users can update their own achievements") never actually took effect: RLS
-- policies only apply within privileges already GRANTed at the table level,
-- and `authenticated` was only ever granted SELECT + INSERT on this table
-- (confirmed via information_schema.role_table_grants -- no UPDATE row for
-- authenticated at all). Every star/unstar toggle was therefore failing with
-- a permission-denied error, silently caught client-side, which reverted the
-- optimistic UI update -- the star appeared to do nothing.
grant update on public.user_achievements to authenticated;
