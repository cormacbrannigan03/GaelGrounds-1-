-- Stores APNs device tokens for signed-in users, so push notifications
-- (friend requests, live check-ins) can be sent to their devices. Written
-- to by the iOS app after the user grants notification permission and
-- registers with APNs (PushNotificationService.swift); read by the
-- send-push-notification Edge Function via its service-role client, which
-- bypasses RLS entirely -- so no policy here needs to grant that function
-- access.
create table public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.device_push_tokens enable row level security;

create policy "users can view their own device tokens"
  on public.device_push_tokens for select
  to authenticated
  using (auth.uid() = user_id);

create policy "users can register their own device tokens"
  on public.device_push_tokens for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "users can update their own device tokens"
  on public.device_push_tokens for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "users can remove their own device tokens"
  on public.device_push_tokens for delete
  to authenticated
  using (auth.uid() = user_id);
