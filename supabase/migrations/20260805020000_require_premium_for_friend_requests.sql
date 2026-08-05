-- The friendships table already existed live (created ad hoc at some point
-- before this migration history was fully reconciled -- its actual
-- policies didn't match 20260801023442_create_friendships_table.sql,
-- which never successfully applied because the table was already there).
-- The live INSERT policy had no premium check at all, so "premium required
-- to add friends" was only ever enforced client-side. Replacing it with
-- the premium-gated version that file always intended.
drop policy if exists "Users can send friend requests" on public.friendships;

create policy "premium users can send friend requests"
  on public.friendships for insert
  to authenticated
  with check (
    auth.uid() = requester_id
    and exists (
      select 1 from public.user_profiles
      where id = auth.uid() and is_premium = true
    )
  );
