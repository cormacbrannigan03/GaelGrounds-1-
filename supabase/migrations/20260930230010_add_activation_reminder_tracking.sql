-- Tracks whether the 48-hour "log your first match" reminder email has
-- already gone out to this user, so the cron job below never double-sends
-- one. Null means not sent yet.
alter table public.user_profiles
  add column if not exists activation_reminder_sent_at timestamptz;

-- Backfill: everyone who already qualifies right now already got this
-- exact email manually today (the Sept/Oct activation campaign). Mark
-- them as already-reminded so the new hourly cron only ever fires for
-- people who sign up from this point forward, not the whole existing
-- backlog again.
update public.user_profiles up
set activation_reminder_sent_at = now()
where up.activation_reminder_sent_at is null
  and up.created_at <= now() - interval '48 hours'
  and up.is_premium = false
  and not exists (
    select 1 from public.user_match_attendance m where m.user_id = up.id
  );
