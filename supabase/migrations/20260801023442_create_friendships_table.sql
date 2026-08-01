-- Friends feature backing table. Matches the Friendship/FriendshipInsert/
-- FriendshipStatusUpdate Swift models in ios/GaelGrounds/Models/UserData.swift.
create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  unique (requester_id, addressee_id)
);

alter table public.friendships enable row level security;

create policy "friendships are readable by the two people involved"
  on public.friendships for select
  to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

-- Premium required to send a friend request — this is the actual
-- server-side enforcement of "premium required to add friends," not just
-- a client-side UI check.
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

create policy "addressee can respond to a friend request"
  on public.friendships for update
  to authenticated
  using (auth.uid() = addressee_id)
  with check (auth.uid() = addressee_id);

create policy "either side can remove a friendship"
  on public.friendships for delete
  to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);
